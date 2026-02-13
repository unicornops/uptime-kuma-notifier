import Foundation

struct Server: Identifiable, Codable, Sendable, Hashable {
    let id: UUID
    var name: String
    var url: String
    var username: String
    var twoFactorToken: String?

    init(id: UUID = UUID(), name: String, url: String, username: String, twoFactorToken: String? = nil) {
        self.id = id
        self.name = name
        self.url = url
        self.username = username
        self.twoFactorToken = twoFactorToken
    }
}
