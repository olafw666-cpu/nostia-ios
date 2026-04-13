import Foundation

@MainActor
final class AnalyticsViewModel: ObservableObject {
    @Published var dashboard: AnalyticsDashboard?
    @Published var funnelSteps: [FunnelStep] = []
    @Published var retention: [RetentionRow] = []
    @Published var hasAccess = false
    @Published var selectedDays = 30
    @Published var isLoading = false
    @Published var errorMessage: String?

    func load() async {
        isLoading = true
        errorMessage = nil
        do {
            let sub = try await AnalyticsAPI.shared.getSubscription()
            hasAccess = sub.hasAccess
            if hasAccess {
                let data = try await AnalyticsAPI.shared.getDashboard(days: selectedDays)
                dashboard = data.metrics
                funnelSteps = data.funnelSteps ?? []
                retention = data.retention ?? []
            }
        } catch {
            // Access check might 403 for non-admins — that's expected
            hasAccess = false
        }
        isLoading = false
    }
}
