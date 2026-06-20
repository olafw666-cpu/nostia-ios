import SwiftUI

/// Guided enable flow (Section 2.2): verify phone → verify email → activate.
struct TwoFactorSetupView: View {
    var existingEmail: String?
    var onComplete: () -> Void
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var responsive: ResponsiveLayoutManager

    private enum Step: Int { case phone, phoneCode, email, emailCode, confirm }
    @State private var step: Step = .phone

    @State private var phone = ""
    @State private var email = ""
    @State private var code = ""
    @State private var isLoading = false
    @State private var errorMessage: String?

    init(existingEmail: String?, onComplete: @escaping () -> Void) {
        self.existingEmail = existingEmail
        self.onComplete = onComplete
        _email = State(initialValue: existingEmail ?? "")
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: responsive.spacing(20)) {
                progressHeader

                if let errorMessage {
                    Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                        .font(.footnote).foregroundColor(Color.nostriaDanger)
                        .accessibilityLabel("Error: \(errorMessage)")
                }

                switch step {
                case .phone:     phoneStep
                case .phoneCode: codeStep(title: "Verify your phone",
                                          subtitle: "Enter the code we texted you.",
                                          action: verifyPhone)
                case .email:     emailStep
                case .emailCode: codeStep(title: "Verify your email",
                                          subtitle: "Enter the code we emailed you.",
                                          action: verifyEmail)
                case .confirm:   confirmStep
                }
            }
            .padding(responsive.spacing(24))
            .frame(maxWidth: responsive.contentMaxWidth)
            .frame(maxWidth: .infinity)
        }
        .background(.clear)
        .navigationTitle("Two-Factor Setup")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Cancel") { dismiss() }.foregroundColor(Color.nostiaAccent)
            }
        }
    }

    private var progressHeader: some View {
        let titles = ["Phone", "Code", "Email", "Code", "Done"]
        return VStack(alignment: .leading, spacing: 6) {
            Text("Step \(step.rawValue + 1) of 5")
                .font(.caption).foregroundColor(Color.nostiaTextMuted)
            ProgressView(value: Double(step.rawValue + 1), total: 5)
                .tint(Color.nostiaAccent)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Step \(step.rawValue + 1) of 5, \(titles[step.rawValue])")
    }

    private var phoneStep: some View {
        VStack(alignment: .leading, spacing: responsive.spacing(16)) {
            Text("Add a phone number to receive verification codes by SMS.")
                .font(.subheadline).foregroundColor(Color.nostiaTextSecond)
                .fixedSize(horizontal: false, vertical: true)
            NostiaTextField(label: "Phone number", placeholder: "+1 555 123 4567", text: $phone, keyboardType: .phonePad)
            TwoFactorPrimaryButton(title: "Send code", isLoading: isLoading,
                                   disabled: phone.trimmingCharacters(in: .whitespaces).count < 7) {
                Task { await startPhone() }
            }
        }
    }

    private var emailStep: some View {
        VStack(alignment: .leading, spacing: responsive.spacing(16)) {
            Text("Add an email as your recovery method.")
                .font(.subheadline).foregroundColor(Color.nostiaTextSecond)
                .fixedSize(horizontal: false, vertical: true)
            NostiaTextField(label: "Email", placeholder: "you@example.com", text: $email, keyboardType: .emailAddress)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
            TwoFactorPrimaryButton(title: "Send code", isLoading: isLoading,
                                   disabled: !email.contains("@")) {
                Task { await startEmail() }
            }
        }
    }

    private func codeStep(title: String, subtitle: String, action: @escaping () async -> Void) -> some View {
        VStack(alignment: .leading, spacing: responsive.spacing(16)) {
            Text(title).font(.headline).foregroundColor(.white)
            Text(subtitle).font(.subheadline).foregroundColor(Color.nostiaTextSecond)
            OTPField(label: "Verification code", code: $code) { Task { await action() } }
            TwoFactorPrimaryButton(title: "Verify", isLoading: isLoading, disabled: code.count != 6) {
                Task { await action() }
            }
        }
    }

    private var confirmStep: some View {
        VStack(alignment: .leading, spacing: responsive.spacing(16)) {
            Label("Phone and email verified", systemImage: "checkmark.seal.fill")
                .font(.headline).foregroundColor(Color.nostiaAccent)
            Text("Turn on two-factor authentication. You'll be asked for a code when signing in on a new device.")
                .font(.subheadline).foregroundColor(Color.nostiaTextSecond)
                .fixedSize(horizontal: false, vertical: true)
            TwoFactorPrimaryButton(title: "Turn on 2FA", isLoading: isLoading) {
                Task { await enable() }
            }
        }
    }

    // MARK: Actions

    private func startPhone() async {
        isLoading = true; errorMessage = nil
        do {
            _ = try await TwoFactorAPI.shared.startPhone(phone.trimmingCharacters(in: .whitespaces))
            code = ""; isLoading = false; step = .phoneCode
            a11yAnnounce("Code sent to your phone.")
        } catch { fail(error) }
    }
    private func verifyPhone() async {
        guard code.count == 6 else { return }
        isLoading = true; errorMessage = nil
        do {
            try await TwoFactorAPI.shared.verifyPhone(code: code)
            code = ""; isLoading = false; step = .email
        } catch { fail(error) }
    }
    private func startEmail() async {
        isLoading = true; errorMessage = nil
        do {
            _ = try await TwoFactorAPI.shared.startEmail(email.trimmingCharacters(in: .whitespaces))
            code = ""; isLoading = false; step = .emailCode
            a11yAnnounce("Code sent to your email.")
        } catch { fail(error) }
    }
    private func verifyEmail() async {
        guard code.count == 6 else { return }
        isLoading = true; errorMessage = nil
        do {
            try await TwoFactorAPI.shared.verifyEmail(code: code)
            code = ""; isLoading = false; step = .confirm
        } catch { fail(error) }
    }
    private func enable() async {
        isLoading = true; errorMessage = nil
        do {
            try await TwoFactorAPI.shared.enable()
            isLoading = false
            a11yAnnounce("Two-factor authentication is now on.")
            onComplete()
            dismiss()
        } catch { fail(error) }
    }

    private func fail(_ error: Error) {
        isLoading = false
        errorMessage = error.localizedDescription
        a11yAnnounce(error.localizedDescription)
    }
}
