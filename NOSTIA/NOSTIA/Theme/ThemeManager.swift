import SwiftUI
import Combine

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
        didSet { UserDefaults.standard.set(theme.rawValue, forKey: Self.storageKey) }
    }

    private init() {
        let raw = UserDefaults.standard.string(forKey: Self.storageKey)
        self.theme = raw.flatMap(AppTheme.init(rawValue:)) ?? .dark
    }

    /// One-time post-login appearance prompt — true until the user has seen it once.
    var shouldShowFirstRunPrompt: Bool {
        !UserDefaults.standard.bool(forKey: Self.promptKey)
    }

    func markFirstRunPromptShown() {
        UserDefaults.standard.set(true, forKey: Self.promptKey)
    }
}
