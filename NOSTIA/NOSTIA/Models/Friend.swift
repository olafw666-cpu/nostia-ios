import Foundation

struct Friend: Codable, Identifiable {
    let id: Int
    let username: String
    let name: String
    var homeStatus: String?
    var latitude: Double?
    var longitude: Double?

    var isHomeOpen: Bool { homeStatus == "open" }
    var initial: String { String(name.prefix(1)).uppercased() }
}

struct FriendRequest: Codable, Identifiable {
    let id: Int
    let username: String
    let name: String
    var friendId: Int?
    var createdAt: String?
}

struct FriendRequestsResponse: Codable {
    let received: [FriendRequest]
    let sent: [FriendRequest]
}

struct FriendLocation: Codable, Identifiable {
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
