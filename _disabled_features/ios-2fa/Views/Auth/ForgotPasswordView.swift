import SwiftUI

/// Account recovery (Section 2.4). Step 1: request a code to the verified phone/email.
/// Step 2: enter the code and set a new password.
struct ForgotPasswordView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var responsive: ResponsiveLayoutManager

    private enum Step { case request, reset, done }
    @State private var step: Step = .request

    @State private var identifier = ""
    @State private var preferEmail = false
    @State private var code = ""
    @State private var newPassword = ""
    @State private var confirmPassword = ""

    @State private var challengeToken: String?
    @State private var destinationHint: String?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var infoMessage: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: responsive.spacing(20)) {
                header

                if let errorMessage {
                    Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                        .font(.footnote).foregroundColor(Color.nostriaDanger)
                        .accessibilityLabel("Error: \(errorMessage)")
                }
                if let infoMessage {
                    Label(infoMessage, systemImage: "info.circle.fill")
                        .font(.footnote).foregroundColor(Color.nostiaAccent)
                }

                switch step {
                case .request: requestStep
                case .reset:   resetStep
                case .done:    doneStep
                }
            }
            .padding(responsive.spacing(24))
            .frame(maxWidth: responsive.contentMaxWidth)
            .frame(maxWidth: .infinity)
        }
        .background(.clear)
        .navigationTitle("Reset Password")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: "key.horizontal.fill")
                .font(.system(size: responsive.fontSize(40)))
                .foregroundColor(Color.nostiaAccent)
                .accessibilityHidden(true)
            Text("Recover your account")
                .font(.system(size: responsive.fontSize(24), weight: .bold))
                .foregroundColor(.white)
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: Step 1

    private var requestStep: some View {
        VStack(alignment: .leading, spacing: responsive.spacing(16)) {
            NostiaTextField(label: "Username or email", placeholder: "Enter your username or email", text: $identifier)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)

            Toggle(isOn: $preferEmail) {
                Text("Send code to my email instead of SMS").foregroundColor(.white)
            }
            .tint(Color.nostiaAccent)

            TwoFactorPrimaryButton(title: "Send recovery code", isLoading: isLoading,
                                   disabled: identifier.trimmingCharacters(in: .whitespaces).isEmpty) {
                Task { await requestCode() }
            }
        }
    }

    // MARK: Step 2

    private var resetStep: some View {
        VStack(alignment: .leading, spacing: responsive.spacing(16)) {
            Text("Enter the 6-digit code we sent to \(destinationHint ?? "your verified contact"), then choose a new password.")
                .font(.subheadline).foregroundColor(Color.nostiaTextSecond)
                .fixedSize(horizontal: false, vertical: true)

            OTPField(label: "Recovery code", code: $code)
            NostiaSecureField(label: "New password", placeholder: "At least 8 characters", text: $newPassword)
            NostiaSecureField(label: "Confirm new password", placeholder: "Re-enter your new password", text: $confirmPassword)

            TwoFactorPrimaryButton(title: "Reset password", isLoading: isLoading, disabled: !canReset) {
                Task { await resetPassword() }
            }
            Button("Resend code") { Task { await requestCode() } }
                .font(.footnote).foregroundColor(Color.nostiaAccent)
                .frame(maxWidth: .infinity)
        }
    }

    private var doneStep: some View {
        VStack(alignment: .leading, spacing: responsive.spacing(16)) {
            Label("Your password has been reset.", systemImage: "checkmark.seal.fill")
                .font(.headline).foregroundColor(Color.nostiaAccent)
            TwoFactorPrimaryButton(title: "Back to login") { dismiss() }
        }
    }

    private var canReset: Bool {
        code.count == 6 && newPassword.count >= 8 && newPassword == confirmPassword
    }

    // MARK: Actions

    private func requestCode() async {
        isLoading = true; errorMessage = nil; infoMessage = nil
        do {
            let res = try await AuthAPI.shared.forgotPassword(
                identifier: identifier.trimmingCharacters(in: .whitespaces),
                channel: preferEmail ? "email" : "sms"
            )
            isLoading = false
            if let token = res.challengeToken {
                challengeToken = token
                destinationHint = res.destinationHint
                if let dev = res.devCode { code = dev }
                step = .reset
                a11yAnnounce("Recovery code sent. Enter the code to continue.")
            } else {
                // Generic response — do not reveal whether the account exists.
                infoMessage = res.message ?? "If an account exists, a recovery code has been sent."
            }
        } catch {
            isLoading = false
            errorMessage = error.localizedDescription
            a11yAnnounce(error.localizedDescription)
        }
    }

    private func resetPassword() async {
        guard let token = challengeToken else { return }
        guard newPassword == confirmPassword else {
            errorMessage = "Passwords do not match"; a11yAnnounce("Passwords do not match"); return
        }
        isLoading = true; errorMessage = nil
        do {
            try await AuthAPI.shared.resetPassword(challengeToken: token, code: code, newPassword: newPassword)
            isLoading = false
            step = .done
            a11yAnnounce("Your password has been reset.")
        } catch {
            isLoading = false
            errorMessage = error.localizedDescription
            a11yAnnounce(error.localizedDescription)
        }
    }
}
