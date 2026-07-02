import SwiftUI
import UIKit

extension View {
    /// Resigns the current first responder, dismissing the keyboard from anywhere
    /// in the view hierarchy (fields with no return key — number pads — have no
    /// other way out).
    func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}
