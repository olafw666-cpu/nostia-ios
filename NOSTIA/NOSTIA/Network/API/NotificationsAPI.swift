import Foundation

final class NotificationsAPI {
    static let shared = NotificationsAPI()
    private let client = APIClient.shared
    private init() {}

    func getAll(limit: Int = 50) async throws -> [NostiaNotification] {
        // Server may return array directly or { notifications: [] }
        if let arr: [NostiaNotification] = try? await client.request("/notifications?limit=\(limit)") {
            return arr
        }
        let res: NotificationsResponse = try await client.request("/notifications?limit=\(limit)")
        return res.notifications ?? []
    }

    func getUnreadCount() async throws -> Int {
        let res: UnreadCountResponse = try await client.request("/notifications/unread-count")
        return res.unreadCount
    }

    func markAsRead(_ id: Int) async throws {
        try await client.requestVoid("/notifications/\(id)/read", method: "PUT")
    }

    func markAllAsRead() async throws {
        try await client.requestVoid("/notifications/read-all", method: "PUT")
    }

    func savePushToken(_ token: String) async throws {
        try await client.requestVoid("/push-token", method: "POST", body: ["token": token])
    }
}
