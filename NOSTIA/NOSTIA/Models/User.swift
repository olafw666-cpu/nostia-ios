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
    var addressLine1: String?
    var addressCity: String?
    var addressState: String?
    var addressZip: String?
    var isBlockedByMe: Bool?  // only present on GET /users/:id (public profile)
    private var hasCreatedExperienceRaw: Int?

    var isAdmin: Bool { role == "admin" }
    var isDev: Bool { accountType == "dev" }
    var isHomeOpen: Bool { homeStatus == "open" }
    var initial: String { String(name.prefix(1)).uppercased() }
    var dataNotSold: Bool { dataNotSoldRaw.map { $0 != 0 } ?? false }
    var hasHomeAddress: Bool { !(addressLine1 ?? "").isEmpty }
    // True once the user has ever created an experience — suppresses the map empty-state popup.
    var hasCreatedExperience: Bool { (hasCreatedExperienceRaw ?? 0) != 0 }

    enum CodingKeys: String, CodingKey {
        case id, username, name, email, homeStatus, latitude, longitude, role, createdAt, bio
        case profilePictureUrl = "profile_picture_url"
        case followersCount, isBlockedByMe
        case accountType = "account_type"
        case dataNotSoldRaw = "data_not_sold"
        case addressLine1 = "address_line1"
        case addressCity = "address_city"
        case addressState = "address_state"
        case addressZip = "address_zip"
        case hasCreatedExperienceRaw = "has_created_experience"
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
