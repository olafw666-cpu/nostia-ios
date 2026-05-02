import Foundation

final class FriendsAPI {
    static let shared = FriendsAPI()
    private let client = APIClient.shared
    private init() {}

    func getFollowers() async throws -> [FollowUser] {
        return try await client.request("/followers")
    }

    func getFollowing() async throws -> [FollowUser] {
        return try await client.request("/following")
    }

    func follow(userId: Int) async throws {
        try await client.requestVoid("/follow", method: "POST", body: ["userId": userId])
    }

    func unfollow(userId: Int) async throws {
        try await client.requestVoid("/follow/\(userId)", method: "DELETE")
    }

    func getFollowStatus(userId: Int) async throws -> FollowStatus {
        return try await client.request("/follow/status/\(userId)")
    }

    func searchUsers(_ query: String) async throws -> [UserSearchResult] {
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        return try await client.request("/users/search?query=\(encoded)")
    }

    func getLocations() async throws -> [FollowLocation] {
        return try await client.request("/follow/locations")
    }
}
