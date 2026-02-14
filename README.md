# Uptime Kuma Notifier

A native macOS menu bar application that connects to your Uptime Kuma
instance and provides real-time notifications for monitor status changes.

## Features

- **Real-time Monitoring**: Connects to your Uptime Kuma server via
  WebSocket for instant status updates
- **Menu Bar Integration**: Displays monitor status directly in your
  macOS menu bar
- **Notifications**: Receive native macOS notifications when monitor
  status changes
- **Multiple Servers**: Support for connecting to multiple Uptime Kuma
  instances
- **Secure Storage**: Server credentials stored securely in macOS Keychain

## Installation

### Prerequisites

- macOS 15.0 or later
- Swift 6.0 or later
- Xcode 16.0 or later (for building from source)

### Building from Source

1. Clone this repository:

   ```bash
   git clone https://github.com/unicornops/uptime-kuma-notifier.git
   cd uptime-kuma-notifier
   ```

2. Build the project:

   ```bash
   swift build -c release
   ```

3. The built application will be available in `.build/release/`

## Usage

1. Launch the application
2. Click on the menu bar icon
3. Add your Uptime Kuma server details
4. The application will connect and display your monitor status

## Configuration

The application stores configuration in:

- `~/Library/Application Support/com.unicornops.UptimeKumaNotifier/` -
  Application data
- macOS Keychain - Secure credential storage

## Development

### Project Structure

- `Sources/` - Main application source code
- `Tests/` - Unit tests
- `Package.swift` - Swift Package Manager manifest

### Running Tests

```bash
swift test
```

### Code Style

This project follows standard Swift conventions. See
[CLAUDE.md](CLAUDE.md) for additional project-specific conventions.

## Contributing

Contributions are welcome! Please see [CLAUDE.md](CLAUDE.md) for
contribution guidelines.

## License

This project is licensed under the MIT License - see the
[LICENSE](LICENSE) file for details.

## Support

For issues, questions, or feature requests, please open an issue on
GitHub.

## Screenshots

![Menu Bar View](.github/images/menu-bar.png)
![Monitor List](.github/images/monitor-list.png)
![Settings](.github/images/settings.png)

## Related Projects

- [Uptime Kuma](https://github.com/louislam/uptime-kuma) - The
  monitoring tool this application connects to
- [Socket.IO](https://socket.io/) - Real-time communication library used
  for WebSocket connections

## Acknowledgements

- [Uptime Kuma](https://github.com/louislam/uptime-kuma) for the
  excellent monitoring solution
- [SwiftUI](https://developer.apple.com/xcode/swiftui/) for the modern UI
  framework
- [Socket.IO Client](https://github.com/socketio/socket.io-client-swift)
  for WebSocket communication
