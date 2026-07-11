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

    private static let storageKey = "nostia_accent_theme"

    /// Read by the `Color.nostiaAccent`/`nostiaAccentSoft` tokens at render time.
    /// UserDefaults-backed so it's available before any view exists.
    static var current: AccentTheme {
        AccentTheme(rawValue: UserDefaults.standard.string(forKey: storageKey) ?? "") ?? .stock
    }

    static func persist(_ theme: AccentTheme) {
        UserDefaults.standard.set(theme.rawValue, forKey: storageKey)
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
        didSet { AccentTheme.persist(accentTheme) }
    }

    private init() {
        let raw = UserDefaults.standard.string(forKey: Self.storageKey)
        self.theme = raw.flatMap(AppTheme.init(rawValue:)) ?? .dark
        self.accentTheme = AccentTheme.current
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

    /// One-time post-login appearance prompt — true until the user has seen it once.
    var shouldShowFirstRunPrompt: Bool {
        !UserDefaults.standard.bool(forKey: Self.promptKey)
    }

    func markFirstRunPromptShown() {
        UserDefaults.standard.set(true, forKey: Self.promptKey)
    }
}
