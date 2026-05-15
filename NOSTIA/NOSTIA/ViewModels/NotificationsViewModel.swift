import Combine
import Foundation

@MainActor
final class NotificationsViewModel: ObservableObject {
    @Published var notifications: [NostiaNotification] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    var unreadCount: Int { notifications.filter { !$0.read }.count }

    func load() async {
        if let cached: [NostiaNotification] = await CacheManager.shared.get(CacheKey.notifications) {
            notifications = cached
        } else {
            isLoading = true
        }
        do {
            let fresh = try await NotificationsAPI.shared.getAll(limit: 50)
            notifications = fresh
            await CacheManager.shared.set(CacheKey.notifications, value: fresh)
        } catch {
            if notifications.isEmpty { errorMessage = error.localizedDescription }
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
