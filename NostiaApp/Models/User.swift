import Foundation

struct User: Codable, Identifiable {
    let id: Int
    let username: String
    let name: String
    var email: String?
    var homeStatus: String?  // "open" | "closed"
    var latitude: Double?
    var longitude: Double?
    var role: String?        // "user" | "admin"
    var createdAt: String?

    var isAdmin: Bool { role == "admin" }
    var isHomeOpen: Bool { homeStatus == "open" }
    var initial: String { String(name.prefix(1)).uppercased() }
}

struct AuthResponse: Codable {
    let token: String
    let user: User
}
