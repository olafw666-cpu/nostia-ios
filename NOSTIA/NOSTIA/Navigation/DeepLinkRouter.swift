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
    /// Tags a themed Home "See all" wants Explore to pre-check. `ExperiencesView`
    /// consumes a non-empty value into its filter, then clears it so a later manual
    /// visit to Explore isn't re-filtered.
    @Published var pendingExploreTags: [String] = []
    /// Trip whose vault a tapped push wants opened. Switching to the Vaults tab alone
    /// can't push the detail screen, so `TripsView` consumes this (and clears it) once
    /// its trip list contains the target.
    @Published var pendingVaultTripId: Int?

    /// How many pushed full-bottom screens (e.g. chat views, whose pinned input bar would
    /// otherwise sit *under* the floating `AtlasTabBar`) currently want the bar hidden.
    /// A depth counter rather than a `Bool` so overlapping push/pop transitions can never
    /// leave the bar stuck hidden. `MainTabView` hides the bar while this is > 0.
    @Published var tabBarHiddenDepth: Int = 0
    var isTabBarHidden: Bool { tabBarHiddenDepth > 0 }

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
        case "vault_reminder", "added_to_vault", "payment_received", "vault_expense":
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
        case .vault(let tripId):
            selectedTab = 2             // Vaults tab (Atlas order: Home·Explore·Vaults·Map·Following)
            if let tripId { pendingVaultTripId = tripId }
        case .event:  selectedTab = 1   // Explore / Experiences tab
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

// MARK: - Floating tab bar visibility

private struct HidesAppTabBar: ViewModifier {
    @EnvironmentObject private var router: DeepLinkRouter

    func body(content: Content) -> some View {
        content
            .onAppear { router.tabBarHiddenDepth += 1 }
            .onDisappear { router.tabBarHiddenDepth = max(0, router.tabBarHiddenDepth - 1) }
    }
}

extension View {
    /// Hides the floating bottom `AtlasTabBar` while this screen is on-screen. Use on pushed
    /// detail screens whose own bottom-pinned controls (e.g. a chat message bar) would
    /// otherwise be covered by the floating bar.
    func hidesAppTabBar() -> some View { modifier(HidesAppTabBar()) }
}
