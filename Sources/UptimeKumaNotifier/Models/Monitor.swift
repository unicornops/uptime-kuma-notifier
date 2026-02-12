import Foundation

struct Monitor: Identifiable, Sendable {
    let id: Int
    var name: String
    var url: String?
    var type: String
    var status: MonitorStatus
    var active: Bool
    var latestHeartbeat: Heartbeat?

    static func from(dictionary dict: [String: Any]) -> Monitor? {
        guard let id = dict["id"] as? Int,
              let name = dict["name"] as? String,
              let type = dict["type"] as? String else {
            return nil
        }

        let active = dict["active"] as? Bool ?? true
        let url = dict["url"] as? String

        // Status may come from an embedded heartbeat or not be present yet
        let statusRaw = dict["status"] as? Int
        let status = statusRaw.flatMap { MonitorStatus(rawValue: $0) } ?? .pending

        return Monitor(
            id: id,
            name: name,
            url: url,
            type: type,
            status: status,
            active: active,
            latestHeartbeat: nil
        )
    }
}
