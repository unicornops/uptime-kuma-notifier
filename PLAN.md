# Uptime Kuma Notifier — Swift macOS Menu Bar App

## Context
Rewrite the Uptime Kuma monitoring notifier as a native Swift macOS menu bar app (replacing the previous Rust implementation). The app connects to one or more Uptime Kuma servers via Socket.IO, displays aggregate status in the menu bar, and sends native notifications on status changes. Targeting macOS 15 (Sequoia), App Store ready with sandboxing.

## Architecture
- **SwiftUI** with `MenuBarExtra` for the menu bar UI
- **Socket.IO** (via `socket.io-client-swift` SPM package) for real-time server communication
- **macOS Keychain** (Security framework) for secure credential storage
- **UserNotifications** framework for native notifications
- **@Observable** pattern (macOS 15) for state management
- **Swift Package Manager** for dependency management

## Project Structure
```
Package.swift
Info.plist
UptimeKumaNotifier.entitlements
Sources/UptimeKumaNotifier/
  App/UptimeKumaNotifierApp.swift          # @main, MenuBarExtra + Settings scene
  Models/
    MonitorStatus.swift                     # Enum: down(0), up(1), pending(2), maintenance(3)
    ServerConnectionState.swift             # Enum: disconnected/connecting/authenticating/connected/error
    Server.swift                            # Server config (id, name, url, username) — Codable
    Monitor.swift                           # Monitor data (id, name, type, status, heartbeat)
    Heartbeat.swift                         # Heartbeat event data
  Services/
    KeychainService.swift                   # SecItem-based CRUD for passwords & JWT tokens
    SocketIOService.swift                   # Single-server Socket.IO connection & event parsing
    NotificationService.swift               # UNUserNotificationCenter wrapper
  ViewModels/
    ServerManager.swift                     # Multi-server orchestrator, @Observable, persists configs
    ServerConnectionViewModel.swift         # Per-server live state, SocketIOServiceDelegate
  Views/
    MenuBarView.swift                       # Popover content: server list, status summary, quit
    MonitorListView.swift                   # Collapsible section per server with monitors
    MonitorRowView.swift                    # Single monitor row (icon, name, message, ping)
    SettingsView.swift                      # Preferences window: server list + edit pane
    ServerFormView.swift                    # Add/edit server form with test connection
```

## Key Design Decisions

### Socket.IO Connection
- Use `socket.io-client-swift` v16.x with `.version(.three)` (Socket.IO protocol v3 = library v4, matching Uptime Kuma server)
- Auth flow: `login` event with username/password → receive JWT → store in Keychain → use `loginByToken` on reconnect
- Listen for: `monitorList` (full inventory), `heartbeat` (live status), `updateMonitorIntoList` (monitor changes)
- Status codes: 0=DOWN, 1=UP, 2=PENDING, 3=MAINTENANCE

### Credential Storage
- Server configs (URL, name, username) stored in `UserDefaults` as JSON
- Passwords and JWT tokens stored in macOS Keychain via Security framework
- Keyed by server UUID, scoped by app sandbox automatically

### Menu Bar
- Green checkmark SF Symbol when all monitors operational
- Red X with count overlay when monitors are down
- `MenuBarExtra(.window)` style for rich SwiftUI popover
- `LSUIElement = true` to hide dock icon

### Notifications
- Fire on status transitions (UP→DOWN, DOWN→UP) detected by comparing heartbeat status to stored monitor status
- Use `UNUserNotificationCenter` with unique IDs per monitor+server combo

### Sandboxing & Entitlements
- `com.apple.security.app-sandbox` — required for App Store
- `com.apple.security.network.client` — for outbound WebSocket connections
- No other entitlements needed (Keychain and notifications work within sandbox)

## Implementation Order

1. **Package.swift** — SPM config with SocketIO dependency
2. **Info.plist + Entitlements** — App metadata, LSUIElement, sandbox config
3. **Models** — All 5 model files
4. **UptimeKumaNotifierApp.swift** — Minimal MenuBarExtra skeleton
5. **KeychainService.swift** — Secure credential CRUD
6. **SocketIOService.swift** — Connection, auth, event parsing with delegate pattern
7. **NotificationService.swift** — Permission request and posting
8. **ServerConnectionViewModel.swift** — Per-server state, delegate implementation
9. **ServerManager.swift** — Multi-server orchestration, persistence
10. **Views** — MenuBarView, MonitorListView, MonitorRowView, SettingsView, ServerFormView
11. **Update .gitignore** — Add Swift/Xcode patterns

## Verification
1. `swift build` — Confirm project compiles with SocketIO dependency
2. `swift run` — App appears as menu bar icon
3. Configure a test Uptime Kuma server in Settings
4. Verify real-time monitor list populates via Socket.IO
5. Simulate a monitor going down → verify notification fires and menu bar shows count
6. Test multiple server connections simultaneously
7. Test app relaunch → verify token-based reconnection from Keychain
