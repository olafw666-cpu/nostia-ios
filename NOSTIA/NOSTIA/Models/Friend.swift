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
