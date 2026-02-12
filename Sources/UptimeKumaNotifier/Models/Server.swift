import Foundation

struct Server: Identifiable, Codable, Sendable, Hashable {
    let id: UUID
    var name: String
    var url: String
    var username: String

    init(id: UUID = UUID(), name: String, url: String, username: String) {
        self.id = id
        self.name = name
        self.url = url
        self.username = username
    }
}
