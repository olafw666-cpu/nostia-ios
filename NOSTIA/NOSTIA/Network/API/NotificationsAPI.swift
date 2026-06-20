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

    /// Register this device's APNs token (platform "ios"). Multi-device on the backend.
    func savePushToken(_ token: String, platform: String = "ios") async throws {
        try await client.requestVoid("/push-token", method: "POST", body: ["token": token, "platform": platform])
    }

    /// Remove this device's token (e.g. on logout / permission revoked).
    func removePushToken(_ token: String) async throws {
        try await client.requestVoid("/push-token", method: "DELETE", body: ["token": token])
    }

    // MARK: - Push preference (single all-or-nothing toggle, spec Section 3.3)

    func getPushEnabled() async throws -> Bool {
        let res: PushSettingsResponse = try await client.request("/notifications/settings")
        return res.pushEnabled
    }

    func setPushEnabled(_ enabled: Bool) async throws {
        try await client.requestVoid("/notifications/settings", method: "PUT", body: ["pushEnabled": enabled])
    }
}

struct PushSettingsResponse: Decodable {
    let pushEnabled: Bool
}
