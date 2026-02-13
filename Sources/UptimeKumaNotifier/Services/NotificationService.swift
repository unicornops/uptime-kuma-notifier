import AppKit
import Foundation
import UserNotifications

@MainActor
enum NotificationService {
    /// Cached URL for the app icon written to a temporary file for notification attachments.
    private static var appIconURL: URL?
    private static var appIconResolved = false

    /// Must be called from the main actor to resolve the app icon for notifications.
    static func resolveAppIcon() {
        guard !appIconResolved else { return }
        appIconResolved = true
        guard let appIcon = NSApplication.shared.applicationIconImage else { return }
        guard let tiffData = appIcon.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let pngData = bitmap.representation(using: .png, properties: [:]) else { return }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("app-icon-notification.png")
        do {
            try pngData.write(to: url, options: .atomic)
            appIconURL = url
        } catch {
            // Icon attachment will be skipped
        }
    }

    static func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error {
                print("Notification permission error: \(error.localizedDescription)")
            }
            if !granted {
                print("Notification permission not granted")
            }
        }
    }

    static func sendStatusChange(
        monitorName: String,
        serverName: String,
        oldStatus: MonitorStatus,
        newStatus: MonitorStatus
    ) {
        let content = UNMutableNotificationContent()

        switch newStatus {
        case .down:
            content.title = "Monitor Down"
            content.body = "\(monitorName) on \(serverName) is down"
            content.sound = .defaultCritical
        case .up:
            content.title = "Monitor Recovered"
            content.body = "\(monitorName) on \(serverName) is back up"
            content.sound = .default
        case .pending:
            content.title = "Monitor Pending"
            content.body = "\(monitorName) on \(serverName) is pending"
            content.sound = .default
        case .maintenance:
            content.title = "Monitor Maintenance"
            content.body = "\(monitorName) on \(serverName) is in maintenance"
            content.sound = .default
        }

        content.categoryIdentifier = "STATUS_CHANGE"
        content.threadIdentifier = serverName

        // Attach app icon for LSUIElement (menu bar only) apps
        if let iconURL = appIconURL,
           let attachment = try? UNNotificationAttachment(identifier: "app-icon", url: iconURL, options: nil) {
            content.attachments = [attachment]
        }

        let identifier = "status-\(serverName)-\(monitorName)-\(UUID().uuidString.prefix(8))"
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: nil)

        UNUserNotificationCenter.current().add(request) { error in
            if let error {
                print("Failed to deliver notification: \(error.localizedDescription)")
            }
        }
    }
}
