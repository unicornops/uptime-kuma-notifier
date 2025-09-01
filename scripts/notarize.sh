#!/usr/bin/env bash
set -euo pipefail

# Notarize a DMG (preferred) or create a DMG from a signed .app and notarize it.
# Expects the following environment variables to be set:
#   APPLE_ID            - your Apple ID email (recommended to keep as a secret in CI)
#   APPLE_ID_PASSWORD   - an app-specific password generated at appleid.apple.com
#   TEAM_ID             - (optional) your Apple Team ID
#   CODE_SIGN_IDENTITY  - (optional) explicit codesign identity to use if signing is needed
#
# Behavior:
# 1. If a signed DMG is present in dist/ (preferably *-signed.dmg), use it.
# 2. Otherwise, if a signed .app is present in dist/, create a DMG containing the signed .app.
# 3. Submit the DMG to Apple's notary service using `xcrun notarytool` and wait for completion.
# 4. Staple the notarization ticket to the DMG and validate the stapled result.
#
# Note: This script assumes Xcode command line tools are available on the machine (macOS runner).
#       APPLE_ID_PASSWORD must be an app-specific password, not your main Apple ID password.

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

APP_NAME="Uptime Kuma Notifier"

# Determine project/package name (for artifact names)
PROJECT_NAME=""
if [ -f Cargo.toml ]; then
    PROJECT_NAME=$(grep -E '^name\s*=' Cargo.toml | head -1 | sed -E 's/name\s*=\s*"([^"]+)".*/\1/') || true
fi
if [ -z "${PROJECT_NAME:-}" ]; then
    PROJECT_NAME="${APP_NAME// /_}"
fi
PROJECT_NAME_SAFE=$(echo "${PROJECT_NAME}" | tr ' ' '_' | tr '/' '_' | sed -E 's/^"+//; s/"+$//')

DIST_DIR="dist"
APP_BUNDLE_DIR="${DIST_DIR}/${APP_NAME}.app"

echo -e "${BLUE}🔐 macOS Notarization helper${NC}"
echo -e "${BLUE}📦 Project: ${PROJECT_NAME} | App: ${APP_NAME}${NC}"

# Validate required env vars
if [ -z "${APPLE_ID:-}" ] || [ -z "${APPLE_ID_PASSWORD:-}" ]; then
    echo -e "${RED}❌ Missing required environment variables.${NC}"
    echo -e "${YELLOW}Please set APPLE_ID and APPLE_ID_PASSWORD (app-specific password).${NC}"
    exit 1
fi

# Find an existing DMG to notarize (prefer *-signed.dmg)
DMG=""
if compgen -G "${DIST_DIR}/*-signed.dmg" >/dev/null 2>&1; then
    DMG=$(ls ${DIST_DIR}/*-signed.dmg | head -n1)
elif compgen -G "${DIST_DIR}/*.dmg" >/dev/null 2>&1; then
    DMG=$(ls ${DIST_DIR}/*.dmg | head -n1)
fi

# If no DMG, see if we have an app bundle to create one
if [ -z "${DMG}" ]; then
    if [ -d "${APP_BUNDLE_DIR}" ]; then
        echo -e "${YELLOW}ℹ️  No DMG found; will create a DMG from the .app: ${APP_BUNDLE_DIR}${NC}"

        # Ensure app is code signed (or sign it if CODE_SIGN_IDENTITY provided)
        if ! codesign -v "${APP_BUNDLE_DIR}" >/dev/null 2>&1; then
            if [ -n "${CODE_SIGN_IDENTITY:-}" ]; then
                echo -e "${YELLOW}🔁 App not signed; attempting to sign with provided CODE_SIGN_IDENTITY${NC}"
                codesign --force --deep --options runtime --sign "${CODE_SIGN_IDENTITY}" "${APP_BUNDLE_DIR}"
            else
                echo -e "${RED}❌ App bundle is not code signed and no CODE_SIGN_IDENTITY provided.${NC}"
                echo -e "${YELLOW}💡 Either sign the app locally or provide CODE_SIGN_IDENTITY in the environment.${NC}"
                exit 1
            fi
        else
            echo -e "${GREEN}✅ App bundle is already code signed${NC}"
        fi

        # Create a signed DMG (name based on project)
        DMG="${DIST_DIR}/${PROJECT_NAME_SAFE}-signed.dmg"
        echo -e "${YELLOW}📦 Creating DMG: ${DMG}${NC}"
        # Remove existing DMG if present
        rm -f "${DMG}" || true
        hdiutil create -volname "$(basename "${APP_BUNDLE_DIR}" .app)" -srcfolder "${APP_BUNDLE_DIR}" -ov -format UDZO "${DMG}"
        echo -e "${GREEN}✅ DMG created: ${DMG}${NC}"
    else
        echo -e "${RED}❌ No DMG found in ${DIST_DIR} and no app bundle at ${APP_BUNDLE_DIR}.${NC}"
        echo -e "${YELLOW}💡 Build the project and create a signed .app or place a DMG into ${DIST_DIR}.${NC}"
        exit 1
    fi
else
    echo -e "${GREEN}✅ Found DMG to notarize: ${DMG}${NC}"
fi

# Double-check DMG exists
if [ ! -f "${DMG}" ]; then
    echo -e "${RED}❌ DMG file not found: ${DMG}${NC}"
    exit 1
fi

# Submit DMG for notarization
echo -e "${BLUE}🚀 Submitting ${DMG} for notarization (this may take a while)...${NC}"
NOTARIZE_CMD=(xcrun notarytool submit "${DMG}" --apple-id "${APPLE_ID}" --password "${APPLE_ID_PASSWORD}")
# include team-id if provided
if [ -n "${TEAM_ID:-}" ]; then
    NOTARIZE_CMD+=("--team-id" "${TEAM_ID}")
fi
# --wait to block until notarization completes
NOTARIZE_CMD+=("--wait")

set +o pipefail
# Capture the full response for diagnostics
NOTARIZE_OUTPUT="$("${NOTARIZE_CMD[@]}" 2>&1)" || NOTARIZE_RC=$? && NOTARIZE_RC=${NOTARIZE_RC:-0}
set -o pipefail

# If xcrun returned non-zero, print output and fail
if [ "${NOTARIZE_RC:-0}" -ne 0 ]; then
    echo -e "${RED}❌ notarytool reported a failure (exit code ${NOTARIZE_RC}).${NC}"
    echo -e "${YELLOW}📋 notarytool output:${NC}"
    echo "${NOTARIZE_OUTPUT}"
    # Try to show logs if possible: some responses include an id, try to extract and show logs
    SUB_ID=$(echo "${NOTARIZE_OUTPUT}" | grep -oE 'id: [a-f0-9-]+' | head -n1 | awk '{print $2}' || true)
    if [ -n "${SUB_ID}" ]; then
        echo -e "${YELLOW}📥 Attempting to fetch notarytool log for submission id ${SUB_ID}${NC}"
        xcrun notarytool log "${SUB_ID}" --apple-id "${APPLE_ID}" --password "${APPLE_ID_PASSWORD}" --team-id "${TEAM_ID:-}" || true
    fi
    exit 1
fi

echo -e "${GREEN}✅ Notarization submission completed (accepted or other final state).${NC}"
echo -e "${BLUE}📋 notarytool output:${NC}"
echo "${NOTARIZE_OUTPUT}"

# Try to extract a submission id from the output for optional log lookup
SUBMISSION_ID=$(echo "${NOTARIZE_OUTPUT}" | grep -oE 'id: [a-f0-9-]+' | head -n1 | awk '{print $2}' || true)
if [ -n "${SUBMISSION_ID}" ]; then
    echo -e "${BLUE}📌 Submission ID: ${SUBMISSION_ID}${NC}"
fi

# Staple the notarization ticket to the DMG
echo -e "${YELLOW}📎 Stapling notarization ticket to ${DMG}${NC}"
if xcrun stapler staple "${DMG}"; then
    echo -e "${GREEN}✅ Staple succeeded for ${DMG}${NC}"
else
    echo -e "${RED}⚠️  Staple failed for ${DMG} (non-fatal).${NC}"
    # continue, but indicate potential issues
fi

# Validate the stapled DMG (non-fatal)
echo -e "${BLUE}🔍 Validating stapled DMG (non-fatal)...${NC}"
if xcrun stapler validate "${DMG}" >/dev/null 2>&1; then
    echo -e "${GREEN}✅ Stapled DMG validated successfully.${NC}"
else
    echo -e "${YELLOW}⚠️  Stapled DMG validation failed or inconclusive; inspect manually.${NC}"
fi

echo -e "${GREEN}🎉 Notarization flow complete. Notarized DMG: ${DMG}${NC}"
