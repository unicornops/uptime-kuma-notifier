# Uptime Kuma Notifier

A macOS menu bar application that displays the number of services that are up and down in your Uptime Kuma instance.

Important: We recommend using the provided `Makefile` for common workflows (building, packaging, testing, releasing). The `Makefile` encapsulates platform-specific details, packaging steps, code signing, and notarization. Use `make` targets rather than calling `cargo` directly unless you know what you need to do.

## Features

- Shows real-time status of your Uptime Kuma monitors in the macOS menu bar
- Displays format: "Up:X / Down:Y"
- Automatically updates every 30 seconds (configurable)
- Lightweight and runs in the background (no dock icon)
- Native macOS preferences window
- Universal binary support (Intel and Apple Silicon)
- Uses the reliable Uptime Kuma metrics endpoint
- Supports multiple authentication methods (Basic Auth, Bearer token)

## Prerequisites

- macOS 10.15+ (tested on macOS 14+)
- Rust toolchain (cargo, rustc) with stable channel
- Xcode command line tools (for codesign, lipo, etc.)
- Uptime Kuma instance running and accessible

## Installation

1. Clone this repository:
```bash
git clone https://github.com/unicornops/uptime-kuma-notifier.git
cd uptime-kuma-notifier
```

2. Configure the application (see Configuration section below)

3. Build and package using the `Makefile` (recommended):

- Build the Rust binary (release):
```bash
make build
```

- Create a macOS `.app` bundle:
```bash
make package
```

- Create a DMG installer (builds package first):
```bash
make dmg
```

- Full release build (clean, package, dmg):
```bash
make release
```

Why use `make`?
- The `Makefile` runs the correct `cargo` commands, sets expected environment variables, and invokes packaging scripts.
- Packaging, codesigning, and notarization are handled for you by targets like `package`, `notarize`, and `dmg`.
- It provides convenient shortcuts for development and release workflows (e.g. `make check`, `make fmt`, `make test`).

If you only want to run the app locally without packaging:
- After `make build`, run the release binary directly:
```bash
./target/release/uptime_kuma_notifier
```

If you prefer `cargo` for quick development builds, you can still run:
```bash
# Quick debug build
cargo build

# Run directly (development)
cargo run
```
But for packaging, distribution, and reproducible release builds prefer `make`.

## Configuration

### Native Preferences Window

1. **Right-click** the menu bar icon
2. **Select "Preferences..."** from the menu
3. A **native macOS preferences window** opens with fields for:
   - **API URL** - Your Uptime Kuma instance URL
   - **API Key** - Secure text field for your API key
   - **Refresh Interval** - Update frequency in seconds (5-3600, default 30)
   - **Show Notifications** - Toggle notification display
4. Use the **Test Connection** button to verify your settings
5. Click **Save** to apply

Preferences are stored in `~/Library/Application Support/uptime-kuma-notifier/`.

### Getting Your API Key

1. In your Uptime Kuma instance, go to Settings > API Keys
2. Create a new API key with appropriate permissions
3. Copy the API key and enter it in the preferences window

### API Endpoint

The application uses the **Metrics Endpoint** (`/metrics`):

- **Endpoint**: `/metrics`
- **Authentication**: HTTP Basic Auth with API key as password (preferred), Bearer token, or unauthenticated
- **Response Format**: Prometheus metrics format
- **Advantages**:
  - More reliable than other endpoints
  - Provides real-time monitor status
  - Standard Prometheus format
  - Includes all monitor information

Note: The metrics endpoint requires HTTP Basic Authentication where:
- Username: (empty string)
- Password: Your API key

The application will automatically try Basic Auth, then Bearer token, then unauthenticated access.

## Usage

1. Start the application:
```bash
# Recommended: build with make then run binary
make build
./target/release/uptime_kuma_notifier

# Or for development
cargo run
```

2. You'll see a new icon in your macOS menu bar showing your Uptime Kuma status
3. The icon displays: "Up:X / Down:Y" (X = up monitors, Y = down monitors)
4. Status updates automatically based on your refresh interval

### Menu Bar Interface

Right-click the menu bar icon for these options:

- **Preferences...**: Opens the native macOS preferences window
- **Quit**: Closes the application

## Development

### Project Structure

```
uptime-kuma-notifier/
├── src/
│   ├── main.rs                  # Main application, menu bar, status updates
│   ├── preferences.rs           # Preferences data model
│   ├── native_preferences.rs    # Native macOS preferences UI
│   └── simple_preferences.rs    # Preferences manager
├── scripts/
│   ├── build_package.sh         # Packaging script (universal binary, DMG)
│   ├── create_icon.sh           # Icon generation
│   ├── install_dependencies.sh  # Setup script
│   └── notarize.sh              # Apple notarization
├── .github/
│   ├── workflows/main.yml       # CI/CD pipeline
│   └── dependabot.yml           # Dependency updates
├── Cargo.toml                   # Dependencies and project configuration
├── Makefile                     # Build automation
├── Info.plist                   # macOS app metadata
├── Entitlements.plist           # App sandbox & security permissions
├── rust-toolchain.toml          # Rust toolchain configuration
├── cog.toml                     # Cocogitto conventional commits config
└── config.example.toml          # Example configuration file
```

### Dependencies

- `cacao` - macOS app framework
- `objc` / `objc2` - Objective-C runtime bindings
- `objc2-app-kit` / `objc2-foundation` - AppKit and Foundation bindings
- `reqwest` - HTTP client for API requests
- `serde` / `serde_json` - Serialization/deserialization
- `tokio` - Async runtime
- `dispatch` - Grand Central Dispatch bindings
- `plist` - Property list file handling
- `dirs` - Standard directory paths

### Building & Common Tasks (use `Makefile`)

Prefer `make` targets for standard tasks. The `Makefile` includes helpful targets:

- `make help` — Show available targets and usage info
- `make build` — Build the Rust application (release by default)
- `make dev` — Development build (non-release)
- `make clean` — Clean build artifacts and dist directory
- `make package` — Create macOS app bundle (.app)
- `make dmg` — Create a DMG installer (depends on `package`)
- `make notarize` — Notarize the app (requires Apple credentials)
- `make install` — Install the built app to `/Applications`
- `make release` — Full release flow (clean + package + dmg)
- `make universal` — Build universal binary (x86_64 + arm64) without packaging
- `make test` — Run tests
- `make check` — Run `cargo check` and `cargo clippy`
- `make fmt` — Run `cargo fmt`
- `make update` — Update dependencies (`cargo update`)
- `make info` — Show project information

Examples:
```bash
# Build and create an app bundle
make package

# Create a DMG for distribution
make dmg

# Prepare a release build (clean + package + dmg)
make release
```

Advanced: If you must use `cargo` directly for experimentation:
```bash
# Debug build
cargo build

# Release build
cargo build --release

# Run tests
cargo test

# Code checks
cargo check
cargo clippy
```
But note: packaging, codesigning, and notarization are handled by the `Makefile` and accompanying scripts — using `cargo` alone won't produce an installable macOS app.

### CI/CD

The project includes a GitHub Actions workflow (`.github/workflows/main.yml`) that automates:

1. **Tagging & Release** — Determines the next version using conventional commits (cocogitto) and creates a GitHub release
2. **Build** — Builds a universal binary (x86_64 + arm64) and creates a DMG
3. **Sign & Notarize** — Code signs and notarizes the app with Apple (when credentials are configured)
4. **Attach to Release** — Uploads build artifacts to the GitHub release

Dependency updates are managed by Dependabot with daily Cargo checks and weekly GitHub Actions checks.

## Troubleshooting

### Common Issues

1. **API Connection Failed**: Check your Uptime Kuma URL and ensure it's accessible
2. **Authentication Failed**: Verify your API key is correct and has proper permissions
3. **No Status Updates**: Check the console output for error messages

### Debug Mode

Run with debug output to see detailed information:
```bash
RUST_LOG=debug cargo run
```

### Console Output

The application prints status updates to the console. You can view these in Console.app or by running from Terminal.

## API Response Format

The application uses the Uptime Kuma metrics endpoint which returns Prometheus-formatted metrics:

```
# HELP uptime_kuma_monitor_status Current status of monitors
# TYPE uptime_kuma_monitor_status gauge
uptime_kuma_monitor_status{monitor="monitor_name"} 1
uptime_kuma_monitor_status{monitor="another_monitor"} 0
```

Where:
- `1` = Monitor is UP
- `0` = Monitor is DOWN
- Other values = Pending, Maintenance, or other statuses

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests if applicable
5. Submit a pull request

This project uses [conventional commits](https://www.conventionalcommits.org/). Please follow existing code style and run `make fmt` and `make check` before opening a PR.

## License

This project is licensed under the [MIT License](./LICENSE).

## Support

For issues and questions:

1. Check the troubleshooting section
2. Review the console output for error messages
3. Open an issue on GitHub with detailed information about your setup
