# Uptime Kuma Notifier Preferences System

This document describes the new preferences system that replaces the static configuration file.

## Overview

The preferences system allows users to configure the Uptime Kuma Notifier application through a graphical interface instead of editing configuration files manually. Preferences are stored securely in the standard macOS location for application preferences.

## Features

- **Graphical Preferences Window**: Accessible via right-click on the menu bar item
- **Secure Storage**: Preferences are stored in the standard macOS location (`~/Library/Application Support/uptime-kuma-notifier/`)
- **Multiple Format Support**: Preferences are saved in both JSON and PLIST formats for compatibility
- **Real-time Updates**: Configuration changes take effect immediately
- **Persistent Storage**: Preferences persist between application launches

## Accessing Preferences

1. **Right-click** on the Uptime Kuma Notifier menu bar item
2. Select **"Preferences..."** from the dropdown menu
3. The preferences window will open with all current settings

## Configuration Options

### API URL
- **Description**: The base URL of your Uptime Kuma instance
- **Example**: `https://uptime.example.com`
- **Default**: `https://uptime.example.com`

### API Key
- **Description**: Your Uptime Kuma API key for authentication
- **Format**: Usually starts with `uk2_` followed by a long string
- **Default**: `uk2_xxxxxxxx`

### Refresh Interval
- **Description**: How often (in seconds) the application checks Uptime Kuma for status updates
- **Range**: 10-300 seconds recommended
- **Default**: 30 seconds

### Show Notifications
- **Description**: Whether to display system notifications for status changes
- **Options**: Enabled/Disabled
- **Default**: Enabled

## Storage Location

Preferences are stored in the following location:
```
~/Library/Application Support/uptime-kuma-notifier/
├── preferences.json    # JSON format preferences
└── preferences.plist   # macOS PLIST format preferences
```

### Why This Location?

- **Security**: Follows macOS security guidelines for application data
- **Backup**: Automatically included in Time Machine backups
- **Standard**: Follows Apple's Human Interface Guidelines
- **Isolation**: Each application has its own isolated preferences directory

## File Formats

### JSON Format
Human-readable format that can be manually edited if needed:
```json
{
  "api_url": "https://uptime.example.com",
  "api_key": "uk2_your_api_key_here",
  "refresh_interval": 30,
  "show_notifications": true
}
```

### PLIST Format
Native macOS format used by the system:
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>api_url</key>
    <string>https://uptime.example.com</string>
    <key>api_key</key>
    <string>uk2_your_api_key_here</string>
    <key>refresh_interval</key>
    <integer>30</integer>
    <key>show_notifications</key>
    <true/>
</dict>
</plist>
```

## Testing the Preferences System

You can test the preferences system using the included test binary:

```bash
cargo run --bin test_preferences
```

This will:
1. Create default preferences
2. Save them to disk
3. Load them back
4. Verify the data integrity
5. Show the storage locations

## Migration from Static Configuration

If you were previously using a static configuration file:

1. **Backup**: Your old configuration file (if any)
2. **Launch**: The new application with preferences system
3. **Configure**: Use the preferences window to set your settings
4. **Verify**: Check that the application connects successfully
5. **Remove**: Old configuration files (optional)

## Troubleshooting

### Preferences Not Saving
- Check that the application has write permissions to `~/Library/Application Support/`
- Verify the directory exists and is writable
- Check the console for any error messages

### Preferences Not Loading
- Verify the preferences files exist in the storage location
- Check file permissions (should be readable by the application)
- Try deleting the preferences files to reset to defaults

### Configuration Not Taking Effect
- Restart the application after making changes
- Check that the preferences were saved successfully
- Verify the console output for any error messages

## Security Considerations

- **API Keys**: Stored locally on your machine, not transmitted to external servers
- **File Permissions**: Preferences files are readable only by your user account
- **Encryption**: Consider using macOS FileVault for additional security
- **Backup**: Preferences are included in Time Machine backups by default

## Future Enhancements

Planned improvements to the preferences system:
- **Validation**: Real-time validation of API URLs and keys
- **Import/Export**: Ability to backup and restore preferences
- **Profiles**: Multiple configuration profiles for different Uptime Kuma instances
- **Advanced Options**: Additional configuration options for power users

## Support

If you encounter issues with the preferences system:
1. Check the console output for error messages
2. Verify the storage location and file permissions
3. Try resetting preferences to defaults
4. Report issues with detailed error information
