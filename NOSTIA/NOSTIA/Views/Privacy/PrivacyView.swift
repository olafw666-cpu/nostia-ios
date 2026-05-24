import SwiftUI
import SafariServices

struct PrivacyView: View {
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var responsive: ResponsiveLayoutManager
    @State private var user: User?
    @State private var consentStatus: ConsentStatus?
    @State private var isLoading = true
    @State private var showDeleteAlert = false
    @State private var message: String?
    @State private var showDeleteAccountStep1 = false
    @State private var showDeleteAccountStep2 = false
    @State private var isDeletingAccount = false
    @State private var deleteAccountError: String?
    @State private var navigateToPaymentMethods = false
    @State private var showEmailPrompt = false
    @State private var promptEmail = ""
    @State private var isSavingEmail = false
    @State private var emailSaveError: String?

    var body: some View {
        ScrollView {
            LazyVStack(spacing: responsive.spacing(16)) {
                if isLoading {
                    ProgressView().tint(Color.nostiaAccent).padding(40)
                } else {
                    // Account section
                    GlassSection(title: "Account") {
                        if let u = user {
                            GlassRow(icon: "person.fill", label: "Name", value: u.name)
                            GlassRow(icon: "at", label: "Username", value: "@\(u.username)")
                            if let email = u.email, !email.isEmpty {
                                GlassRow(icon: "envelope.fill", label: "Email", value: email)
                            }
                        }
                        Button {
                            if let email = user?.email, !email.isEmpty {
                                navigateToPaymentMethods = true
                            } else {
                                promptEmail = ""
                                emailSaveError = nil
                                showEmailPrompt = true
                            }
                        } label: {
                            HStack {
                                Image(systemName: "creditcard.fill").foregroundColor(Color.nostiaAccent).frame(width: 24)
                                Text("Payment Methods").foregroundColor(.white)
                                Spacer()
                                Image(systemName: "chevron.right").foregroundColor(Color.nostiaTextSecond)
                            }
                            .font(.subheadline).padding(responsive.spacing(16))
                            .overlay(Divider().background(Color.white.opacity(0.08)), alignment: .bottom)
                        }
                        .navigationDestination(isPresented: $navigateToPaymentMethods) {
                            PaymentMethodsView()
                                .navigationTitle("Payment Methods")
                                .navigationBarTitleDisplayMode(.inline)
                                .toolbarBackground(.hidden, for: .navigationBar)
                        }
                    }

                    // Privacy & Consent section
                    GlassSection(title: "Privacy & Consent") {
                        GlassRow(icon: "location.fill",
                                 label: "Location Consent",
                                 value: consentStatus?.locationConsent == true ? "Granted" : "Not granted",
                                 valueColor: consentStatus?.locationConsent == true ? Color.nostiaSuccess : Color.nostriaDanger)
                        GlassRow(icon: "chart.bar.fill",
                                 label: "Data Collection",
                                 value: consentStatus?.dataCollectionConsent == true ? "Granted" : "Not granted",
                                 valueColor: consentStatus?.dataCollectionConsent == true ? Color.nostiaSuccess : Color.nostriaDanger)

                        Button { showDeleteAccountStep1 = true } label: {
                            HStack {
                                Image(systemName: "person.crop.circle.badge.minus").foregroundColor(Color.nostriaDanger)
                                Text("Delete Account").foregroundColor(Color.nostriaDanger)
                                Spacer()
                                if isDeletingAccount {
                                    ProgressView().tint(Color.nostriaDanger)
                                } else {
                                    Image(systemName: "chevron.right").foregroundColor(Color.nostiaTextSecond)
                                }
                            }
                            .padding(responsive.spacing(16))
                        }
                        .disabled(isDeletingAccount)
                    }

                    if let err = deleteAccountError {
                        Text(err).font(.footnote).foregroundColor(Color.nostriaDanger)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(responsive.spacing(12))
                            .glassEffect(in: RoundedRectangle(cornerRadius: 10))
                    }

                    // Data section
                    GlassSection(title: "Your Data") {
                        Button { Task { await requestDataExport() } } label: {
                            HStack {
                                Image(systemName: "square.and.arrow.down").foregroundColor(Color.nostiaAccent)
                                Text("Request Data Export").foregroundColor(.white)
                                Spacer()
                                Image(systemName: "chevron.right").foregroundColor(Color.nostiaTextSecond)
                            }
                            .padding(responsive.spacing(16))
                        }

                        Button { showDeleteAlert = true } label: {
                            HStack {
                                Image(systemName: "trash.fill").foregroundColor(Color.nostriaDanger)
                                Text("Delete My Data").foregroundColor(Color.nostriaDanger)
                                Spacer()
                                Image(systemName: "chevron.right").foregroundColor(Color.nostiaTextSecond)
                            }
                            .padding(responsive.spacing(16))
                        }
                    }

                    // Legal section
                    GlassSection(title: "Legal") {
                        Button { openURL(AppConfig.termsOfServiceURL) } label: {
                            HStack {
                                Image(systemName: "doc.text.fill").foregroundColor(Color.nostiaAccent).frame(width: 24)
                                Text("Terms of Service").foregroundColor(.white)
                                Spacer()
                                Image(systemName: "arrow.up.right").foregroundColor(Color.nostiaTextSecond)
                            }
                            .font(.subheadline).padding(responsive.spacing(16))
                        }
                    }

                    // Logout
                    Button { authManager.logout() } label: {
                        HStack {
                            Spacer()
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                            Text("Logout")
                            Spacer()
                        }
                        .font(.headline).foregroundColor(.white)
                        .padding(responsive.spacing(16))
                        .background(Color.nostriaDanger).cornerRadius(14)
                        .shadow(color: Color.nostriaDanger.opacity(0.4), radius: 10, y: 5)
                    }

                    if let msg = message {
                        Text(msg).font(.footnote).foregroundColor(Color.nostiaSuccess)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(12)
                            .glassEffect(in: RoundedRectangle(cornerRadius: 10))
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.nostiaSuccess.opacity(0.4), lineWidth: 1))
                    }
                }
            }
            .padding(responsive.spacing(16)).padding(.bottom, 40)
            .frame(maxWidth: responsive.contentMaxWidth)
            .frame(maxWidth: .infinity)
        }
        .background(.clear)
        .task { await loadData() }
        .sheet(isPresented: $showEmailPrompt) {
            EmailCaptureSheet(
                email: $promptEmail,
                errorMessage: $emailSaveError,
                isSaving: $isSavingEmail,
                onSave: { Task { await saveEmailAndNavigate() } },
                onDismiss: { showEmailPrompt = false }
            )
        }
        .alert("Delete Your Account?", isPresented: $showDeleteAccountStep1) {
            Button("Cancel", role: .cancel) {}
            Button("Continue") { showDeleteAccountStep2 = true }
        } message: {
            Text("This will permanently delete your account and all associated data including your posts, events, vaults, messages, and follower relationships. This action cannot be undone.")
        }
        .alert("Are You Absolutely Sure?", isPresented: $showDeleteAccountStep2) {
            Button("Cancel", role: .cancel) {}
            Button("Delete Forever", role: .destructive) { Task { await deleteAccount() } }
        } message: {
            Text("Your account and all your data will be deleted forever. You will be logged out immediately. There is no way to recover your account after this step.")
        }
        .alert("Delete Data", isPresented: $showDeleteAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) { Task { await deleteData() } }
        } message: {
            Text("This will request deletion of all your personal data. This action cannot be undone.")
        }
    }

    func loadData() async {
        isLoading = true
        async let userData = AuthAPI.shared.getMe()
        async let consentResponseData: ConsentResponse? = try? APIClient.shared.request("/consent")
        let (u, c) = await (try? userData, await consentResponseData)
        user = u; consentStatus = c?.consent
        isLoading = false
    }

    func requestDataExport() async {
        try? await APIClient.shared.requestVoid("/privacy/data-request", method: "POST")
        message = "Data export requested. You'll receive an email when it's ready."
    }

    func deleteData() async {
        try? await APIClient.shared.requestVoid("/privacy/delete-data", method: "POST")
        authManager.logout()
    }

    func deleteAccount() async {
        isDeletingAccount = true
        deleteAccountError = nil
        do {
            try await APIClient.shared.requestVoid("/users/me", method: "DELETE")
            if let bgURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
                .first?.appendingPathComponent("home_background.jpg") {
                try? FileManager.default.removeItem(at: bgURL)
            }
            UserDefaults.standard.removeObject(forKey: "nostia_pending_invite_token")
            UserDefaults.standard.removeObject(forKey: "nostia_pending_profile_setup")
            authManager.logout()
        } catch {
            isDeletingAccount = false
            deleteAccountError = "Something went wrong. Your account was not deleted. Please try again."
        }
    }

    func openURL(_ urlString: String) {
        guard let url = URL(string: urlString) else { return }
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootVC = scene.keyWindow?.rootViewController else { return }
        var topVC = rootVC
        while let presented = topVC.presentedViewController { topVC = presented }
        let safari = SFSafariViewController(url: url)
        safari.modalPresentationStyle = .pageSheet
        topVC.present(safari, animated: true)
    }

    func saveEmailAndNavigate() async {
        let trimmed = promptEmail.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, trimmed.contains("@"), trimmed.contains(".") else {
            emailSaveError = "Please enter a valid email address."
            return
        }
        isSavingEmail = true
        emailSaveError = nil
        do {
            let updated = try await AuthAPI.shared.updateMe(["email": trimmed])
            user = updated
            showEmailPrompt = false
            navigateToPaymentMethods = true
        } catch {
            emailSaveError = "Failed to save email. Please try again."
        }
        isSavingEmail = false
    }
}

// MARK: - Email Capture Sheet

struct EmailCaptureSheet: View {
    @Binding var email: String
    @Binding var errorMessage: String?
    @Binding var isSaving: Bool
    let onSave: () -> Void
    let onDismiss: () -> Void
    @EnvironmentObject var responsive: ResponsiveLayoutManager

    var body: some View {
        NavigationStack {
            VStack(spacing: responsive.spacing(24)) {
                VStack(spacing: responsive.spacing(12)) {
                    Image(systemName: "envelope.badge.fill")
                        .font(.system(size: responsive.fontSize(48)))
                        .foregroundStyle(Color.nostiaAccent)
                    Text("Email Required")
                        .font(.title2.bold()).foregroundColor(.white)
                    Text("An email address is required to set up payment methods. This email is used by Stripe for account verification.")
                        .font(.subheadline).foregroundColor(Color.nostiaTextSecond)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, responsive.spacing(8))

                NostiaTextField(label: "Email", placeholder: "your@email.com", text: $email)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()

                if let err = errorMessage {
                    Text(err).font(.footnote).foregroundColor(Color.nostriaDanger)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                Button {
                    onSave()
                } label: {
                    HStack(spacing: 8) {
                        if isSaving {
                            ProgressView().tint(.white)
                        } else {
                            Image(systemName: "arrow.right.circle.fill")
                            Text("Save & Continue")
                        }
                    }
                    .font(.headline.bold()).foregroundColor(.white)
                    .frame(maxWidth: .infinity).padding(responsive.spacing(16))
                    .background(Color.nostiaAccent).cornerRadius(14)
                    .shadow(color: Color.nostiaAccent.opacity(0.4), radius: 8)
                }
                .disabled(isSaving || email.trimmingCharacters(in: .whitespaces).isEmpty)

                Spacer()
            }
            .padding(responsive.spacing(24))
            .frame(maxWidth: responsive.contentMaxWidth)
            .frame(maxWidth: .infinity)
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { onDismiss() }
                        .foregroundColor(Color.nostiaTextSecond)
                }
            }
        }
        .presentationBackground(.ultraThinMaterial)
        .presentationDetents([.medium])
    }
}

// Server wraps the consent object: { consent: { locationConsent: 1, ... }, isValid: bool }
// SQLite stores booleans as integers (0/1), so we decode as Int and derive Bool.
struct ConsentResponse: Decodable {
    let consent: ConsentStatus?
}

struct ConsentStatus: Decodable {
    private let locationConsentRaw: Int?
    private let dataCollectionConsentRaw: Int?

    var locationConsent: Bool { locationConsentRaw.map { $0 != 0 } ?? false }
    var dataCollectionConsent: Bool { dataCollectionConsentRaw.map { $0 != 0 } ?? false }

    enum CodingKeys: String, CodingKey {
        case locationConsentRaw = "locationConsent"
        case dataCollectionConsentRaw = "dataCollectionConsent"
    }
}

// MARK: - Glass Settings Components

struct GlassSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(.footnote.bold())
                .foregroundColor(Color.nostiaTextSecond)
                .padding(.horizontal, 4).padding(.bottom, 6)
            VStack(spacing: 0) {
                content()
            }
            .glassEffect(in: RoundedRectangle(cornerRadius: 16))
        }
    }
}

struct GlassRow: View {
    let icon: String
    let label: String
    let value: String
    var valueColor: Color = Color.nostiaTextSecond
    @EnvironmentObject var responsive: ResponsiveLayoutManager

    var body: some View {
        HStack {
            Image(systemName: icon).foregroundColor(Color.nostiaAccent).frame(width: 24)
            Text(label).foregroundColor(.white)
            Spacer()
            Text(value).foregroundColor(valueColor)
        }
        .font(.subheadline)
        .padding(responsive.spacing(16))
        .overlay(Divider().background(Color.white.opacity(0.08)), alignment: .bottom)
    }
}
