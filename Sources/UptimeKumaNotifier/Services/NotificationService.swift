import Foundation
import UserNotifications

enum NotificationService {
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

        let identifier = "status-\(serverName)-\(monitorName)-\(UUID().uuidString.prefix(8))"
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: nil)

        UNUserNotificationCenter.current().add(request) { error in
            if let error {
                print("Failed to deliver notification: \(error.localizedDescription)")
            }
        }
    }
}
