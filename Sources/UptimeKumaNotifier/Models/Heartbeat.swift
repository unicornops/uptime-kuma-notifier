import Foundation

struct Heartbeat: Sendable {
    let monitorID: Int
    let status: MonitorStatus
    let message: String
    let time: Date
    let ping: Int?
    let duration: Int?

    private static func parseDate(_ string: String) -> Date {
        let primary = ISO8601DateFormatter()
        primary.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = primary.date(from: string) { return date }

        let fallback = ISO8601DateFormatter()
        fallback.formatOptions = [.withInternetDateTime]
        return fallback.date(from: string) ?? Date()
    }

    static func from(dictionary dict: [String: Any]) -> Heartbeat? {
        guard let monitorID = dict["monitorID"] as? Int,
              let statusRaw = dict["status"] as? Int,
              let status = MonitorStatus(rawValue: statusRaw) else {
            return nil
        }

        let message = dict["msg"] as? String ?? ""
        let ping = dict["ping"] as? Int
        let duration = dict["duration"] as? Int

        var time = Date()
        if let timeString = dict["time"] as? String {
            time = parseDate(timeString)
        }

        return Heartbeat(
            monitorID: monitorID,
            status: status,
            message: message,
            time: time,
            ping: ping,
            duration: duration
        )
    }
}
