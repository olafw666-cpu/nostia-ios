import SwiftUI
import AppTrackingTransparency

private enum SignupSheet: Identifiable {
    case tos, consent
    var id: String { switch self { case .tos: return "tos"; case .consent: return "consent" } }
}

struct SignupView: View {
    @StateObject private var vm = AuthViewModel()
    @State private var username = ""
    @State private var password = ""
    @State private var name = ""
    @State private var email = ""
    @State private var activeSheet: SignupSheet?
    @State private var tosAgreed = false
    @State private var attDenied = false
    @State private var consentGranted = false
    @State private var use2FA = false
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var responsive: ResponsiveLayoutManager

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                LinearGradient(colors: [Color.nostiaAccent, Color.nostriaPurple],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
                    .frame(maxWidth: .infinity).frame(height: responsive.spacing(240))
                    .overlay {
                        VStack(spacing: responsive.spacing(12)) {
                            Image(systemName: "safari.fill")
                                .font(.system(size: responsive.fontSize(64)))
                                .foregroundColor(.white)
                                .shadow(color: .white.opacity(0.3), radius: 20)
                            Text("Join Nostia")
                                .font(.system(size: responsive.fontSize(34), weight: .bold))
                                .foregroundColor(.white)
                            Text("Start your adventure today")
                                .font(.subheadline)
                                .foregroundColor(Color(hex: "E0E7FF"))
                        }
                    }

                VStack(spacing: responsive.spacing(20)) {
                    if let err = vm.errorMessage {
                        Text(err).font(.footnote).foregroundColor(Color.nostriaDanger)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(12)
                            .nostiaCard(in: RoundedRectangle(cornerRadius: 10))
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.nostriaDanger.opacity(0.5), lineWidth: 1))
                    }

                    NostiaTextField(label: "Full Name *", placeholder: "Enter your name", text: $name)
                        .textInputAutocapitalization(.words)

                    NostiaTextField(label: "Username *", placeholder: "Choose a username (3-30 chars)", text: $username)
                        .autocorrectionDisabled().textInputAutocapitalization(.never)

                    NostiaTextField(label: "Email (optional)", placeholder: "your@email.com", text: $email)
                        .keyboardType(.emailAddress).textInputAutocapitalization(.never)

                    NostiaSecureField(label: "Password *", placeholder: "At least 8 characters", text: $password)

                    // Optional Face ID 2FA opt-in — the passkey enrolls right after the
                    // account is created (system Face ID sheet), before the app opens.
                    Button { Haptics.tap(); use2FA.toggle() } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "faceid")
                                .font(.system(size: 22))
                                .foregroundColor(use2FA ? Color.nostiaSuccess : Color.nostiaAccent)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Use 2FA")
                                    .font(.subheadline.bold()).foregroundColor(Color.nostiaTextPrimary)
                                Text("Protect your account with Face ID. New devices will need Face ID to sign in, and you can recover your account with Face ID if you forget your password.")
                                    .font(.caption).foregroundColor(Color.nostiaTextSecond)
                                    .multilineTextAlignment(.leading)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            Spacer()
                            Image(systemName: use2FA ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 22))
                                .foregroundColor(use2FA ? Color.nostiaSuccess : Color.nostiaTextMuted)
                        }
                        .padding(responsive.spacing(14))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .nostiaCard(in: RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12)
                            .stroke(use2FA ? Color.nostiaSuccess.opacity(0.5) : Color.nostriaBorder, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Use 2FA")
                    .accessibilityValue(use2FA ? "On" : "Off")
                    .accessibilityHint("Adds Face ID security to your account right after it is created")

                    if consentGranted {
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.shield.fill").foregroundColor(Color.nostiaSuccess)
                            Text("Privacy consent granted").font(.subheadline).foregroundColor(Color.nostiaSuccess)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                        .nostiaCard(in: RoundedRectangle(cornerRadius: 10))
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.nostiaSuccess.opacity(0.4), lineWidth: 1))
                    }

                    Button {
                        let validationError = validate()
                        if let err = validationError { vm.errorMessage = err; return }
                        if !tosAgreed { activeSheet = .tos; return }
                        if !consentGranted { activeSheet = .consent; return }
                        Task { await submitSignup(locationConsent: true, dataConsent: true) }
                    } label: {
                        HStack(spacing: 8) {
                            if vm.isLoading { ProgressView().tint(.white) }
                            else {
                                Image(systemName: consentGranted ? "person.badge.plus" : "checkmark.shield")
                                Text(consentGranted ? "Create Account" : "Continue")
                            }
                        }
                        .font(.system(size: responsive.fontSize(18), weight: .bold)).foregroundColor(.white)
                        .frame(maxWidth: .infinity).padding(responsive.spacing(18))
                        .background(LinearGradient(colors: [Color.nostiaAccent, Color.nostriaPurple],
                                                   startPoint: .leading, endPoint: .trailing))
                        .cornerRadius(16)
                        .shadow(color: Color.nostiaAccent.opacity(0.4), radius: 12, y: 6)
                    }
                    .disabled(vm.isLoading)

                    Divider().background(Color.nostriaBorder)

                    Button { dismiss() } label: {
                        HStack(spacing: 4) {
                            Text("Already have an account?").foregroundColor(Color.nostiaTextSecond)
                            Text("Login").fontWeight(.bold).foregroundColor(Color.nostiaAccent)
                        }
                        .font(.subheadline)
                    }
                }
                .padding(responsive.spacing(24))
                .frame(maxWidth: responsive.contentMaxWidth)
                .frame(maxWidth: .infinity)
            }
        }
        // Pushed from Login — paints its own themed canvas (pushed destinations sit on the
        // system background, black in dark mode, not RootView's gradient).
        .background(Color.nostiaBackground.ignoresSafeArea())
        .navigationBarHidden(true)
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .tos:
                TermsAgreementView(
                    onAgree: {
                        tosAgreed = true
                        activeSheet = .consent
                    },
                    onDecline: {
                        activeSheet = nil
                        dismiss()
                    }
                )
            case .consent:
                ConsentSheet(onContinue: {
                    consentGranted = true
                    activeSheet = nil
                    Task { await submitSignup(locationConsent: true, dataConsent: true) }
                })
            }
        }
    }

    func validate() -> String? {
        let trimName = name.trimmingCharacters(in: .whitespaces)
        let trimUser = username.trimmingCharacters(in: .whitespaces)
        if trimName.isEmpty || trimName.count > 100 { return "Name is required (max 100 characters)" }
        if trimUser.count < 3 || trimUser.count > 30 { return "Username must be 3-30 characters" }
        if !trimUser.allSatisfy({ $0.isLetter || $0.isNumber || $0 == "_" }) {
            return "Username can only contain letters, numbers, and underscores"
        }
        if password.count < 8 { return "Password must be at least 8 characters" }
        return nil
    }

    func submitSignup(locationConsent: Bool, dataConsent: Bool) async {
        try? await Task.sleep(for: .milliseconds(400))
        let status = await ATTrackingManager.requestTrackingAuthorization()
        attDenied = (status != .authorized)
        _ = await vm.register(username: username, password: password, name: name, email: email,
                              locationConsent: locationConsent, dataCollectionConsent: dataConsent,
                              tosVersion: LegalDocuments.tosVersion, dataNotSold: attDenied,
                              enable2FA: use2FA)
    }
}
