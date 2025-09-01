# Makefile for Uptime Kuma Notifier macOS Package
# This Makefile provides convenient commands for building and packaging

.PHONY: help build universal clean package dmg notarize install release

# Configuration
APP_NAME = Uptime Kuma Notifier
VERSION ?= 0.1.0
export VERSION
BUILD_DIR = target/release
DIST_DIR = dist
APP_BUNDLE = $(DIST_DIR)/$(APP_NAME).app

# Default target
help:
	@echo "Uptime Kuma Notifier - macOS Package Build System"
	@echo ""
	@echo "Quick usage examples:"
	@echo ""
	@echo "  # Build release binary (recommended to use the Makefile)"
	@echo "  make build"
	@echo ""
	@echo "  # Build a development (non-release) version"
	@echo "  make dev"
	@echo ""
	@echo "  # Create a macOS .app bundle (runs packaging scripts)"
	@echo "  make package"
	@echo ""
	@echo "  # Create a DMG installer (invokes package first)"
	@echo "  make dmg"
	@echo ""
	@echo "  # Full release flow: clean, package, dmg"
	@echo "  make release"
	@echo ""
	@echo "Other useful targets:"
	@echo "  make clean     - Clean build artifacts and dist directory"
	@echo "  make test      - Run unit and integration tests"
	@echo "  make check     - Run cargo check and cargo clippy"
	@echo "  make fmt       - Format source with cargo fmt"
	@echo "  make update    - Update Cargo dependencies (cargo update)"
	@echo "  make help      - Show this help message"
	@echo ""
	@echo "Why use the Makefile?"
	@echo "  The Makefile wraps cargo with packaging, signing, and distribution steps"
	@echo "  needed for macOS apps. Using the provided targets ensures a repeatable"
	@echo "  build and matches CI/packaging workflows (codesign, .app creation, DMG, notarize)."
	@echo ""
	@echo "Environment variables (used by packaging/notarization):"
	@echo "  CODE_SIGN_IDENTITY - Code signing identity (e.g. \"Developer ID Application: Your Name (TEAMID)\")"
	@echo "  APPLE_ID           - Apple ID for notarization (email)"
	@echo "  APPLE_ID_PASSWORD  - App-specific password for notarization (use an app-specific password)"
	@echo "  TEAM_ID            - Apple Developer Team ID (optional but useful for some signing flows)"
	@echo ""
	@echo "Environment variable examples:"
	@echo "  # Export your signing identity and Apple credentials for notarization"
	@echo "  export CODE_SIGN_IDENTITY=\"Developer ID Application: Example Name (ABCD1234)\""
	@echo "  export APPLE_ID=\"you@apple.com\""
	@echo "  export APPLE_ID_PASSWORD=\"app-specific-password-here\""
	@echo ""
	@echo "Notes and tips:"
	@echo "  - On macOS you may need Xcode command line tools for codesign, lipo, and related tools."
	@echo "  - Use 'make -n <target>' to preview commands without executing them."
	@echo "  - The 'package' target runs scripts in ./scripts/ which perform bundle creation and signing hooks."
	@echo "  - CI pipelines should call the same make targets to ensure parity with local builds."
	@echo ""
	@echo "Troubleshooting:"
	@echo "  - If a codesign or notarize step fails, ensure your Apple credentials and identity are correct,"
	@echo "    and that the machine has the necessary keychain access to the signing key."
	@echo "  - For quick development iteration you can still use 'cargo run' or 'cargo build',"
	@echo "    but those will not produce a distributable .app or DMG."
	@echo ""
	@echo "Examples recap:"
	@echo "  make build        # build release binary"
	@echo "  make package      # create .app bundle"
	@echo "  make dmg          # create installer DMG"
	@echo "  make release      # clean + package + dmg"

# Build the Rust application
build:
	@echo "🔨 Building Rust application..."
	cargo build --release
	@echo "✅ Build complete"

# Clean build artifacts
clean:
	@echo "🧹 Cleaning build artifacts..."
	cargo clean
	rm -rf $(DIST_DIR)
	@echo "✅ Clean complete"

# Create macOS app bundle
package:
	@echo "📦 Creating macOS app bundle..."
	@chmod +x scripts/build_package.sh
	./scripts/build_package.sh
	@echo "✅ Package complete"

# Create DMG installer
dmg: package
	@echo "💾 Creating DMG installer..."
	@chmod +x scripts/build_package.sh
	./scripts/build_package.sh --dmg
	@echo "✅ DMG creation complete"

# Notarize the app
notarize: package
	@echo "🔐 Notarizing app..."
	@chmod +x scripts/notarize.sh
	./scripts/notarize.sh
	@echo "✅ Notarization complete"

# Install to Applications folder
install: package
	@echo "📥 Installing to Applications folder..."
	@chmod +x scripts/build_package.sh
	./scripts/build_package.sh --install
	@echo "✅ Installation complete"

# Full release build
release: clean package dmg
	@echo "🎉 Release build complete!"
	@echo "📁 Distribution files in: $(DIST_DIR)"

# Development build
dev: clean
	@echo "🔨 Building development version..."
	cargo build
	@echo "✅ Development build complete"

# Run tests
test:
	@echo "🧪 Running tests..."
	cargo test
	@echo "✅ Tests complete"

# Check code
check:
	@echo "🔍 Checking code..."
	cargo check
	cargo clippy
	@echo "✅ Code check complete"

# Format code
fmt:
	@echo "✨ Formatting code..."
	cargo fmt
	@echo "✅ Code formatting complete"

# Update dependencies
update:
	@echo "📦 Updating dependencies..."
	cargo update
	@echo "✅ Dependencies updated"

# Show project info
info:
	@echo "📋 Project Information:"
	@echo "  Name: $(APP_NAME)"
	@echo "  Version: $(VERSION)"
	@echo "  Rust Edition: $(shell grep 'edition' Cargo.toml | cut -d'"' -f2)"
	@echo "  Default Host Target: $(shell rustc -vV | grep 'host:' | awk '{print $$2}')"
	@echo "  Universal Binary: $(UNIVERSAL_BINARY)"
	@echo "  Cargo Version: $(shell cargo --version)"
	@echo "  Rust Version: $(shell rustc --version)"

# Build universal (fat) binary without packaging
universal:
	@echo "🎯 Building universal binary (x86_64 + arm64)..."
	@for arch in $(ARCHS); do \
		echo "   -> $$arch"; \
		$(CARGO) build --release --target $$arch; \
	done
	@mkdir -p $(UNIVERSAL_DIR)
	@lipo -create $(foreach arch,$(ARCHS),target/$(arch)/release/uptime_kuma_notifier) -output $(UNIVERSAL_BINARY)
	@echo "✅ Universal binary ready: $(UNIVERSAL_BINARY)"
