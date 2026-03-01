# CLAUDE.md

## Project Overview

Uptime Kuma Notifier — a native macOS menu bar application
(Swift/SwiftUI) that monitors Uptime Kuma servers via Socket.IO and provides
real-time status updates with native notifications.

## Build & Run

```bash
swift build              # Debug build
swift build -c release   # Release build
swift run                # Build and run
```

## Project Structure

- `Package.swift` — SPM config, depends on `socket.io-client-swift`
- `Sources/UptimeKumaNotifier/`
  - `App/` — `@main` entry point with `MenuBarExtra`
  - `Models/` — `Server`, `Monitor`, `Heartbeat`, `MonitorStatus`,
    `ServerConnectionState`
  - `Services/` — `KeychainService`, `SocketIOService`,
    `NotificationService`
  - `ViewModels/` — `ServerManager` (multi-server orchestrator),
    `ServerConnectionViewModel` (per-server state)
  - `Views/` — `MenuBarView`, `MonitorListView`, `MonitorRowView`,
    `SettingsView`, `ServerFormView`
- `Info.plist` — `LSUIElement=true` (menu bar only app), macOS 15+
- `UptimeKumaNotifier.entitlements` — Sandbox + network.client

## Key Technical Details

- **Target**: macOS 15 (Sequoia) minimum
- **Swift version**: 6.0 (strict concurrency)
- **Dependency**: `socket.io-client-swift` v16.x with `.version(.three)`
  (matches Uptime Kuma's Socket.IO v4 server)
- **Credentials**: Passwords and JWT tokens stored in macOS Keychain via
  Security framework. Server configs (non-secret) in UserDefaults.
- **Architecture**: `@Observable` pattern, `@MainActor` for all
  UI/ViewModel code. `SocketIOService` is `@unchecked Sendable` with delegate
  callbacks dispatched to MainActor

## Conventions

- **All commits must use conventional commit format**
  (e.g., `feat:`, `fix:`, `chore:`, `ci:`, `docs:`)
- Versioning and changelog management are handled by release-please
- Follow Apple platform best practices (SwiftUI, Keychain,
  UserNotifications, app sandbox)
- No third-party dependencies beyond Socket.IO client — use system frameworks
  (Security, UserNotifications)

## CI/CD

- **PR validation**: semantic PR title check + debug/release builds
  (`pr-validation.yml`)
- **Release on merge**: release-please automation, signed + notarized app bundle,
  DMG/ZIP GitHub Release assets (`release-on-merge.yml`)
- **App Store**: manual dispatch, builds .pkg and uploads to App Store Connect
  (`appstore-release.yml`)

## GitHub Secrets Required

- `APPLE_CERTIFICATE_BASE64` / `APPLE_CERTIFICATE_PASSWORD` —
  Developer ID signing
- `APPLE_TEAM_ID` / `APPLE_DEVELOPER_ID` / `APPLE_APP_PASSWORD` —
  Notarization
- `APPSTORE_CERTIFICATE_BASE64` / `APPSTORE_INSTALLER_CERTIFICATE_BASE64` /
  `APPSTORE_CERTIFICATE_PASSWORD` / `APPSTORE_PROVISIONING_PROFILE_BASE64` —
  App Store submission
