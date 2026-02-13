import SwiftUI

@main
struct UptimeKumaNotifierApp: App {
    @State private var serverManager = ServerManager()

    var body: some Scene {
        MenuBarExtra {
            MenuBarView(serverManager: serverManager)
        } label: {
            HStack(spacing: 2) {
                Image(systemName: serverManager.menuBarSystemImage)
                if let label = serverManager.menuBarLabel {
                    Text(label)
                        .font(.caption)
                }
            }
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView(serverManager: serverManager)
        }
    }

    init() {
        NotificationService.requestPermission()
        NotificationService.resolveAppIcon()
    }
}
