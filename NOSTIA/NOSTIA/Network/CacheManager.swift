import Foundation

actor CacheManager {
    static let shared = CacheManager()
    private var store: [String: (value: Any, timestamp: Date)] = [:]
    private let ttl: TimeInterval = 30

    func get<T>(_ key: String) -> T? {
        guard let entry = store[key],
              Date().timeIntervalSince(entry.timestamp) < ttl else { return nil }
        return entry.value as? T
    }

    func set(_ key: String, value: Any) {
        store[key] = (value, Date())
    }

    func invalidate(_ key: String) { store.removeValue(forKey: key) }

    func invalidatePrefix(_ prefix: String) {
        store = store.filter { !$0.key.hasPrefix(prefix) }
    }

    func clearAll() { store.removeAll() }
}

enum CacheKey {
    static let homeFeed = "feed:home"
    static let notifications = "notifications"
    static let vaultList = "vault:list"
    static let followersList = "friends:followers"
    static let followingList = "friends:following"
    static let eventList = "events:list"

    static func userPosts(_ id: Int) -> String { "feed:user:\(id)" }
    static func vaultDetail(_ id: Int) -> String { "vault:detail:\(id)" }
    static func comments(_ postId: Int) -> String { "comments:\(postId)" }
}
