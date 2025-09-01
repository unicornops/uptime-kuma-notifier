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
# Determine project name (prefer Cargo package name) for artifact filenames
PROJECT_NAME=""
if [ -f Cargo.toml ]; then
    PROJECT_NAME=$(grep -E '^name\s*=' Cargo.toml | head -1 | sed -E 's/name\s*=\s*"([^"]+)".*/\1/') || true
fi
# Fallback: derive from APP_NAME (replace spaces with underscores)
if [ -z "${PROJECT_NAME:-}" ]; then
    PROJECT_NAME="${APP_NAME// /_}"
fi
# Sanitize PROJECT_NAME for filenames
PROJECT_NAME_SAFE=$(echo "${PROJECT_NAME}" | tr ' ' '_' | tr '/' '_' | sed -E 's/^"+//; s/"+$//')

APP_BUNDLE_DIR="dist/${APP_NAME}.app"
BUNDLE_ID="com.unicornops.uptime-kuma-notifier"

echo -e "${BLUE}🔐 Notarizing ${APP_NAME} for macOS distribution${NC}"

# Check if app bundle exists
if [ ! -d "${APP_BUNDLE_DIR}" ]; then
    echo -e "${RED}❌ App bundle not found: ${APP_BUNDLE_DIR}${NC}"
    echo -e "${YELLOW}💡 Run the build script first: ./scripts/build_package.sh${NC}"
    exit 1
fi

# Check for required environment variables
if [ -z "$APPLE_ID" ] || [ -z "$APPLE_ID_PASSWORD" ]; then
    echo -e "${RED}❌ Missing required environment variables${NC}"
    echo -e "${YELLOW}💡 Set the following environment variables:${NC}"
    echo -e "${YELLOW}   APPLE_ID=your.apple.id@example.com${NC}"
    echo -e "${YELLOW}   APPLE_ID_PASSWORD=your-app-specific-password${NC}"
    echo -e "${YELLOW}💡 Note: Use an app-specific password, not your main Apple ID password${NC}"
    exit 1
fi

# Check if app is code signed
if ! codesign -dv "${APP_BUNDLE_DIR}" &>/dev/null; then
    echo -e "${RED}❌ App is not code signed${NC}"
    echo -e "${YELLOW}💡 Code sign the app first:${NC}"
    echo -e "${YELLOW}   codesign --force --deep --sign 'Developer ID Application' '${APP_BUNDLE_DIR}'${NC}"
    exit 1
fi

echo -e "${GREEN}✅ App bundle found and code signed${NC}"

# Create zip file for notarization
# Use the Cargo package name (sanitized) for the artifact filename
ZIP_FILE="dist/${PROJECT_NAME_SAFE}-notarize.zip"
echo -e "${YELLOW}📦 Creating zip file for notarization: ${ZIP_FILE}${NC}"
ditto -c -k --keepParent "${APP_BUNDLE_DIR}" "${ZIP_FILE}"

echo -e "${GREEN}✅ Zip file created: ${ZIP_FILE}${NC}"

# Submit for notarization
echo -e "${YELLOW}🚀 Submitting for notarization...${NC}"
NOTARIZATION_RESPONSE=$(xcrun notarytool submit "${ZIP_FILE}" \
    --apple-id "${APPLE_ID}" \
    --password "${APPLE_ID_PASSWORD}" \
    --team-id "${TEAM_ID:-}" \
    --wait)

echo -e "${GREEN}✅ Notarization response received${NC}"

# Extract submission ID for status checking
SUBMISSION_ID=$(echo "${NOTARIZATION_RESPONSE}" | grep -o 'id: [a-f0-9-]*' | cut -d' ' -f2)

if [ -z "$SUBMISSION_ID" ]; then
    echo -e "${RED}❌ Could not extract submission ID${NC}"
    echo -e "${YELLOW}📋 Full response:${NC}"
    echo "${NOTARIZATION_RESPONSE}"
    exit 1
fi

echo -e "${BLUE}📋 Submission ID: ${SUBMISSION_ID}${NC}"

# Wait for notarization to complete
echo -e "${YELLOW}⏳ Waiting for notarization to complete...${NC}"
while true; do
    STATUS_RESPONSE=$(xcrun notarytool wait "${SUBMISSION_ID}" \
        --apple-id "${APPLE_ID}" \
        --password "${APPLE_ID_PASSWORD}" \
        --team-id "${TEAM_ID:-}" 2>/dev/null || echo "processing")

    if [[ "${STATUS_RESPONSE}" == *"accepted"* ]]; then
        echo -e "${GREEN}✅ Notarization accepted!${NC}"
        break
    elif [[ "${STATUS_RESPONSE}" == *"rejected"* ]]; then
        echo -e "${RED}❌ Notarization rejected${NC}"
        echo -e "${YELLOW}📋 Checking logs...${NC}"
        xcrun notarytool log "${SUBMISSION_ID}" \
            --apple-id "${APPLE_ID}" \
            --password "${APPLE_ID_PASSWORD}" \
            --team-id "${TEAM_ID:-}"
        exit 1
    else
        echo -e "${YELLOW}⏳ Status: ${STATUS_RESPONSE}${NC}"
        sleep 10
    fi
done

# Staple the notarization ticket
echo -e "${YELLOW}📎 Stapling notarization ticket...${NC}"
xcrun stapler staple "${APP_BUNDLE_DIR}"

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ Notarization ticket stapled successfully${NC}"
else
    echo -e "${RED}❌ Failed to staple notarization ticket${NC}"
    exit 1
fi

# Verify the app
echo -e "${YELLOW}🔍 Verifying notarized app...${NC}"
if codesign -dv --verbose=4 "${APP_BUNDLE_DIR}" 2>&1 | grep -q "notarized"; then
    echo -e "${GREEN}✅ App is properly notarized and ready for distribution${NC}"
else
    echo -e "${YELLOW}⚠️  App verification inconclusive - check manually${NC}"
fi

# Clean up zip file
echo -e "${YELLOW}🧹 Cleaning up temporary files...${NC}"
rm -f "${ZIP_FILE}"

echo -e "${GREEN}🎉 Notarization complete!${NC}"
echo -e "${BLUE}📱 Your app is now ready for distribution outside the Mac App Store${NC}"
echo -e "${BLUE}📁 Notarized app: ${APP_BUNDLE_DIR}${NC}"

# Optional: Create DMG with notarized app
if [ "$1" = "--dmg" ]; then
    echo -e "${YELLOW}💾 Creating DMG with notarized app...${NC}"
    ./scripts/build_package.sh --dmg
fi
