# Uptime Kuma Notify

A macOS menu bar application that displays the number of services that are up and down in your Uptime Kuma instance.

## Features

- Shows real-time status of your Uptime Kuma monitors in the macOS menu bar
- Displays format: "Up:X / Down:Y"
- Automatically updates every 30 seconds
- Lightweight and runs in the background
- Configurable via TOML file
- Uses the reliable Uptime Kuma metrics endpoint

## Prerequisites

- macOS (tested on macOS 14+)
- Rust toolchain (cargo, rustc)
- Uptime Kuma instance running and accessible

## Installation

1. Clone this repository:
```bash
git clone <repository-url>
cd uptime-kuma-notify
```

2. Configure the application (see Configuration section below)

3. Build the application:
```bash
cargo build --release
```

4. Run the application:
```bash
cargo run --release
```

## Configuration

The app supports a simple way to configure preferences:

### Integrated Preferences Editor

#### **🖱️ Menu Bar Access**
1. **Right-click** the menu bar icon
2. **Select "Preferences..."** from the menu
3. **Browser window opens** with a beautiful preferences interface

### Getting Your API Key

1. In your Uptime Kuma instance, go to Settings → API Keys
2. Create a new API key with appropriate permissions
3. Copy the API key and update your configuration

### API Endpoint

The application uses the **Metrics Endpoint** (`/metrics`):

- **Endpoint**: `/metrics`
- **Authentication**: HTTP Basic Auth with API key as password (recommended method)
- **Response Format**: Prometheus metrics format
- **Advantages**:
  - More reliable than other endpoints
  - Provides real-time monitor status
  - Standard Prometheus format
  - Includes all monitor information

**Note**: The metrics endpoint requires HTTP Basic Authentication where:
- Username: (empty string)
- Password: Your API key

## Usage

1. **Start the application**:
```bash
cargo run
```

2. **You'll see a new icon in your macOS menu bar** showing your Uptime Kuma status
3. **The icon displays**: "✅ X 🔴 Y" (X = up monitors, Y = down monitors)
4. **Status updates automatically** based on your refresh interval

### 🖱️ Menu Bar Interface

**Right-click the menu bar icon** for these options:

- **Preferences...**: Opens a beautiful web-based preferences editor in your browser
- **Quit**: Closes the application

### 🎯 User-Friendly Features

- **Visual Preferences**: Clean, modern web interface - no need to edit config files
- **Multiple Access Methods**: Menu bar clicks or console shortcuts
- **Professional Interface**: Native macOS menu bar integration
- **Real-time Updates**: Status displays current monitor counts automatically

## Development

### Project Structure

- `src/main.rs` - Main application code
- `Cargo.toml` - Dependencies and project configuration
- `config.example.toml` - Example configuration file

### Dependencies

- `cacao` - macOS app framework
- `objc2` - Objective-C runtime bindings
- `reqwest` - HTTP client for API requests
- `serde` - JSON serialization/deserialization
- `tokio` - Async runtime

### Building

```bash
# Debug build
cargo build

# Release build
cargo build --release

# Run tests
cargo test

# Check for issues
cargo check
```

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

The application now uses the Uptime Kuma metrics endpoint which returns Prometheus-formatted metrics:

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

## License

[Add your license here]

## Support

For issues and questions:
1. Check the troubleshooting section
2. Review the console output for error messages
3. Open an issue on GitHub with detailed information about your setup
