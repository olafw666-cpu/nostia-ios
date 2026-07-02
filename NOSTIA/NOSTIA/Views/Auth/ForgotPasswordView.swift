import SwiftUI

/// Account recovery with Face ID. No username or email is asked for: the user
/// picks their Nostia passkey in the system sheet, which both identifies the
/// account and proves ownership, then sets a new password. Only available to
/// accounts that enabled Face ID security in Settings.
struct ForgotPasswordView: View {
    @EnvironmentObject var responsive: ResponsiveLayoutManager
    @Environment(\.dismiss) private var dismiss

    @State private var newPassword = ""
    @State private var confirmPassword = ""
    @State private var isWorking = false
    @State private var errorMessage: String?
    @State private var didReset = false

    var body: some View {
        ScrollView {
            VStack(spacing: responsive.spacing(20)) {
                VStack(spacing: responsive.spacing(12)) {
                    Image(systemName: "faceid")
                        .font(.system(size: responsive.fontSize(56)))
                        .foregroundColor(Color.nostiaAccent)
                    Text("Reset with Face ID")
                        .font(.system(size: responsive.fontSize(26), weight: .bold))
                        .foregroundColor(Color.nostiaTextPrimary)
                    Text("If you enabled Face ID security on your account, you can set a new password by confirming with Face ID — no email or codes needed.")
                        .font(.subheadline)
                        .foregroundColor(Color.nostiaTextSecond)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.top, responsive.spacing(32))

                if didReset {
                    VStack(spacing: responsive.spacing(12)) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title)
                            .foregroundColor(Color.nostiaSuccess)
                        Text("Password reset. Sign in with your new password.")
                            .font(.subheadline).foregroundColor(Color.nostiaTextPrimary)
                            .multilineTextAlignment(.center)
                        Button("Back to Login") { dismiss() }
                            .font(.headline).foregroundColor(Color.nostiaAccent)
                    }
                    .padding(responsive.spacing(20))
                    .frame(maxWidth: .infinity)
                    .nostiaCard(in: RoundedRectangle(cornerRadius: 14))
                } else {
                    if let errorMessage {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundColor(Color.nostriaDanger)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(12)
                            .nostiaCard(in: RoundedRectangle(cornerRadius: 10))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color.nostriaDanger.opacity(0.5), lineWidth: 1)
                            )
                    }

                    NostiaSecureField(label: "New Password", placeholder: "At least 8 characters", text: $newPassword)
                    NostiaSecureField(label: "Confirm New Password", placeholder: "Repeat the new password", text: $confirmPassword)

                    Button {
                        Task { await reset() }
                    } label: {
                        HStack(spacing: 8) {
                            if isWorking {
                                ProgressView().tint(.white)
                            } else {
                                Image(systemName: "faceid")
                                Text("Confirm with Face ID")
                            }
                        }
                        .font(.system(size: responsive.fontSize(17), weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(responsive.spacing(16))
                        .background(
                            LinearGradient(colors: [Color.nostiaAccent, Color.nostriaPurple],
                                           startPoint: .leading, endPoint: .trailing)
                        )
                        .cornerRadius(14)
                    }
                    .disabled(isWorking)

                    Text("Didn't enable Face ID security? Your account can't be recovered automatically — contact support from the app store listing.")
                        .font(.caption).foregroundColor(Color.nostiaTextMuted)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(responsive.spacing(24))
            .frame(maxWidth: responsive.contentMaxWidth)
            .frame(maxWidth: .infinity)
        }
        .background(.clear)
        .scrollBounceBehavior(.basedOnSize)
        .navigationTitle("Forgot Password")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func reset() async {
        errorMessage = nil
        guard newPassword.count >= 8 else {
            errorMessage = "Password must be at least 8 characters"
            return
        }
        guard newPassword == confirmPassword else {
            errorMessage = "Passwords don't match"
            return
        }
        isWorking = true
        do {
            let options = try await PasskeyAPI.shared.recoveryOptions()
            let assertion = try await PasskeyManager.shared.assert(options: options)
            try await PasskeyAPI.shared.resetPassword(response: assertion, newPassword: newPassword)
            didReset = true
        } catch PasskeyManager.PasskeyError.canceled {
            // User backed out of the system sheet — not an error.
        } catch {
            errorMessage = error.localizedDescription
        }
        isWorking = false
    }
}
