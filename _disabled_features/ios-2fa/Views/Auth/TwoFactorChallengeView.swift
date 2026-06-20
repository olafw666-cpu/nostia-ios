import SwiftUI

/// Shown after a correct password when 2FA is required on an unrecognized device
/// (Section 2.3). Verifies the 6-digit code and completes login.
struct TwoFactorChallengeView: View {
    var onSuccess: () -> Void
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var responsive: ResponsiveLayoutManager

    private let challengeToken: String
    private let emailFallbackAvailable: Bool

    @State private var code = ""
    @State private var rememberDevice = true
    @State private var channel: String
    @State private var destinationHint: String?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var infoMessage: String?

    init(challenge: LoginChallenge, onSuccess: @escaping () -> Void) {
        self.onSuccess = onSuccess
        self.challengeToken = challenge.challengeToken
        self.emailFallbackAvailable = challenge.emailFallbackAvailable
        _channel = State(initialValue: challenge.channel)
        _destinationHint = State(initialValue: challenge.destinationHint)
        _code = State(initialValue: challenge.devCode ?? "")
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: responsive.spacing(20)) {
                VStack(alignment: .leading, spacing: 8) {
                    Image(systemName: "lock.shield")
                        .font(.system(size: responsive.fontSize(44)))
                        .foregroundColor(Color.nostiaAccent)
                        .accessibilityHidden(true)
                    Text("Two-Factor Verification")
                        .font(.system(size: responsive.fontSize(26), weight: .bold))
                        .foregroundColor(.white)
                    Text(promptText)
                        .font(.subheadline)
                        .foregroundColor(Color.nostiaTextSecond)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .accessibilityElement(children: .combine)

                if let errorMessage {
                    Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                        .font(.footnote)
                        .foregroundColor(Color.nostriaDanger)
                        .accessibilityLabel("Error: \(errorMessage)")
                }
                if let infoMessage {
                    Label(infoMessage, systemImage: "checkmark.circle.fill")
                        .font(.footnote)
                        .foregroundColor(Color.nostiaAccent)
                }

                OTPField(label: "Verification code", code: $code) { Task { await verify() } }

                Toggle(isOn: $rememberDevice) {
                    Text("Remember this device")
                        .foregroundColor(.white)
                }
                .tint(Color.nostiaAccent)
                .accessibilityHint("Skip 2FA on this device next time")

                TwoFactorPrimaryButton(title: "Verify & Sign In", isLoading: isLoading,
                                       disabled: code.count != 6) {
                    Task { await verify() }
                }

                VStack(spacing: 10) {
                    Button("Resend code") { Task { await resend(channel: channel) } }
                        .foregroundColor(Color.nostiaAccent)
                        .accessibilityHint("Send a new code to your \(channel == "email" ? "email" : "phone")")
                    if emailFallbackAvailable && channel != "email" {
                        Button("Send code to email instead") { Task { await resend(channel: "email") } }
                            .foregroundColor(Color.nostiaAccent)
                    }
                }
                .font(.footnote)
                .frame(maxWidth: .infinity)
            }
            .padding(responsive.spacing(24))
            .frame(maxWidth: responsive.contentMaxWidth)
            .frame(maxWidth: .infinity)
        }
        .background(.clear)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Cancel") { dismiss() }.foregroundColor(Color.nostiaAccent)
            }
        }
        .navigationTitle("Verify")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var promptText: String {
        let target = destinationHint ?? (channel == "email" ? "your email" : "your phone")
        return "Enter the 6-digit code we sent to \(target)."
    }

    private func verify() async {
        guard code.count == 6, !isLoading else { return }
        isLoading = true; errorMessage = nil
        do {
            try await AuthAPI.shared.verifyLoginCode(
                challengeToken: challengeToken, code: code, rememberDevice: rememberDevice,
                deviceName: rememberDevice ? currentDeviceName() : nil
            )
            isLoading = false
            onSuccess()
        } catch {
            isLoading = false
            errorMessage = error.localizedDescription
            a11yAnnounce(error.localizedDescription)
        }
    }

    private func resend(channel newChannel: String) async {
        errorMessage = nil; infoMessage = nil
        do {
            let res = try await AuthAPI.shared.resendLoginCode(challengeToken: challengeToken, channel: newChannel)
            channel = res.channel ?? newChannel
            destinationHint = res.destinationHint ?? destinationHint
            if let dev = res.devCode { code = dev }
            infoMessage = "A new code was sent."
            a11yAnnounce("A new code was sent to your \(channel == "email" ? "email" : "phone").")
        } catch {
            errorMessage = error.localizedDescription
            a11yAnnounce(error.localizedDescription)
        }
    }
}
