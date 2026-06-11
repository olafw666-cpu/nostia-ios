import Foundation

struct BlockedUser: Codable, Identifiable {
    let id: Int
    let username: String
    let name: String
    let blockedAt: String?
}

enum ReportReason: String, CaseIterable, Identifiable {
    case spam
    case harassment
    case inappropriate
    case other

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .spam: return "Spam"
        case .harassment: return "Harassment or bullying"
        case .inappropriate: return "Inappropriate content"
        case .other: return "Other"
        }
    }

    var icon: String {
        switch self {
        case .spam: return "envelope.badge"
        case .harassment: return "person.crop.circle.badge.exclamationmark"
        case .inappropriate: return "eye.slash"
        case .other: return "ellipsis.circle"
        }
    }
}

// Drives .sheet(item:) presentation of ReportSheet
struct ReportTarget: Identifiable {
    let contentType: String   // "post" | "comment" | "user" | "message"
    let contentId: Int
    var id: String { "\(contentType)-\(contentId)" }
}
