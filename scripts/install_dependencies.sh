#!/bin/bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}📦 Installing dependencies for macOS packaging${NC}"

# Check if we're on macOS
if [[ "$OSTYPE" != "darwin"* ]]; then
    echo -e "${RED}❌ This script is for macOS only${NC}"
    exit 1
fi

# Check if Homebrew is installed
if ! command -v brew &> /dev/null; then
    echo -e "${YELLOW}🍺 Homebrew not found. Installing...${NC}"
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

    # Add Homebrew to PATH if needed
    if [[ -f "/opt/homebrew/bin/brew" ]]; then
        echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile
        eval "$(/opt/homebrew/bin/brew shellenv)"
    elif [[ -f "/usr/local/bin/brew" ]]; then
        echo 'eval "$(/usr/local/bin/brew shellenv)"' >> ~/.zprofile
        eval "$(/usr/local/bin/brew shellenv)"
    fi
else
    echo -e "${GREEN}✅ Homebrew already installed${NC}"
fi

# Update Homebrew (skipped in CI or when HOMEBREW_NO_AUTO_UPDATE set)
if [ -n "${CI:-}" ]; then
    echo -e "${YELLOW}⚡ Skipping Homebrew update in CI (HOMEBREW_NO_AUTO_UPDATE=1)${NC}"
    export HOMEBREW_NO_AUTO_UPDATE=1
elif [ -n "${HOMEBREW_NO_AUTO_UPDATE:-}" ]; then
    echo -e "${YELLOW}⚡ Skipping Homebrew update because HOMEBREW_NO_AUTO_UPDATE is set${NC}"
else
    echo -e "${YELLOW}🔄 Updating Homebrew...${NC}"
    brew update
fi

# Install Rust if not present
if ! command -v rustc &> /dev/null; then
    echo -e "${YELLOW}🦀 Installing Rust...${NC}"
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
    source ~/.cargo/env
    echo -e "${GREEN}✅ Rust installed${NC}"
else
    echo -e "${GREEN}✅ Rust already installed: $(rustc --version)${NC}"
fi

# Install create-dmg for DMG creation
if ! command -v create-dmg &> /dev/null; then
    echo -e "${YELLOW}💾 Installing create-dmg...${NC}"
    brew install create-dmg
    echo -e "${GREEN}✅ create-dmg installed${NC}"
else
    echo -e "${GREEN}✅ create-dmg already installed${NC}"
fi

# Install additional useful tools
echo -e "${YELLOW}🔧 Installing additional tools...${NC}"

# Install jq for JSON processing
if ! command -v jq &> /dev/null; then
    brew install jq
    echo -e "${GREEN}✅ jq installed${NC}"
else
    echo -e "${GREEN}✅ jq already installed${NC}"
fi

# Install ripgrep for fast searching
if ! command -v rg &> /dev/null; then
    brew install ripgrep
    echo -e "${GREEN}✅ ripgrep installed${NC}"
else
    echo -e "${GREEN}✅ ripgrep already installed${NC}"
fi

# Install fd for fast file finding
if ! command -v fd &> /dev/null; then
    brew install fd
    echo -e "${GREEN}✅ fd installed${NC}"
else
    echo -e "${GREEN}✅ fd already installed${NC}"
fi

# Check Xcode Command Line Tools
if ! xcode-select -p &> /dev/null; then
    echo -e "${YELLOW}🛠️  Installing Xcode Command Line Tools...${NC}"
    xcode-select --install
    echo -e "${YELLOW}⚠️  Please complete the Xcode Command Line Tools installation in the popup window${NC}"
    echo -e "${YELLOW}💡 After installation, run this script again${NC}"
    exit 1
else
    echo -e "${GREEN}✅ Xcode Command Line Tools already installed${NC}"
fi

# Check for code signing identities
echo -e "${YELLOW}🔐 Checking code signing identities...${NC}"
if security find-identity -v -p codesigning | grep -q "Developer ID Application"; then
    echo -e "${GREEN}✅ Developer ID Application found${NC}"
elif security find-identity -v -p codesigning | grep -q "Mac Developer"; then
    echo -e "${GREEN}✅ Mac Developer identity found${NC}"
else
    echo -e "${YELLOW}⚠️  No code signing identity found${NC}"
    echo -e "${YELLOW}💡 You can still build the app, but it won't be code signed${NC}"
    echo -e "${YELLOW}💡 To distribute outside the Mac App Store, you'll need a Developer ID${NC}"
fi

# Make scripts executable
echo -e "${YELLOW}🔧 Making scripts executable...${NC}"
chmod +x scripts/*.sh

# Verify Rust toolchain
echo -e "${YELLOW}🔍 Verifying Rust toolchain...${NC}"
rustup target list | grep -q "x86_64-apple-darwin" && echo -e "${GREEN}✅ x86_64 target available${NC}" || echo -e "${YELLOW}⚠️  x86_64 target not available${NC}"
rustup target list | grep -q "aarch64-apple-darwin" && echo -e "${GREEN}✅ Apple Silicon target available${NC}" || echo -e "${YELLOW}⚠️  Apple Silicon target not available${NC}"

# Add common targets
echo -e "${YELLOW}🎯 Adding common targets...${NC}"
rustup target add x86_64-apple-darwin
rustup target add aarch64-apple-darwin

echo -e "${GREEN}🎉 Dependencies installation complete!${NC}"
echo -e "${BLUE}📋 Next steps:${NC}"
echo -e "${BLUE}   1. Run 'make package' to create the app bundle${NC}"
echo -e "${BLUE}   2. Run 'make dmg' to create a DMG installer${NC}"
echo -e "${BLUE}   3. Run 'make notarize' to notarize for distribution${NC}"
echo -e "${BLUE}   4. Run 'make help' to see all available commands${NC}"
