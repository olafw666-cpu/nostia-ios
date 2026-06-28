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

    private init() {
        let raw = UserDefaults.standard.string(forKey: Self.storageKey)
        self.theme = raw.flatMap(AppTheme.init(rawValue:)) ?? .dark
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
