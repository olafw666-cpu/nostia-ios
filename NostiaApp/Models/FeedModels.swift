import Foundation

struct FeedPost: Codable, Identifiable {
    let id: Int
    let userId: Int
    let username: String
    let name: String
    let content: String?
    let imageData: String?
    let relatedTripId: Int?
    let relatedEventId: Int?
    let tripTitle: String?
    let eventTitle: String?
    let likeCount: Int
    let commentCount: Int
    let isLiked: Bool?
    let createdAt: String

    var timeAgo: String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        var date = formatter.date(from: createdAt)
        if date == nil {
            let f2 = DateFormatter(); f2.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
            date = f2.date(from: createdAt)
        }
        if date == nil {
            let f3 = DateFormatter(); f3.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
            date = f3.date(from: createdAt)
        }
        guard let d = date else { return "" }
        let diff = Int(Date().timeIntervalSince(d))
        if diff < 60 { return "now" }
        if diff < 3600 { return "\(diff/60)m" }
        if diff < 86400 { return "\(diff/3600)h" }
        return "\(diff/86400)d"
    }
}

struct FeedComment: Codable, Identifiable {
    let id: Int
    let userId: Int
    let username: String
    let name: String
    let content: String
    let createdAt: String

    var timeAgo: String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        var date = formatter.date(from: createdAt)
        if date == nil {
            let f2 = DateFormatter(); f2.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
            date = f2.date(from: createdAt)
        }
        guard let d = date else { return "" }
        let diff = Int(Date().timeIntervalSince(d))
        if diff < 60 { return "now" }
        if diff < 3600 { return "\(diff/60)m" }
        if diff < 86400 { return "\(diff/3600)h" }
        return "\(diff/86400)d"
    }
}

struct CreatePostResponse: Codable {
    let id: Int
    let content: String?
    let createdAt: String
}

struct LikeResponse: Codable {
    let likeCount: Int
}
