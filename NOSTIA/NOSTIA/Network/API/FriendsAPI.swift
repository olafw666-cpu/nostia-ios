import Foundation

final class FriendsAPI {
    static let shared = FriendsAPI()
    private let client = APIClient.shared
    private init() {}

    func getAll() async throws -> [Friend] {
        return try await client.request("/friends")
    }

    func getRequests() async throws -> FriendRequestsResponse {
        return try await client.request("/friends/requests")
    }

    func searchUsers(_ query: String) async throws -> [UserSearchResult] {
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        return try await client.request("/users/search?query=\(encoded)")
    }

    func sendRequest(to userId: Int) async throws {
        try await client.requestVoid("/friends/request", method: "POST", body: ["friendId": userId])
    }

    func acceptRequest(_ requestId: Int) async throws {
        try await client.requestVoid("/friends/accept/\(requestId)", method: "POST")
    }

    func rejectRequest(_ requestId: Int) async throws {
        try await client.requestVoid("/friends/reject/\(requestId)", method: "DELETE")
    }

    func removeFriend(_ friendId: Int) async throws {
        try await client.requestVoid("/friends/\(friendId)", method: "DELETE")
    }

    func getLocations() async throws -> [FriendLocation] {
        return try await client.request("/friends/locations")
    }
}
