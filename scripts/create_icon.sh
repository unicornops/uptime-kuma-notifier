#!/bin/bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🎨 Creating placeholder app icon${NC}"

# Check if we're on macOS
if [[ "$OSTYPE" != "darwin"* ]]; then
    echo -e "${RED}❌ This script is for macOS only${NC}"
    exit 1
fi

# Create Resources directory if it doesn't exist
mkdir -p "dist/Uptime Kuma Notifier.app/Contents/Resources"

echo -e "${YELLOW}🔧 Creating icon directory structure...${NC}"

# Create icon set directory
mkdir -p "dist/Uptime Kuma Notifier.app/Contents/Resources/AppIcon.iconset"

echo -e "${GREEN}✅ Icon directory structure created${NC}"
echo -e "${BLUE}📁 Icon directories created in: dist/Uptime Kuma Notifier.app/Contents/Resources/${NC}"

# Update Info.plist to reference the icon
if [ -f "dist/Uptime Kuma Notifier.app/Contents/Info.plist" ]; then
    echo -e "${YELLOW}📋 Updating Info.plist icon references...${NC}"
    
    # For now, just use a generic icon name
    sed -i '' 's/<string>AppIcon<\/string>/<string>AppIcon.icns<\/string>/g' "dist/Uptime Kuma Notifier.app/Contents/Info.plist"
    echo -e "${GREEN}✅ Info.plist updated${NC}"
else
    echo -e "${YELLOW}⚠️  Info.plist not found, icon references not updated${NC}"
fi

echo -e "${GREEN}🎉 Icon setup complete!${NC}"
echo -e "${YELLOW}💡 Note: You can add your own AppIcon.icns file to the Resources directory${NC}"
