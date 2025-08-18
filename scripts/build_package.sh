#!/usr/bin/env bash
#
# build_package.sh
#
# Purpose:
#   Build, (optionally) code-sign, produce a universal macOS .app bundle,
#   and (optionally) create a DMG for distribution.
#
# Key Features:
#   - Incremental builds (does not wipe target/ unless forced)
#   - Universal (fat) binary (x86_64 + arm64) via lipo
#   - CI-friendly fast DMG creation using hdiutil (no Finder layout)
#   - Optional fancy DMG via create-dmg locally (with timeout + fallback)
#   - Optional install to /Applications
#   - Safe re-runs (idempotent where possible)
#
# Usage:
#   ./scripts/build_package.sh [--dmg] [--install] [--force-clean] [--no-sign] [--skip-universal]
#
# Environment Variables:
#   CODE_SIGN_IDENTITY    Code signing identity (e.g. "Developer ID Application: ...")
#   APP_NAME              Override app name (default: Uptime Kuma Notifier)
#   VERSION               Override version (auto-detected from Cargo.toml if unset)
#   BUNDLE_ID             Override bundle id (default: com.unicornops.uptime-kuma-notifier)
#   CI                    When set (e.g. by GitHub Actions), uses simplified DMG path
#   APPLE_ID / APPLE_ID_PASSWORD / TEAM_ID (used only by notarization script, not here)
#
# Exit codes:
#   0 success
#   1 generic failure
#   2 invalid usage
#
set -euo pipefail

#######################################
# Colors
#######################################
if [ -t 1 ]; then
  RED='\033[0;31m'
  GREEN='\033[0;32m'
  YELLOW='\033[1;33m'
  BLUE='\033[0;34m'
  MAGENTA='\033[0;35m'
  CYAN='\033[0;36m'
  NC='\033[0m'
else
  RED='' GREEN='' YELLOW='' BLUE='' MAGENTA='' CYAN='' NC=''
fi

log()  { echo -e "${BLUE}[$(date +%H:%M:%S)]${NC} $*"; }
warn() { echo -e "${YELLOW}[$(date +%H:%M:%S)] WARN:${NC} $*"; }
err()  { echo -e "${RED}[$(date +%H:%M:%S)] ERROR:${NC} $*" >&2; }
ok()   { echo -e "${GREEN}[$(date +%H:%M:%S)] OK:${NC} $*"; }

#######################################
# Defaults / Configuration
#######################################
APP_NAME_DEFAULT="Uptime Kuma Notifier"
APP_NAME="${APP_NAME:-$APP_NAME_DEFAULT}"
BUNDLE_ID="${BUNDLE_ID:-com.unicornops.uptime-kuma-notifier}"

# Try to parse version from Cargo.toml if not provided
if [ -z "${VERSION:-}" ]; then
  if [ -f Cargo.toml ]; then
    VERSION=$(grep -E '^version\s*=' Cargo.toml | head -1 | sed -E 's/version\s*=\s*"([^"]+)".*/\1/')
  fi
fi
VERSION="${VERSION:-0.0.0}"

# Paths
BUILD_ROOT="target"
UNIVERSAL_DIR="${BUILD_ROOT}/universal"
DIST_DIR="dist"
APP_BUNDLE_DIR="${DIST_DIR}/${APP_NAME}.app"
CONTENTS_DIR="${APP_BUNDLE_DIR}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"
RESOURCES_DIR="${CONTENTS_DIR}/Resources"
UNIVERSAL_BINARY="${UNIVERSAL_DIR}/uptime_kuma_notifier"
PLIST_SRC="Info.plist"
ENTITLEMENTS_SRC="Entitlements.plist"
BINARY_NAME="uptime_kuma_notifier"

# Architectures to include in universal build
ARCHS=("x86_64-apple-darwin" "aarch64-apple-darwin")

#######################################
# Flags
#######################################
DO_DMG=0
DO_INSTALL=0
FORCE_CLEAN=0
NO_SIGN=0
SKIP_UNIVERSAL=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dmg) DO_DMG=1 ;;
    --install) DO_INSTALL=1 ;;
    --force-clean) FORCE_CLEAN=1 ;;
    --no-sign) NO_SIGN=1 ;;
    --skip-universal) SKIP_UNIVERSAL=1 ;;
    -h|--help)
      cat <<EOF
Usage: $0 [options]

Options:
  --dmg             Create DMG after building
  --install         Install the .app to /Applications
  --force-clean     Remove dist/ and universal binary before building
  --no-sign         Skip code signing even if identity is present
  --skip-universal  Build only host arch (no lipo universal binary)
  -h, --help        Show this help

Environment:
  APP_NAME, VERSION, BUNDLE_ID, CODE_SIGN_IDENTITY (see script header)

Examples:
  $0 --dmg
  APP_NAME="Custom Name" VERSION=1.2.3 $0 --force-clean --dmg
EOF
      exit 0
      ;;
    *)
      err "Unknown argument: $1"
      exit 2
      ;;
  esac
  shift
done

log "Starting build for ${APP_NAME} v${VERSION}"
log "Bundle ID: ${BUNDLE_ID}"

#######################################
# Preconditions
#######################################
if [[ "$OSTYPE" != "darwin"* ]]; then
  err "This script must run on macOS (darwin)."
  exit 1
fi

if ! command -v cargo >/dev/null 2>&1; then
  err "cargo not found. Install Rust (https://www.rust-lang.org/tools/install)."
  exit 1
fi

if ! command -v rustup >/dev/null 2>&1; then
  warn "rustup not found; unable to add targets automatically."
fi

#######################################
# Clean (conditional)
#######################################
if [ $FORCE_CLEAN -eq 1 ]; then
  warn "Forced clean requested."
  rm -rf "${DIST_DIR}" "${UNIVERSAL_DIR}"
  # Do NOT remove the entire target/ to keep incremental cache.
fi

mkdir -p "${DIST_DIR}"

#######################################
# Ensure targets for universal binary
#######################################
if [ $SKIP_UNIVERSAL -eq 0 ]; then
  for T in "${ARCHS[@]}"; do
    if ! rustc --print target-list | grep -q "^${T}$"; then
      err "Target ${T} not recognized by rustc. (rustc --print target-list)"
      exit 1
    fi
    if ! rustup target list --installed | grep -q "^${T}$"; then
      log "Adding Rust target: ${T}"
      rustup target add "${T}"
    fi
  done
fi

#######################################
# Build function per arch
#######################################
build_arch() {
  local target="$1"
  log "Building for ${target}"
  cargo build --release --target "${target}"
  ok "Built ${target}"
}

#######################################
# Determine whether rebuild needed
#######################################
needs_rebuild_universal=1
if [ $SKIP_UNIVERSAL -eq 0 ] && [ -f "${UNIVERSAL_BINARY}" ]; then
  # Heuristic: if Cargo.lock or any src modified after universal binary
  latest_src_mtime=$(find src -type f -print0 2>/dev/null | xargs -0 stat -f '%m' 2>/dev/null | sort -nr | head -1 || echo 0)
  universal_mtime=$(stat -f '%m' "${UNIVERSAL_BINARY}" || echo 0)
  if [ "${latest_src_mtime}" -le "${universal_mtime}" ]; then
    needs_rebuild_universal=0
    ok "Universal binary appears up-to-date (heuristic)."
  else
    log "Sources changed since universal binary creation."
  fi
fi

#######################################
# Build (host or universal)
#######################################
if [ $SKIP_UNIVERSAL -eq 1 ]; then
  log "Skipping universal build; building host-only."
  cargo build --release
  HOST_BINARY="${BUILD_ROOT}/release/${BINARY_NAME}"
  if [ ! -f "${HOST_BINARY}" ]; then
    err "Host build failed; binary not found at ${HOST_BINARY}"
    exit 1
  fi
else
  if [ $needs_rebuild_universal -eq 1 ]; then
    log "Building universal binary..."
    for arch in "${ARCHS[@]}"; do
      build_arch "${arch}"
    done
    mkdir -p "${UNIVERSAL_DIR}"
    local_x86="${BUILD_ROOT}/x86_64-apple-darwin/release/${BINARY_NAME}"
    local_arm="${BUILD_ROOT}/aarch64-apple-darwin/release/${BINARY_NAME}"
    if ! command -v lipo >/dev/null 2>&1; then
      err "lipo tool not found (part of Xcode Command Line Tools). Install via: xcode-select --install"
      exit 1
    fi
    log "Creating universal (fat) binary with lipo"
    lipo -create "${local_x86}" "${local_arm}" -output "${UNIVERSAL_BINARY}"
    ok "Universal binary created at ${UNIVERSAL_BINARY}"
  fi
fi

#######################################
# Create / refresh app bundle
#######################################
log "Preparing app bundle structure."
mkdir -p "${MACOS_DIR}" "${RESOURCES_DIR}"

# Copy binary
if [ $SKIP_UNIVERSAL -eq 1 ]; then
  cp "${HOST_BINARY}" "${MACOS_DIR}/${BINARY_NAME}"
else
  cp "${UNIVERSAL_BINARY}" "${MACOS_DIR}/${BINARY_NAME}"
fi
chmod +x "${MACOS_DIR}/${BINARY_NAME}"

# Info.plist
if [ -f "${PLIST_SRC}" ]; then
  cp "${PLIST_SRC}" "${CONTENTS_DIR}/Info.plist"
else
  warn "Info.plist not found; generating minimal placeholder."
  cat > "${CONTENTS_DIR}/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>${APP_NAME}</string>
  <key>CFBundleDisplayName</key><string>${APP_NAME}</string>
  <key>CFBundleIdentifier</key><string>${BUNDLE_ID}</string>
  <key>CFBundleVersion</key><string>${VERSION}</string>
  <key>CFBundleShortVersionString</key><string>${VERSION}</string>
  <key>CFBundleExecutable</key><string>${BINARY_NAME}</string>
  <key>LSMinimumSystemVersion</key><string>11.0</string>
  <key>CFBundlePackageType</key><string>APPL</string>
</dict>
</plist>
EOF
fi

# Entitlements (optional)
if [ -f "${ENTITLEMENTS_SRC}" ]; then
  cp "${ENTITLEMENTS_SRC}" "${CONTENTS_DIR}/Entitlements.plist"
fi

# Resources (examples / docs)
for f in README.md config.example.toml; do
  if [ -f "$f" ]; then
    cp "$f" "${RESOURCES_DIR}/" || true
  fi
done

# Icon generation (non-fatal)
if [ -x "./scripts/create_icon.sh" ]; then
  log "Generating application icon (if needed)."
  if ! ./scripts/create_icon.sh; then
    warn "Icon generation failed."
  fi
else
  warn "scripts/create_icon.sh not executable or missing; skipping icon."
fi

#######################################
# Code Signing
#######################################
if [ $NO_SIGN -eq 1 ]; then
  warn "Skipping code signing due to --no-sign flag."
else
  if [ -n "${CODE_SIGN_IDENTITY:-}" ]; then
    log "Code signing with identity: ${CODE_SIGN_IDENTITY}"
    SIGN_CMD=(codesign --force --deep --timestamp --options runtime --sign "${CODE_SIGN_IDENTITY}" "${APP_BUNDLE_DIR}")
    if [ -f "${CONTENTS_DIR}/Entitlements.plist" ]; then
      SIGN_CMD+=(--entitlements "${CONTENTS_DIR}/Entitlements.plist")
    fi
    if "${SIGN_CMD[@]}"; then
      ok "Code signing complete."
    else
      warn "Code signing failed."
    fi
  else
    warn "No CODE_SIGN_IDENTITY provided; bundle will be unsigned."
  fi
fi

#######################################
# Verify signing (if any)
#######################################
if codesign -dv "${APP_BUNDLE_DIR}" >/dev/null 2>&1; then
  log "Codesign verification:"
  (codesign -dv --verbose=2 "${APP_BUNDLE_DIR}" 2>&1 || true)
else
  warn "codesign -dv failed (unsigned bundle is acceptable for development)."
fi

ok "App bundle ready: ${APP_BUNDLE_DIR}"

#######################################
# DMG Creation
#######################################
if [ $DO_DMG -eq 1 ]; then
  DMG_ARCH_SUFFIX="universal"
  [ $SKIP_UNIVERSAL -eq 1 ] && DMG_ARCH_SUFFIX="host"
  DMG_NAME="${DIST_DIR}/${APP_NAME// /_}-${VERSION}-${DMG_ARCH_SUFFIX}.dmg"
  log "Creating DMG: ${DMG_NAME}"

  if [ -n "${CI:-}" ]; then
    # Fast, reliable, layout-free DMG for CI
    log "CI detected; using simplified hdiutil DMG creation."
    hdiutil create -volname "${APP_NAME}" -srcfolder "${APP_BUNDLE_DIR}" -ov -format UDZO "${DMG_NAME}"
  else
    # Local environment: attempt create-dmg for nicer layout
    if command -v create-dmg >/dev/null 2>&1; then
      log "Using create-dmg (with timeout fallback)."
      set +e
      timeout 300 create-dmg \
        --volname "${APP_NAME}" \
        --window-size 600 300 \
        --icon-size 100 \
        --icon "${APP_NAME}" 175 120 \
        --app-drop-link 425 120 \
        "${DMG_NAME}" "${APP_BUNDLE_DIR}/"
      rc=$?
      set -e
      if [ $rc -ne 0 ]; then
        warn "create-dmg failed or timed out (rc=$rc); falling back to hdiutil."
        hdiutil create -volname "${APP_NAME}" -srcfolder "${APP_BUNDLE_DIR}" -ov -format UDZO "${DMG_NAME}"
      fi
    else
      warn "create-dmg not installed; using hdiutil."
      hdiutil create -volname "${APP_NAME}" -srcfolder "${APP_BUNDLE_DIR}" -ov -format UDZO "${DMG_NAME}"
    fi
  fi
  ok "DMG created: ${DMG_NAME}"
fi

#######################################
# Install
#######################################
if [ $DO_INSTALL -eq 1 ]; then
  if [ -d "/Applications" ]; then
    log "Installing to /Applications"
    cp -R "${APP_BUNDLE_DIR}" /Applications/
    ok "Installed to /Applications/${APP_NAME}.app"
  else
    warn "/Applications not found; skipping install."
  fi
fi

#######################################
# Summary
#######################################
echo ""
echo -e "${CYAN}Build Summary${NC}"
echo "  App Name:        ${APP_NAME}"
echo "  Version:         ${VERSION}"
echo "  Bundle ID:       ${BUNDLE_ID}"
echo "  Universal:       $([ $SKIP_UNIVERSAL -eq 0 ] && echo yes || echo no)"
echo "  Signed:          $([ -n "${CODE_SIGN_IDENTITY:-}" ] && [ $NO_SIGN -eq 0 ] && echo yes || echo no)"
echo "  App Bundle:      ${APP_BUNDLE_DIR}"
[ $DO_DMG -eq 1 ] && echo "  DMG:             ${DMG_NAME}"
[ $DO_INSTALL -eq 1 ] && echo "  Installed:       /Applications/${APP_NAME}.app (if /Applications existed)"
echo ""
ok "Build script completed successfully."

exit 0
