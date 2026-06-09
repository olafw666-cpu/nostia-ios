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

    func lookupContacts(emails: [String]) async throws -> [String: UserSearchResult] {
        return try await client.request("/contacts/lookup", method: "POST", body: ["emails": emails])
    }

    func createContactInvite(email: String?, phone: String?) async throws -> ContactInviteRecord {
        var body: [String: Any] = [:]
        if let email { body["email"] = email }
        if let phone { body["phone"] = phone }
        return try await client.request("/contacts/invite", method: "POST", body: body)
    }

    func getContactInvites() async throws -> [ContactInviteRecord] {
        return try await client.request("/contacts/invites")
    }

    func getLocations() async throws -> [FollowLocation] {
        return try await client.request("/follow/locations")
    }
}
