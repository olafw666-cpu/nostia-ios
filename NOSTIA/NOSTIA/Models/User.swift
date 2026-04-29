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
    var bio: String?
    var profilePictureUrl: String?
    var friendsCount: Int?

    var isAdmin: Bool { role == "admin" }
    var isHomeOpen: Bool { homeStatus == "open" }
    var initial: String { String(name.prefix(1)).uppercased() }

    enum CodingKeys: String, CodingKey {
        case id, username, name, email, homeStatus, latitude, longitude, role, createdAt, bio
        case profilePictureUrl = "profile_picture_url"
        case friendsCount
    }
}

struct AuthResponse: Codable {
    let token: String
    let user: User
}
