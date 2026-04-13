import Foundation

final class MessagesAPI {
    static let shared = MessagesAPI()
    private let client = APIClient.shared
    private init() {}

    func getConversations() async throws -> [Conversation] {
        return try await client.request("/conversations")
    }

    func getOrCreateConversation(withUserId userId: Int) async throws -> ConversationResponse {
        return try await client.request("/conversations", method: "POST", body: ["userId": userId])
    }

    func getMessages(conversationId: Int, limit: Int = 100, offset: Int = 0) async throws -> [Message] {
        let path = "/conversations/\(conversationId)/messages?limit=\(limit)&offset=\(offset)"
        // Server may return array or { messages: [] }
        if let arr: [Message] = try? await client.request(path) {
            return arr
        }
        let res: MessagesResponse = try await client.request(path)
        return res.messages ?? []
    }

    func sendMessage(conversationId: Int, content: String) async throws -> Message {
        return try await client.request(
            "/conversations/\(conversationId)/messages",
            method: "POST",
            body: ["content": content]
        )
    }

    func markAsRead(conversationId: Int) async throws {
        try await client.requestVoid("/conversations/\(conversationId)/read", method: "PUT")
    }

    func getUnreadCount() async throws -> Int {
        struct Res: Decodable { let unreadCount: Int }
        let res: Res = try await client.request("/messages/unread-count")
        return res.unreadCount
    }
}
