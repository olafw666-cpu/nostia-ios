import SwiftUI
import UIKit

/// Announce a message to VoiceOver (used for validation errors — Section 1.2
/// "Form labels and errors": errors must be announced, not conveyed by color alone).
func a11yAnnounce(_ message: String) {
    UIAccessibility.post(notification: .announcement, argument: message)
}

/// A friendly label for the recognized-devices list. MainActor-isolated because it
/// touches UIKit; computed by callers and handed to the network layer as a String.
@MainActor
func currentDeviceName() -> String {
    let name = UIDevice.current.name
    return name.isEmpty ? UIDevice.current.model : name
}

/// A labelled 6-digit numeric code entry field, accessible by construction.
struct OTPField: View {
    let label: String
    @Binding var code: String
    var onComplete: (() -> Void)? = nil
    @EnvironmentObject var responsive: ResponsiveLayoutManager
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.system(size: responsive.fontSize(14), weight: .semibold))
                .foregroundColor(.white.opacity(0.85))
            TextField("123456", text: $code)
                .keyboardType(.numberPad)
                .textContentType(.oneTimeCode)
                .font(.system(size: responsive.fontSize(24), weight: .bold, design: .monospaced))
                .tracking(8)
                .multilineTextAlignment(.center)
                .foregroundColor(.white)
                .padding(responsive.spacing(16))
                .glassEffect(in: RoundedRectangle(cornerRadius: 12))
                .focused($focused)
                .onChange(of: code) {
                    // Keep digits only, cap at 6, auto-submit when full.
                    let filtered = String(code.filter(\.isNumber).prefix(6))
                    if filtered != code { code = filtered }
                    if code.count == 6 { onComplete?() }
                }
                .accessibilityLabel(label)
                .accessibilityHint("Enter the 6-digit verification code")
        }
        .onAppear { focused = true }
    }
}

/// Primary gradient action button matching the app's auth style, accessible by construction.
struct TwoFactorPrimaryButton: View {
    let title: String
    var isLoading: Bool = false
    var disabled: Bool = false
    let action: () -> Void
    @EnvironmentObject var responsive: ResponsiveLayoutManager

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if isLoading { ProgressView().tint(.white) }
                Text(title)
            }
            .font(.system(size: responsive.fontSize(18), weight: .bold))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 44) // Section 1.2 minimum touch target
            .padding(responsive.spacing(16))
            .background(
                LinearGradient(colors: [Color.nostiaAccent, Color.nostriaPurple],
                               startPoint: .leading, endPoint: .trailing)
            )
            .cornerRadius(16)
            .opacity(disabled || isLoading ? 0.6 : 1)
        }
        .disabled(disabled || isLoading)
        .accessibilityLabel(title)
        .accessibilityAddTraits(.isButton)
    }
}
