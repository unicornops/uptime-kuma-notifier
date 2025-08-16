# Quick Start Guide - macOS Packaging

This guide will get you up and running with the macOS packaging system in under 5 minutes.

## 🚀 One-Command Setup

```bash
# Install all dependencies and make scripts executable
chmod +x scripts/*.sh && ./scripts/install_dependencies.sh
```

## 📦 Build Commands

```bash
# Create macOS app bundle
make package

# Create DMG installer
make dmg

# Full release build (clean + package + dmg)
make release

# Install to Applications folder
make install
```

## 🔐 Code Signing & Notarization

```bash
# Code sign with Developer ID
codesign --force --deep --sign "Developer ID Application" "dist/Uptime Kuma Notifier.app"

# Notarize for distribution
export APPLE_ID="your.apple.id@example.com"
export APPLE_ID_PASSWORD="your-app-specific-password"
make notarize
```

## 📁 What Gets Created

```
dist/
├── Uptime Kuma Notifier.app/          # macOS app bundle
│   └── Contents/
│       ├── MacOS/uptime_kuma_notifier # Your Rust binary
│       ├── Resources/                  # Config files & icons
│       ├── Info.plist                  # App metadata
│       └── Entitlements.plist          # Security permissions
└── Uptime Kuma Notifier-0.1.0.dmg     # DMG installer
```

## 🎯 Key Features

- ✅ **Standard macOS app bundle** - Drag & drop installation
- ✅ **Professional DMG installer** - Easy distribution
- ✅ **App sandboxing** - Enhanced security
- ✅ **Code signing support** - No "unidentified developer" warnings
- ✅ **Notarization ready** - Distribution outside Mac App Store
- ✅ **Universal binary support** - Intel + Apple Silicon
- ✅ **Automated CI/CD** - GitHub Actions workflow included

## 🛠️ Available Commands

```bash
make help          # Show all available commands
make build         # Build Rust app only
make clean         # Clean build artifacts
make package       # Create app bundle
make dmg           # Create DMG installer
make notarize      # Notarize the app
make install       # Install to Applications
make release       # Full release build
make test          # Run tests
make check         # Code quality checks
make fmt           # Format code
```

## 🔧 Troubleshooting

### Common Issues

1. **"Permission denied"** - Run `chmod +x scripts/*.sh`
2. **"Command not found"** - Run `./scripts/install_dependencies.sh`
3. **Build fails** - Run `make clean && make package`
4. **Icon not showing** - Run `./scripts/create_icon.sh`

### Get Help

```bash
# Show detailed help
make help

# Check project info
make info

# View available targets
make -n package
```

## 📚 Next Steps

1. **Customize**: Edit `Info.plist` and `Entitlements.plist`
2. **Add Icon**: Replace placeholder with your custom icon
3. **Configure**: Set up code signing identity
4. **Distribute**: Share your `.app` or `.dmg` file

## 🌟 Pro Tips

- Use `make release` for production builds
- Set `CODE_SIGN_IDENTITY` environment variable for automatic signing
- Run `make notarize` before distributing outside Mac App Store
- Use GitHub Actions for automated builds on releases

---

**Need more details?** See [PACKAGING.md](PACKAGING.md) for comprehensive documentation.
