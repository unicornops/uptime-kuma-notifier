#!/bin/bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
APP_NAME="Uptime Kuma Notifier"
BUNDLE_ID="com.unicornops.uptime-kuma-notifier"
VERSION="0.1.0"
BUILD_DIR="target/release"
APP_BUNDLE_DIR="dist/${APP_NAME}.app"
CONTENTS_DIR="${APP_BUNDLE_DIR}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"
RESOURCES_DIR="${CONTENTS_DIR}/Resources"

echo -e "${BLUE}🚀 Building ${APP_NAME} v${VERSION}${NC}"

# Clean previous builds
echo -e "${YELLOW}🧹 Cleaning previous builds...${NC}"
rm -rf dist/
rm -rf target/release/

# Build the Rust application
echo -e "${YELLOW}🔨 Building Rust application...${NC}"
cargo build --release

if [ ! -f "${BUILD_DIR}/uptime_kuma_notifier" ]; then
    echo -e "${RED}❌ Build failed: uptime_kuma_notifier binary not found${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Rust build successful${NC}"

# Create app bundle structure
echo -e "${YELLOW}📁 Creating app bundle structure...${NC}"
mkdir -p "${MACOS_DIR}"
mkdir -p "${RESOURCES_DIR}"

# Copy binary
echo -e "${YELLOW}📦 Copying binary...${NC}"
cp "${BUILD_DIR}/uptime_kuma_notifier" "${MACOS_DIR}/"

# Copy Info.plist
echo -e "${YELLOW}📋 Copying Info.plist...${NC}"
cp "Info.plist" "${CONTENTS_DIR}/"

# Copy Entitlements.plist
echo -e "${YELLOW}🔒 Copying Entitlements.plist...${NC}"
cp "Entitlements.plist" "${CONTENTS_DIR}/"

# Copy configuration example
echo -e "${YELLOW}⚙️  Copying configuration files...${NC}"
cp "config.example.toml" "${RESOURCES_DIR}/"
cp "README.md" "${RESOURCES_DIR}/"

# Create app icon
echo -e "${YELLOW}🎨 Creating app icon...${NC}"
./scripts/create_icon.sh

# Set permissions
echo -e "${YELLOW}🔐 Setting permissions...${NC}"
chmod +x "${MACOS_DIR}/uptime_kuma_notifier"
chmod 644 "${CONTENTS_DIR}/Info.plist"
chmod 644 "${CONTENTS_DIR}/Entitlements.plist"
chmod 644 "${RESOURCES_DIR}/"*

# Create DMG if requested
if [ "$1" = "--dmg" ]; then
    echo -e "${YELLOW}💾 Creating DMG package...${NC}"
    
    # Install create-dmg if not present
    if ! command -v create-dmg &> /dev/null; then
        echo -e "${YELLOW}📦 Installing create-dmg...${NC}"
        if command -v brew &> /dev/null; then
            brew install create-dmg
        else
            echo -e "${RED}❌ create-dmg not found and brew not available${NC}"
            echo -e "${YELLOW}💡 Install manually: https://github.com/create-dmg/create-dmg${NC}"
        fi
    fi
    
    if command -v create-dmg &> /dev/null; then
        DMG_NAME="dist/${APP_NAME}-${VERSION}.dmg"
        create-dmg \
            --volname "${APP_NAME}" \
            --volicon "AppIcon.icns" \
            --window-pos 200 120 \
            --window-size 600 300 \
            --icon-size 100 \
            --icon "${APP_NAME}" 175 120 \
            --hide-extension "${APP_NAME}" \
            --app-drop-link 425 120 \
            "${DMG_NAME}" \
            "${APP_BUNDLE_DIR}/"
        
        echo -e "${GREEN}✅ DMG created: ${DMG_NAME}${NC}"
    fi
fi

# Code signing (if identity is available)
if [ -n "$CODE_SIGN_IDENTITY" ]; then
    echo -e "${YELLOW}🔐 Code signing with identity: ${CODE_SIGN_IDENTITY}${NC}"
    codesign --force --deep --sign "${CODE_SIGN_IDENTITY}" "${APP_BUNDLE_DIR}"
    echo -e "${GREEN}✅ Code signing complete${NC}"
elif [ -n "$(security find-identity -v -p codesigning | grep 'Developer ID Application')" ]; then
    echo -e "${YELLOW}🔐 Code signing with Developer ID...${NC}"
    codesign --force --deep --sign "Developer ID Application" "${APP_BUNDLE_DIR}"
    echo -e "${GREEN}✅ Code signing complete${NC}"
else
    echo -e "${YELLOW}⚠️  No code signing identity found - app will not be notarized${NC}"
    echo -e "${YELLOW}💡 Set CODE_SIGN_IDENTITY environment variable or use Developer ID${NC}"
fi

# Verify app bundle
echo -e "${YELLOW}🔍 Verifying app bundle...${NC}"
if codesign -dv "${APP_BUNDLE_DIR}" 2>/dev/null; then
    echo -e "${GREEN}✅ App bundle verification successful${NC}"
else
    echo -e "${YELLOW}⚠️  App bundle verification failed (expected for unsigned apps)${NC}"
fi

echo -e "${GREEN}🎉 Build complete!${NC}"
echo -e "${BLUE}📱 App bundle: ${APP_BUNDLE_DIR}${NC}"
echo -e "${BLUE}📁 Distribution ready in: dist/${NC}"

# Optional: Install to Applications
if [ "$1" = "--install" ]; then
    echo -e "${YELLOW}📥 Installing to Applications folder...${NC}"
    cp -R "${APP_BUNDLE_DIR}" "/Applications/"
    echo -e "${GREEN}✅ Installed to /Applications/${NC}"
fi
