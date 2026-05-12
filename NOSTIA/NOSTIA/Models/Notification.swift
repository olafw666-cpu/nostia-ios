import Foundation

struct NostiaNotification: Identifiable, Decodable {
    let id: Int
    let type: String
    let title: String
    let body: String
    let data: NotificationData?
    var read: Bool
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id, type, title, body, data, read, createdAt
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(Int.self, forKey: .id)
        type = try c.decode(String.self, forKey: .type)
        title = try c.decode(String.self, forKey: .title)
        body = try c.decode(String.self, forKey: .body)
        data = try? c.decode(NotificationData.self, forKey: .data)
        createdAt = try c.decode(String.self, forKey: .createdAt)
        if let b = try? c.decode(Bool.self, forKey: .read) {
            read = b
        } else if let i = try? c.decode(Int.self, forKey: .read) {
            read = i != 0
        } else {
            read = false
        }
    }

    var iconName: String {
        switch type {
        case "trip_invite":     return "airplane"
        case "friend_request":  return "person.badge.plus"
        case "payment_received": return "creditcard"
        case "message":         return "bubble.left"
        default:                return "bell"
        }
    }

    var iconColorHex: String {
        switch type {
        case "trip_invite":     return "3B82F6"
        case "friend_request":  return "10B981"
        case "payment_received": return "F59E0B"
        case "message":         return "8B5CF6"
        default:                return "6B7280"
        }
    }

    var timeAgo: String {
        let fmt = ISO8601DateFormatter()
        guard let date = fmt.date(from: createdAt) else { return "" }
        let diff = Date().timeIntervalSince(date)
        let mins = Int(diff / 60)
        if mins < 1 { return "just now" }
        if mins < 60 { return "\(mins)m ago" }
        let hrs = mins / 60
        if hrs < 24 { return "\(hrs)h ago" }
        let days = hrs / 24
        if days < 7 { return "\(days)d ago" }
        let out = DateFormatter(); out.dateFormat = "MMM d"
        return out.string(from: date)
    }
}

struct NotificationData: Codable {
    var conversationId: Int?
    var tripId: Int?
    var requestId: Int?
}

struct NotificationsResponse: Codable {
    let notifications: [NostiaNotification]?
}

struct UnreadCountResponse: Codable {
    let unreadCount: Int
}
