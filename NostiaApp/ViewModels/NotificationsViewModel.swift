import Foundation

@MainActor
final class NotificationsViewModel: ObservableObject {
    @Published var notifications: [NostiaNotification] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    var unreadCount: Int { notifications.filter { !$0.read }.count }

    func load() async {
        isLoading = true
        do {
            notifications = try await NotificationsAPI.shared.getAll(limit: 50)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func markAsRead(_ id: Int) async {
        do {
            try await NotificationsAPI.shared.markAsRead(id)
            if let idx = notifications.firstIndex(where: { $0.id == id }) {
                notifications[idx].read = true
            }
        } catch {}
    }

    func markAllAsRead() async {
        do {
            try await NotificationsAPI.shared.markAllAsRead()
            for idx in notifications.indices { notifications[idx].read = true }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
