import Foundation

final class ProfileAPI {
    static let shared = ProfileAPI()
    private let client = APIClient.shared
    private init() {}

    func updateProfile(bio: String, profilePictureData: String?) async throws -> User {
        var body: [String: Any] = ["bio": bio]
        if let data = profilePictureData { body["profile_picture_url"] = data }
        return try await client.request("/users/me", method: "PUT", body: body)
    }

    func getPublicProfile(userId: Int) async throws -> User {
        return try await client.request("/users/\(userId)")
    }

    /// D6: persist who can see the caller's Visited tab.
    /// `visibility` ∈ "public" | "followers" | "private". Returns the updated User.
    @discardableResult
    func setVisitedVisibility(_ visibility: String) async throws -> User {
        return try await client.request("/profile", method: "PATCH", body: ["visitedVisibility": visibility])
    }
}
