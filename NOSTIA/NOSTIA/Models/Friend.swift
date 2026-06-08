import Foundation

struct FollowUser: Codable, Identifiable {
    let id: Int
    let username: String
    let name: String
    var homeStatus: String?

    var isHomeOpen: Bool { homeStatus == "open" }
    var initial: String { String(name.prefix(1)).uppercased() }
}

struct FollowStatus: Codable {
    var isFollowing: Bool
    var isFollowedBy: Bool
    var isMutual: Bool
}

struct FollowLocation: Codable, Identifiable {
    let id: Int
    let name: String
    let username: String
    let latitude: Double
    let longitude: Double
}

struct UserSearchResult: Codable, Identifiable {
    let id: Int
    let username: String
    let name: String
}

struct ContactMatch: Identifiable {
    let id = UUID()
    let name: String
    let email: String
    let phone: String?
    let nostiaUser: UserSearchResult
}

struct InviteContact: Identifiable {
    let id = UUID()
    let name: String
    let phone: String?
    let email: String?
}
