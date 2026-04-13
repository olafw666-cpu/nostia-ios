import Foundation

final class FeedAPI {
    static let shared = FeedAPI()
    private let client = APIClient.shared
    private init() {}

    func getUserFeed(limit: Int = 50) async throws -> [FeedPost] {
        try await client.request("/feed?limit=\(limit)")
    }

    func createPost(content: String?, imageData: String?, relatedTripId: Int? = nil) async throws -> FeedPost {
        var body: [String: Any] = [:]
        if let c = content { body["content"] = c }
        if let img = imageData { body["imageData"] = img }
        if let t = relatedTripId { body["relatedTripId"] = t }
        return try await client.request("/feed", method: "POST", body: body)
    }

    func deletePost(id: Int) async throws {
        try await client.requestVoid("/feed/\(id)", method: "DELETE")
    }

    func likePost(id: Int) async throws {
        try await client.requestVoid("/feed/\(id)/like", method: "POST")
    }

    func unlikePost(id: Int) async throws {
        try await client.requestVoid("/feed/\(id)/like", method: "DELETE")
    }

    func getComments(postId: Int) async throws -> [FeedComment] {
        try await client.request("/feed/\(postId)/comments")
    }

    func addComment(postId: Int, content: String) async throws -> FeedComment {
        try await client.request("/feed/\(postId)/comments", method: "POST", body: ["content": content])
    }

    func deleteComment(id: Int) async throws {
        try await client.requestVoid("/feed/comments/\(id)", method: "DELETE")
    }
}
