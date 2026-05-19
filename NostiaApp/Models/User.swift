import Foundation

struct User: Codable, Identifiable {
    let id: Int
    let username: String
    let name: String
    var email: String?
    var homeStatus: String?
    var latitude: Double?
    var longitude: Double?
    var role: String?
    var accountType: String?
    var createdAt: String?
    var bio: String?
    var profilePictureUrl: String?

    enum CodingKeys: String, CodingKey {
        case id, username, name, email, homeStatus, latitude, longitude
        case role, createdAt, bio
        case profilePictureUrl = "profile_picture_url"
        case accountType = "account_type"
    }

    var isAdmin: Bool { role == "admin" }
    var isDev: Bool { accountType == "dev" }
    var isHomeOpen: Bool { homeStatus == "open" }
    var initial: String { String(name.prefix(1)).uppercased() }
}

struct AuthResponse: Codable {
    let token: String
    let user: User
}
