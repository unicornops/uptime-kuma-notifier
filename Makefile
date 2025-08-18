# Makefile for Uptime Kuma Notifier macOS Package
# This Makefile provides convenient commands for building and packaging

.PHONY: help build universal clean package dmg notarize install release

# Configuration
APP_NAME = Uptime Kuma Notifier
VERSION = 0.1.0
BUILD_DIR = target/release
DIST_DIR = dist
APP_BUNDLE = $(DIST_DIR)/$(APP_NAME).app

# Default target
help:
	@echo "Uptime Kuma Notifier - macOS Package Build System"
	@echo ""
	@echo "Available targets:"
	@echo "  build      - Build the Rust application (host architecture only)"
	@echo "  universal  - Build universal (x86_64 + arm64) binary only"
	@echo "  clean      - Clean build artifacts"
	@echo "  package    - Create macOS app bundle"
	@echo "  dmg        - Create DMG installer"
	@echo "  notarize   - Notarize the app for distribution"
	@echo "  install    - Install to Applications folder"
	@echo "  release    - Full release build with DMG"
	@echo "  help       - Show this help message"
	@echo ""
	@echo "Environment variables:"
	@echo "  CODE_SIGN_IDENTITY - Code signing identity"
	@echo "  APPLE_ID          - Apple ID for notarization"
	@echo "  APPLE_ID_PASSWORD - App-specific password"
	@echo "  TEAM_ID           - Apple Developer Team ID"

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
