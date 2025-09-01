# macOS Packaging Guide

This guide explains how to package the Uptime Kuma Notifier for macOS distribution.

## Overview

The packaging system creates a standard macOS `.app` bundle that can be:
- Distributed directly as an `.app` file
- Packaged into a `.dmg` installer
- Notarized for distribution outside the Mac App Store
- Code signed for security

## Prerequisites

### Required Tools

1. **Xcode Command Line Tools**
   ```bash
   xcode-select --install
   ```

2. **Rust Toolchain**
   ```bash
   curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
   ```

3. **Homebrew** (for additional tools)
   ```bash
   /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
   ```

### Optional Tools

- **create-dmg**: For creating DMG installers
- **Code signing identity**: For distribution outside Mac App Store

## Quick Start

### 1. Install Dependencies

```bash
# Make scripts executable and install dependencies
chmod +x scripts/*.sh
./scripts/install_dependencies.sh
```

### 2. Build and Package

```bash
# Create macOS app bundle
make package

# Create DMG installer
make dmg

# Full release build
make release
```

## Detailed Workflow

### Step 1: Build the App Bundle

```bash
make package
```

This command:
- Builds the Rust application in release mode
- Creates the proper macOS app bundle structure
- Copies necessary files (Info.plist, Entitlements.plist, etc.)
- Sets appropriate permissions

**Output**: `dist/Uptime Kuma Notifier.app/`

### Step 2: Create DMG Installer (Optional)

```bash
make dmg
```

This creates a professional DMG installer with:
- Proper window positioning and sizing
- App icon placement
- Applications folder link
- Custom volume name

**Output**: `dist/Uptime Kuma Notifier-0.1.0.dmg`

### Step 3: Code Signing (Recommended)

```bash
# Using Developer ID
codesign --force --deep --sign "Developer ID Application" "dist/Uptime Kuma Notifier.app"

# Using custom identity
export CODE_SIGN_IDENTITY="Your Name (XXXXXXXXXX)"
make package
```

### Step 4: Notarization (Required for Distribution)

```bash
# Set environment variables
export APPLE_ID="your.apple.id@example.com"
export APPLE_ID_PASSWORD="your-app-specific-password"
export TEAM_ID="XXXXXXXXXX"  # Optional

# Notarize the app
make notarize
```

**Note**: Use an app-specific password, not your main Apple ID password.

## File Structure

```
dist/
├── Uptime Kuma Notifier.app/
│   └── Contents/
│       ├── MacOS/
│       │   └── uptime_kuma_notifier          # Binary
│       ├── Resources/
│       │   ├── config.example.toml           # Config template
│       │   └── README.md                     # Documentation
│       ├── Info.plist                        # App metadata
│       └── Entitlements.plist                # Security permissions
└── Uptime Kuma Notifier-0.1.0.dmg           # Installer (if created)
```

## Configuration Files

### Info.plist

Defines the app's metadata:
- Bundle identifier
- Version information
- Minimum macOS version
- App permissions and capabilities
- Document type associations

### Entitlements.plist

Defines security permissions:
- App sandboxing
- Network access
- File system access
- User-selected file access

## Code Signing

### Why Code Sign?

- Prevents "unidentified developer" warnings
- Required for notarization
- Enables distribution outside Mac App Store
- Improves user trust

### Available Identities

```bash
# List available identities
security find-identity -v -p codesigning

# Common identities:
# - "Mac Developer" (for development)
# - "Developer ID Application" (for distribution)
# - "Apple Development" (for App Store)
```

### Signing Commands

```bash
# Sign the app bundle
codesign --force --deep --sign "Developer ID Application" "dist/Uptime Kuma Notifier.app"

# Verify signing
codesign -dv "dist/Uptime Kuma Notifier.app"

# Verify and show details
codesign -dv --verbose=4 "dist/Uptime Kuma Notifier.app"
```

## Notarization

### What is Notarization?

Notarization is Apple's security process that:
- Scans your app for malicious code
- Verifies your developer identity
- Allows distribution without "unidentified developer" warnings
- Is required for distribution outside the Mac App Store

### Notarization Process

1. **Submit for scanning**
   ```bash
   xcrun notarytool submit "app.zip" \
     --apple-id "your.apple.id@example.com" \
     --password "app-specific-password"
   ```

2. **Wait for completion**
   ```bash
   xcrun notarytool wait "submission-id" \
     --apple-id "your.apple.id@example.com" \
     --password "app-specific-password"
   ```

3. **Staple the ticket**
   ```bash
   xcrun stapler staple "Uptime Kuma Notifier.app"
   ```

### Environment Variables

```bash
export APPLE_ID="your.apple.id@example.com"
export APPLE_ID_PASSWORD="your-app-specific-password"
export TEAM_ID="XXXXXXXXXX"  # Optional
```

## Distribution Options

### 1. Direct App Distribution

- Share the `.app` file directly
- Users can drag to Applications folder
- No installer required
- Good for technical users

### 2. DMG Installer

- Professional appearance
- Easy installation process
- Can include additional files
- Good for general distribution

### 3. Mac App Store

- Requires Apple Developer Program ($99/year)
- Automatic updates
- User trust
- Requires App Store review

### 4. Homebrew Cask

- Command-line installation
- Automatic updates
- Good for developers
- Requires formula submission

## Troubleshooting

### Common Issues

#### Build Failures

```bash
# Clean and rebuild
make clean
make package

# Check Rust toolchain
rustup show
rustup target list
```

#### Code Signing Issues

```bash
# Check available identities
security find-identity -v -p codesigning

# Verify app structure
codesign -dv "dist/Uptime Kuma Notifier.app"

# Check entitlements
codesign -d --entitlements - "dist/Uptime Kuma Notifier.app"
```

#### Notarization Issues

```bash
# Check logs
xcrun notarytool log "submission-id" \
  --apple-id "your.apple.id@example.com" \
  --password "app-specific-password"

# Verify notarization
spctl --assess --type exec "dist/Uptime Kuma Notifier.app"
```

### Debug Mode

```bash
# Enable verbose output
RUST_LOG=debug make package

# Check app bundle contents
ls -la "dist/Uptime Kuma Notifier.app/Contents/"

# Verify binary
file "dist/Uptime Kuma Notifier.app/Contents/MacOS/uptime_kuma_notifier"
```

## Advanced Configuration

### Custom App Icon

1. Create `.icns` file
2. Place in `Resources/` directory
3. Update `Info.plist` references

### Custom Entitlements

Edit `Entitlements.plist` to add:
- Camera access
- Microphone access
- Location services
- iCloud access

### Universal Binary

```bash
# Build for both architectures
rustup target add x86_64-apple-darwin
rustup target add aarch64-apple-darwin

# Create universal binary
lipo -create \
  target/x86_64-apple-darwin/release/uptime_kuma_notifier \
  target/aarch64-apple-darwin/release/uptime_kuma_notifier \
  -output target/universal/uptime_kuma_notifier
```

## CI/CD Integration

### GitHub Actions Example

```yaml
name: Build and Package

on:
  release:
    types: [published]

jobs:
  package:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v3
      - uses: actions-rs/toolchain@v1
        with:
          toolchain: stable
          target: x86_64-apple-darwin, aarch64-apple-darwin
      
      - name: Build and Package
        run: |
          chmod +x scripts/*.sh
          make release
      
      - name: Upload Artifacts
        uses: actions/upload-artifact@v3
        with:
          name: macos-package
          path: dist/
```

## Security Considerations

### App Sandboxing

- Enabled by default
- Restricts app capabilities
- Improves security
- May require entitlements for certain features

### Network Security

- HTTPS required by default
- Localhost exceptions configured
- Network client access enabled
- No arbitrary network loads

### File Access

- User-selected files only
- Downloads folder access
- Application support folder access
- No arbitrary file system access

## Support

For packaging issues:
1. Check the troubleshooting section
2. Review console output
3. Verify file permissions
4. Check code signing status
5. Open an issue with detailed information

## Resources

- [Apple Developer Documentation](https://developer.apple.com/)
- [Code Signing Guide](https://developer.apple.com/support/code-signing/)
- [Notarization Guide](https://developer.apple.com/documentation/security/notarizing_macos_software_before_distribution)
- [App Sandboxing](https://developer.apple.com/app-sandboxing/)
- [macOS App Distribution](https://developer.apple.com/distribute/)
