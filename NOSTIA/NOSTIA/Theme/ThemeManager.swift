import SwiftUI
import Combine
import UIKit

// MARK: - App theme

/// The three appearance modes the user can pick. `system` follows the device's
/// Light/Dark setting (the Apple Control-Center / Settings toggle).
enum AppTheme: String, CaseIterable, Identifiable {
    case system, light, dark

    var id: String { rawValue }

    var label: String {
        switch self {
        case .system: return "System"
        case .light:  return "Light"
        case .dark:   return "Dark"
        }
    }

    var icon: String {
        switch self {
        case .system: return "iphone"
        case .light:  return "sun.max.fill"
        case .dark:   return "moon.fill"
        }
    }

    var blurb: String {
        switch self {
        case .system: return "Match your device"
        case .light:  return "Bright & airy"
        case .dark:   return "Easy on the eyes"
        }
    }

    /// `nil` means "follow the system" — handed straight to `.preferredColorScheme`.
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light:  return .light
        case .dark:   return .dark
        }
    }

    /// UIKit interface-style override applied to the window. `.system` maps to `.unspecified`
    /// so the window genuinely *follows* the device's Light/Dark setting and reacts to live
    /// Control-Center / Settings toggles at runtime — unlike `.preferredColorScheme(nil)`,
    /// which leaves a stale override after it has previously held a concrete value.
    var overrideStyle: UIUserInterfaceStyle {
        switch self {
        case .system: return .unspecified
        case .light:  return .light
        case .dark:   return .dark
        }
    }
}

// MARK: - Accent theme (Adventure Page cosmetics, spec §9)

/// Unlockable accent palettes bought with adventure points. Only the accent
/// tokens change — canvas, cards and text keep the stock Atlas values, so every
/// screen adapts without extra work. The server gates UNLOCK state only
/// (`user_cosmetics`); rendering is entirely client-side. `stock` is the
/// green-Light / orange-Dark pair everyone starts with.
enum AccentTheme: String, CaseIterable, Identifiable {
    case stock, blue, pink, darkRed

    var id: String { rawValue }

    /// The palette in force right now, regardless of who's signed in. Kept as a
    /// single unqualified key on purpose: `Color.nostiaAccent` reads it on the
    /// render hot path and must not have to consult auth state to draw a colour.
    private static let storageKey = "nostia_accent_theme"

    /// Read by the `Color.nostiaAccent`/`nostiaAccentSoft` tokens at render time.
    /// UserDefaults-backed so it's available before any view exists.
    static var current: AccentTheme {
        AccentTheme(rawValue: UserDefaults.standard.string(forKey: storageKey) ?? "") ?? .stock
    }

    /// Per-account remembered choice. Unlocks are per account (`user_cosmetics`),
    /// so the applied palette is stored per account too — otherwise UserDefaults,
    /// which outlives a logout, hands the next account signed in on this device a
    /// palette it never earned (audit D12.3).
    private static func accountKey(_ userId: Int) -> String { "\(storageKey).\(userId)" }

    /// `owner == nil` (signed out) writes the active palette only, leaving each
    /// account's own choice intact for its next sign-in.
    static func persist(_ theme: AccentTheme, owner: Int?) {
        UserDefaults.standard.set(theme.rawValue, forKey: storageKey)
        if let owner {
            UserDefaults.standard.set(theme.rawValue, forKey: accountKey(owner))
        }
    }

    /// Marks the one-time hand-off from the old unqualified key to per-account
    /// keys. Device-wide, not per-account, so exactly one account can inherit.
    private static let legacyMigratedKey = "nostia_accent_theme_migrated"

    /// What `owner` last chose — stock when signed out or when this account has
    /// never picked one.
    ///
    /// Performs the one-time legacy migration as a side effect: installs from
    /// before per-account storage have only the unqualified value, and silently
    /// resetting a palette the user did earn would be a regression. The first
    /// account to sign in after the update inherits it — and only the first, so a
    /// second account on the same device still starts at stock.
    /// `reconcileAccentEntitlement` verifies ownership against the server either
    /// way, so inheriting can never grant an unearned palette for long.
    static func stored(owner: Int?) -> AccentTheme {
        guard let owner else { return .stock }
        if let raw = UserDefaults.standard.string(forKey: accountKey(owner)) {
            return AccentTheme(rawValue: raw) ?? .stock
        }
        guard !UserDefaults.standard.bool(forKey: legacyMigratedKey) else { return .stock }
        UserDefaults.standard.set(true, forKey: legacyMigratedKey)
        let inherited = current
        UserDefaults.standard.set(inherited.rawValue, forKey: accountKey(owner))
        return inherited
    }

    /// Store key on `cosmetic_items` (nil = stock, never purchasable).
    var cosmeticKey: String? {
        switch self {
        case .stock: return nil
        case .blue: return "theme_blue"
        case .pink: return "theme_pink"
        case .darkRed: return "theme_dark_red"
        }
    }

    static func forCosmeticKey(_ key: String) -> AccentTheme? {
        allCases.first { $0.cosmeticKey == key }
    }

    var label: String {
        switch self {
        case .stock: return "Nostia"
        case .blue: return "Blue"
        case .pink: return "Pink"
        case .darkRed: return "Dark Red"
        }
    }

    // Primary accent (light / dark hex).
    var accentLight: String {
        switch self {
        case .stock: return "0E9F6E"
        case .blue: return "2563EB"
        case .pink: return "DB2777"
        case .darkRed: return "9F1D2E"
        }
    }
    var accentDark: String {
        switch self {
        case .stock: return "E8843C"
        case .blue: return "4A9BE0"
        case .pink: return "F472B6"
        case .darkRed: return "D24B52"
        }
    }

    // Soft tint background behind the accent (light / dark hex).
    var accentSoftLight: String {
        switch self {
        case .stock: return "E7F6EF"
        case .blue: return "E3EDFB"
        case .pink: return "FCE7F3"
        case .darkRed: return "F9E3E5"
        }
    }
    var accentSoftDark: String {
        switch self {
        case .stock: return "45321E"
        case .blue: return "1E2C3E"
        case .pink: return "3C2231"
        case .darkRed: return "3C1F22"
        }
    }
}

// MARK: - Theme manager

/// Persists the user's appearance choice and exposes it to the view tree. `RootView`
/// observes this and feeds `theme.colorScheme` into `.preferredColorScheme`, which flips
/// the whole UI (and every dynamic `Color(light:dark:)` token) between palettes.
@MainActor
final class ThemeManager: ObservableObject {
    static let shared = ThemeManager()

    private static let storageKey = "nostia_app_theme"
    private static let promptKey  = "nostia_theme_prompt_shown"

    /// Current appearance. New installs default to Dark (the flagship look).
    @Published var theme: AppTheme {
        didSet {
            UserDefaults.standard.set(theme.rawValue, forKey: Self.storageKey)
            applyToWindows()
        }
    }

    /// Unlockable accent palette (Adventure store). Views read the actual colors
    /// through the `Color.nostiaAccent` tokens; publishing this only exists to
    /// force a re-render — `RootView` rebuilds the tree via `.id(accentTheme)`.
    @Published var accentTheme: AccentTheme {
        didSet { AccentTheme.persist(accentTheme, owner: accentOwnerId) }
    }

    /// Which account `accentTheme` currently belongs to. Tracked explicitly
    /// rather than read from `AuthManager` at write time because `logout()`
    /// clears `currentUserId` asynchronously — reading it during sign-out would
    /// race, and losing that race would overwrite the departing account's
    /// remembered palette with stock.
    private var accentOwnerId: Int?

    private init() {
        let raw = UserDefaults.standard.string(forKey: Self.storageKey)
        self.theme = raw.flatMap(AppTheme.init(rawValue:)) ?? .dark
        self.accentOwnerId = AuthManager.shared.currentUserId
        self.accentTheme = AccentTheme.stored(owner: AuthManager.shared.currentUserId)
    }

    /// Push the current choice's interface-style override onto every live window. Driving
    /// `overrideUserInterfaceStyle` directly (not just `.preferredColorScheme`) is what makes
    /// `.system` actually track the device appearance switch while the app is running. Call on
    /// launch (once a window exists) and whenever `theme` changes (handled by `didSet`).
    func applyToWindows() {
        let style = theme.overrideStyle
        for scene in UIApplication.shared.connectedScenes {
            guard let windowScene = scene as? UIWindowScene else { continue }
            for window in windowScene.windows {
                window.overrideUserInterfaceStyle = style
            }
        }
    }

    // MARK: - Accent entitlement (audit D12.3)

    /// Unlocks are server state (`user_cosmetics`); the *applied* palette lives in
    /// UserDefaults. That made device-local storage the only thing standing
    /// between a user and a palette they hadn't earned, in two ways: the value
    /// outlived a logout (so it followed the device to the next account), and
    /// nothing ever re-checked ownership (so a palette written locally by any
    /// means stayed applied indefinitely). Per-account keys close the first;
    /// this closes the second.
    ///
    /// Called on launch and on login. Silent on network failure — the palette is
    /// cosmetic, so a flaky connection must not flip the user's theme; the next
    /// successful reconcile settles it.
    func reconcileAccentEntitlement() async {
        guard AuthManager.shared.isAuthenticated else { return }
        guard let key = accentTheme.cosmeticKey else { return }   // stock is never gated
        guard let catalog = try? await AdventureAPI.shared.getCosmetics() else { return }
        let owned = catalog.items.contains { $0.key == key && $0.owned }
        if !owned { accentTheme = .stock }
    }

    /// Sign-in: adopt the palette this account last chose, never whatever the
    /// previous account left applied on this device.
    func adoptAccentForSignedInAccount() {
        accentOwnerId = AuthManager.shared.currentUserId
        accentTheme = AccentTheme.stored(owner: accentOwnerId)
    }

    /// Sign-out: show stock. Clearing the owner first means the write lands on
    /// the active-palette key only, so the departing account's choice survives
    /// for its next sign-in.
    func clearAccentForSignOut() {
        accentOwnerId = nil
        accentTheme = .stock
    }

    /// One-time post-login appearance prompt — true until the user has seen it once.
    var shouldShowFirstRunPrompt: Bool {
        !UserDefaults.standard.bool(forKey: Self.promptKey)
    }

    func markFirstRunPromptShown() {
        UserDefaults.standard.set(true, forKey: Self.promptKey)
    }
}
