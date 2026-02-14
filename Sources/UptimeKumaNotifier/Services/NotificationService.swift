import AppKit
import Foundation
import UserNotifications

enum NotificationService {
    /// Resolve the app icon PNG URL for notification attachments.
    /// Looks for AppIcon.icns in the app bundle Resources (placed there by CI build scripts),
    /// converts to PNG since UNNotificationAttachment requires a supported image format.
    private nonisolated(unsafe) static var appIconURL: URL? = {
        guard let icnsURL = Bundle.main.url(forResource: "AppIcon", withExtension: "icns"),
              let image = NSImage(contentsOf: icnsURL),
              let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let pngData = bitmap.representation(using: .png, properties: [:]) else {
            return nil
        }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("app-icon-notification.png")
        do {
            try pngData.write(to: url, options: .atomic)
            return url
        } catch {
            return nil
        }
    }()

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
