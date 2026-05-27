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
    var accountType: String? // "user" | "dev"
    var createdAt: String?
    var bio: String?
    var profilePictureUrl: String?
    var followersCount: Int?
    private var dataNotSoldRaw: Int?

    var isAdmin: Bool { role == "admin" }
    var isDev: Bool { accountType == "dev" }
    var isHomeOpen: Bool { homeStatus == "open" }
    var initial: String { String(name.prefix(1)).uppercased() }
    var dataNotSold: Bool { dataNotSoldRaw.map { $0 != 0 } ?? false }

    enum CodingKeys: String, CodingKey {
        case id, username, name, email, homeStatus, latitude, longitude, role, createdAt, bio
        case profilePictureUrl = "profile_picture_url"
        case followersCount
        case accountType = "account_type"
        case dataNotSoldRaw = "data_not_sold"
    }
}

struct AuthResponse: Codable {
    let token: String
    let refreshToken: String?
    let user: User
}

struct TokenRefreshResponse: Codable {
    let token: String
    let refreshToken: String
}
