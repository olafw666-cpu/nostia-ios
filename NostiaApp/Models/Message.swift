import Foundation

struct Conversation: Codable, Identifiable {
    let id: Int
    var otherUserId: Int?
    var otherUserName: String?
    var otherUserUsername: String?
    var lastMessage: String?
    var unreadCount: Int?
    var updatedAt: String?
}

struct Message: Codable, Identifiable {
    let id: Int
    let conversationId: Int
    let senderId: Int
    let senderName: String
    let senderUsername: String?
    let content: String
    var read: Bool
    let createdAt: String

    var timeFormatted: String {
        let fmt = ISO8601DateFormatter()
        guard let date = fmt.date(from: createdAt) else { return "" }
        let diff = Date().timeIntervalSince(date)
        if diff < 86400 {
            let out = DateFormatter(); out.dateFormat = "h:mm a"
            return out.string(from: date)
        } else if diff < 86400 * 7 {
            let out = DateFormatter(); out.dateFormat = "EEE"
            return out.string(from: date)
        }
        let out = DateFormatter(); out.dateFormat = "MMM d"
        return out.string(from: date)
    }

    var dayString: String {
        let fmt = ISO8601DateFormatter()
        guard let date = fmt.date(from: createdAt) else { return "" }
        let out = DateFormatter(); out.dateFormat = "EEEE, MMM d"
        return out.string(from: date)
    }
}

struct MessagesResponse: Codable {
    let messages: [Message]?
}

struct ConversationResponse: Codable {
    let id: Int
    var otherUserId: Int?
    var otherUserName: String?
    var otherUserUsername: String?
}
