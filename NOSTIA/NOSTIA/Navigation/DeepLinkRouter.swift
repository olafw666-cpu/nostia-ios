import Combine
import SwiftUI

/// Central router for push-notification deep links (spec Section 3.3 "Tap behavior").
/// A tapped push sets a pending target; `MainTabView` observes it, switches to the
/// relevant tab, and/or presents the relevant screen.
@MainActor
final class DeepLinkRouter: ObservableObject {
    static let shared = DeepLinkRouter()

    enum Target: Equatable {
        case vault(tripId: Int?)     // expense reminder, added-to-vault, payment received
        case profile(userId: Int)    // new follower
        case event(eventId: Int)     // event invite
        case notifications           // fallback
    }

    /// Bound to the tab selection in `MainTabView`.
    @Published var selectedTab: Int = 0
    /// The most recent deep-link target awaiting presentation.
    @Published var pendingTarget: Target?

    private init() {}

    /// Map a push payload's `data` dictionary to a navigation target and route to it.
    func handle(userInfo: [AnyHashable: Any]) {
        let type = userInfo["type"] as? String
        func intVal(_ key: String) -> Int? {
            if let i = userInfo[key] as? Int { return i }
            if let s = userInfo[key] as? String { return Int(s) }
            return nil
        }
        switch type {
        case "vault_reminder", "added_to_vault", "payment_received":
            route(.vault(tripId: intVal("tripId")))
        case "new_follower":
            if let uid = intVal("userId") { route(.profile(userId: uid)) }
            else { route(.notifications) }
        case "event_invite":
            if let eid = intVal("eventId") { route(.event(eventId: eid)) }
            else { route(.notifications) }
        default:
            route(.notifications)
        }
    }

    func route(_ target: Target) {
        switch target {
        case .vault:  selectedTab = 1   // Vaults tab
        case .event:  selectedTab = 3   // Events tab
        case .profile, .notifications:
            break                       // presented modally over the current tab
        }
        pendingTarget = target
    }

    func clear() { pendingTarget = nil }
}

/// Lightweight Identifiable wrapper so a bare Int can drive `.sheet(item:)`.
struct IdentifiableInt: Identifiable {
    let id: Int
}
