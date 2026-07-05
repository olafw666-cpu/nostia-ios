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
    // Public dev flag: account_type is stripped from public profiles, but the server
    // sends isDev everywhere so dev usernames can render golden to everyone.
    private var devFlag: Bool?
    private var hasCreatedExperienceRaw: Int?
    // D6/Q-C: who can see this user's Visited tab — "public" | "followers" | "private".
    // Exposed on profile reads for the owner; defaults to "followers" when absent.
    var visitedVisibility: String?

    var isAdmin: Bool { role == "admin" }
    var isDev: Bool { accountType == "dev" || devFlag == true }
    var isHomeOpen: Bool { homeStatus == "open" }
    var initial: String { String(name.prefix(1)).uppercased() }
    var dataNotSold: Bool { dataNotSoldRaw.map { $0 != 0 } ?? false }
    var hasHomeAddress: Bool { !(addressLine1 ?? "").isEmpty }
    // True once the user has ever created an experience — suppresses the map empty-state popup.
    var hasCreatedExperience: Bool { (hasCreatedExperienceRaw ?? 0) != 0 }
    // Default applied when the server hasn't sent a value yet (Q-C default: Followers).
    var visitedTabVisibility: String { visitedVisibility ?? "followers" }

    enum CodingKeys: String, CodingKey {
        case id, username, name, email, homeStatus, latitude, longitude, role, createdAt, bio
        case profilePictureUrl = "profile_picture_url"
        case followersCount, isBlockedByMe
        case devFlag = "isDev"
        case accountType = "account_type"
        case dataNotSoldRaw = "data_not_sold"
        case addressLine1 = "address_line1"
        case addressCity = "address_city"
        case addressState = "address_state"
        case addressZip = "address_zip"
        case hasCreatedExperienceRaw = "has_created_experience"
        case visitedVisibility = "visited_visibility"
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
