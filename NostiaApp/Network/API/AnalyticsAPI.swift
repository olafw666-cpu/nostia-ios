import Foundation

final class AnalyticsAPI {
    static let shared = AnalyticsAPI()
    private let client = APIClient.shared
    private init() {}

    func getDashboard(days: Int = 30) async throws -> AnalyticsDashboardResponse {
        try await client.request("/analytics/dashboard?days=\(days)")
    }

    func getFunnels(days: Int = 30) async throws -> [FunnelStep] {
        try await client.request("/analytics/funnels?days=\(days)")
    }

    func getRetention(days: Int = 30) async throws -> [RetentionRow] {
        try await client.request("/analytics/retention?days=\(days)")
    }

    func getSubscription() async throws -> AnalyticsSubscription {
        try await client.request("/analytics/subscription")
    }
}
