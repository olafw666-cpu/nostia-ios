import UIKit

/// Lightweight, reusable haptic feedback helpers.
/// Call the relevant method as the first line inside a button's action closure,
/// or via `.simultaneousGesture(TapGesture().onEnded { Haptics.tap() })` for
/// `NavigationLink` labels that don't expose an action closure.
enum Haptics {
    /// Light tap — for general button taps and navigation.
    static func tap() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    /// Selection change — for tab switches and segmented choices.
    static func select() {
        UISelectionFeedbackGenerator().selectionChanged()
    }

    /// Success notification — for completed primary actions.
    static func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    /// Configurable impact — defaults to medium for primary actions.
    static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .medium) {
        UIImpactFeedbackGenerator(style: style).impactOccurred()
    }
}
