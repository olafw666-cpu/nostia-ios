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
            await syncCache()
        } catch {}
    }

    func markAllAsRead() async {
        do {
            try await NotificationsAPI.shared.markAllAsRead()
            for idx in notifications.indices { notifications[idx].read = true }
            await syncCache()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func delete(_ id: Int) async {
        do {
            try await NotificationsAPI.shared.delete(id)
            notifications.removeAll { $0.id == id }
            await syncCache()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func deleteAll() async {
        do {
            try await NotificationsAPI.shared.deleteAll()
            notifications = []
            await syncCache()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Keep the cache in step with local mutations — `load()` serves the cache first, so a
    /// stale copy would resurrect read/deleted notifications the next time the sheet opens.
    private func syncCache() async {
        await CacheManager.shared.set(CacheKey.notifications, value: notifications)
    }
}
