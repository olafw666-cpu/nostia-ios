import Foundation

struct AnalyticsDashboard: Codable {
    let totalUsers: Int?
    let activeUsers: Int?
    let totalTrips: Int?
    let totalPosts: Int?
    let totalFriendships: Int?
    let newUsersToday: Int?
    let newUsersThisWeek: Int?
}

struct FunnelStep: Codable, Identifiable {
    var id: String { step }
    let step: String
    let count: Int
    let percentage: Double?
}

struct RetentionRow: Codable, Identifiable {
    var id: String { period }
    let period: String
    let retained: Int?
    let total: Int?
    let rate: Double?
}

struct AnalyticsDashboardResponse: Codable {
    let metrics: AnalyticsDashboard?
    let funnelSteps: [FunnelStep]?
    let retention: [RetentionRow]?
}

struct AnalyticsSubscription: Codable {
    let hasAccess: Bool
    let plan: String?
    let expiresAt: String?
}
