import AppKit
import Foundation
import UserNotifications

@MainActor
enum NotificationService {
    /// URL for the app icon used in notification attachments.
    /// Locates AppIcon.icns from the app bundle Resources, converts to PNG for UNNotificationAttachment.
    private static let appIconURL: URL? = {
        // Find the .icns in the app bundle (placed there by CI build scripts)
        guard let icnsURL = Bundle.main.url(forResource: "AppIcon", withExtension: "icns"),
              let imageSource = CGImageSourceCreateWithURL(icnsURL as CFURL, nil),
              CGImageSourceGetCount(imageSource) > 0,
              let cgImage = CGImageSourceCreateImageAtIndex(imageSource, 0, nil) else {
            return nil
        }
        let bitmapRep = NSBitmapImageRep(cgImage: cgImage)
        guard let pngData = bitmapRep.representation(using: .png, properties: [:]) else { return nil }
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
