import SwiftUI

struct PrivacyView: View {
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var responsive: ResponsiveLayoutManager
    @EnvironmentObject var themeManager: ThemeManager
    @State private var user: User?
    @State private var consentStatus: ConsentStatus?
    @State private var isLoading = true
    @State private var showDeleteAlert = false
    @State private var message: String?
    @State private var showDeleteAccountStep1 = false
    @State private var showDeleteAccountStep2 = false
    @State private var isDeletingAccount = false
    @State private var deleteAccountError: String?
    @State private var showTermsSheet = false
    @State private var showResetDemoAlert = false
    @State private var trackingEnabled = true
    @State private var navigateToBlockedUsers = false
    @State private var navigateToNotifications = false
    @State private var navigateToPasskeys = false

    var body: some View {
        ScrollView {
            LazyVStack(spacing: responsive.spacing(16)) {
                if isLoading {
                    ProgressView().tint(Color.nostiaAccent).padding(40)
                } else {
                    // Appearance section — Light/Dark/System theme switch.
                    GlassSection(title: "Appearance") {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: "circle.lefthalf.filled")
                                    .foregroundColor(Color.nostiaAccent).frame(width: 24)
                                Text("Theme").foregroundColor(Color.nostiaTextPrimary)
                                Spacer()
                            }
                            .font(.subheadline)
                            Picker("Theme", selection: $themeManager.theme) {
                                ForEach(AppTheme.allCases) { option in
                                    Text(option.label).tag(option)
                                }
                            }
                            .pickerStyle(.segmented)
                            Text("“System” follows your device's Light/Dark setting.")
                                .font(.caption).foregroundColor(Color.nostiaTextSecond)
                        }
                        .padding(responsive.spacing(16))
                    }

                    // Account section
                    GlassSection(title: "Account") {
                        if let u = user {
                            GlassRow(icon: "person.fill", label: "Name", value: u.name)
                            GlassRow(icon: "at", label: "Username", value: "@\(u.username)")
                            if let email = u.email, !email.isEmpty {
                                GlassRow(icon: "envelope.fill", label: "Email", value: email)
                            }
                        }
                    }

                    // Help section
                    GlassSection(title: "Help") {
                        Button {
                            Haptics.tap()
                            // RootView shows the tour; MainTabView closes the sheets
                            // this row is sitting inside.
                            NotificationCenter.default.post(name: .replayAppTour, object: nil)
                        } label: {
                            HStack {
                                Image(systemName: "figure.wave").foregroundColor(Color.nostiaAccent).frame(width: 24)
                                Text("Replay App Tour").foregroundColor(Color.nostiaTextPrimary)
                                Spacer()
                                Image(systemName: "chevron.right").foregroundColor(Color.nostiaTextSecond)
                            }
                            .font(.subheadline).padding(responsive.spacing(16))
                        }
                        .buttonStyle(.nostiaTap)
                        .accessibilityHint("Shows the walkthrough of the app's main features again")
                    }

                    // Demo section — only compiled into the screen when the app is
                    // running against the on-device backend. Restores the seeded world
                    // so a showing always starts from the same place.
                    if AppConfig.isDemoMode {
                        GlassSection(title: "Demo") {
                            Button {
                                Haptics.tap()
                                showResetDemoAlert = true
                            } label: {
                                HStack {
                                    Image(systemName: "arrow.counterclockwise")
                                        .foregroundColor(Color.nostiaAccent).frame(width: 24)
                                    Text("Reset demo data").foregroundColor(Color.nostiaTextPrimary)
                                    Spacer()
                                    Image(systemName: "chevron.right").foregroundColor(Color.nostiaTextSecond)
                                }
                                .font(.subheadline).padding(responsive.spacing(16))
                            }
                            .buttonStyle(.nostiaTap)
                            .accessibilityHint("Discards everything done in this demo and restores the starting data")
                        }
                    }

                    // Notifications section
                    GlassSection(title: "Notifications") {
                        Button { navigateToNotifications = true } label: {
                            HStack {
                                Image(systemName: "bell.badge.fill").foregroundColor(Color.nostiaAccent).frame(width: 24)
                                Text("Notifications").foregroundColor(Color.nostiaTextPrimary)
                                Spacer()
                                Image(systemName: "chevron.right").foregroundColor(Color.nostiaTextSecond)
                            }
                            .font(.subheadline).padding(responsive.spacing(16))
                        }
                        .buttonStyle(.nostiaTap)
                        .accessibilityHint("Turn push notifications on or off")
                        .navigationDestination(isPresented: $navigateToNotifications) {
                            NotificationSettingsView()
                                .background(Color.nostiaBackground.ignoresSafeArea())
                        }
                    }

                    // Security section
                    GlassSection(title: "Security") {
                        Button { navigateToPasskeys = true } label: {
                            HStack {
                                Image(systemName: "faceid").foregroundColor(Color.nostiaAccent).frame(width: 24)
                                Text("Face ID & Recovery").foregroundColor(Color.nostiaTextPrimary)
                                Spacer()
                                Image(systemName: "chevron.right").foregroundColor(Color.nostiaTextSecond)
                            }
                            .font(.subheadline).padding(responsive.spacing(16))
                        }
                        .buttonStyle(.nostiaTap)
                        .accessibilityHint("Protect your account with Face ID and set up password recovery")
                        .navigationDestination(isPresented: $navigateToPasskeys) {
                            PasskeySettingsView()
                                .background(Color.nostiaBackground.ignoresSafeArea())
                        }
                    }

                    // Safety section
                    GlassSection(title: "Safety") {
                        Button { navigateToBlockedUsers = true } label: {
                            HStack {
                                Image(systemName: "nosign").foregroundColor(Color.nostiaAccent).frame(width: 24)
                                Text("Blocked Users").foregroundColor(Color.nostiaTextPrimary)
                                Spacer()
                                Image(systemName: "chevron.right").foregroundColor(Color.nostiaTextSecond)
                            }
                            .font(.subheadline).padding(responsive.spacing(16))
                        }
                        .buttonStyle(.nostiaTap)
                        .navigationDestination(isPresented: $navigateToBlockedUsers) {
                            BlockedUsersView()
                                .background(Color.nostiaBackground.ignoresSafeArea())
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
                        .buttonStyle(.nostiaTap)
                        .disabled(isDeletingAccount)
                    }

                    if let err = deleteAccountError {
                        Text(err).font(.footnote).foregroundColor(Color.nostriaDanger)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(responsive.spacing(12))
                            .nostiaCard(in: RoundedRectangle(cornerRadius: 10))
                    }

                    // Data section
                    GlassSection(title: "Your Data") {
                        Button { Task { await requestDataExport() } } label: {
                            HStack {
                                Image(systemName: "square.and.arrow.down").foregroundColor(Color.nostiaAccent)
                                Text("Request Data Export").foregroundColor(Color.nostiaTextPrimary)
                                Spacer()
                                Image(systemName: "chevron.right").foregroundColor(Color.nostiaTextSecond)
                            }
                            .padding(responsive.spacing(16))
                        }
                        .buttonStyle(.nostiaTap)

                        Button { showDeleteAlert = true } label: {
                            HStack {
                                Image(systemName: "trash.fill").foregroundColor(Color.nostriaDanger)
                                Text("Delete My Data").foregroundColor(Color.nostriaDanger)
                                Spacer()
                                Image(systemName: "chevron.right").foregroundColor(Color.nostiaTextSecond)
                            }
                            .padding(responsive.spacing(16))
                        }
                        .buttonStyle(.nostiaTap)
                    }

                    // Legal section
                    GlassSection(title: "Legal") {
                        HStack {
                            Image(systemName: "hand.raised.fill").foregroundColor(Color.nostiaAccent).frame(width: 24)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Allow Data Tracking").foregroundColor(Color.nostiaTextPrimary)
                                Text("Used to personalise your experience")
                                    .font(.caption).foregroundColor(Color.nostiaTextSecond)
                            }
                            Spacer()
                            Toggle("", isOn: $trackingEnabled)
                                .tint(Color.nostiaAccent)
                                .labelsHidden()
                                .onChange(of: trackingEnabled) { newValue in
                                    Task { await updateTracking(enabled: newValue) }
                                }
                        }
                        .font(.subheadline)
                        .padding(responsive.spacing(16))
                        .overlay(Divider().background(Color.nostiaDivider), alignment: .bottom)

                        Button { showTermsSheet = true } label: {
                            HStack {
                                Image(systemName: "doc.text.fill").foregroundColor(Color.nostiaAccent).frame(width: 24)
                                Text("Terms of Service").foregroundColor(Color.nostiaTextPrimary)
                                Spacer()
                                Image(systemName: "chevron.right").foregroundColor(Color.nostiaTextSecond)
                            }
                            .font(.subheadline).padding(responsive.spacing(16))
                        }
                        .buttonStyle(.nostiaTap)
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
                            .nostiaCard(in: RoundedRectangle(cornerRadius: 10))
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
        .sheet(isPresented: $showTermsSheet) {
            LegalDocumentView()
        }
        .alert("Reset demo data?", isPresented: $showResetDemoAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Reset", role: .destructive) {
                Task {
                    await DemoStore.shared.reset()
                    await CacheManager.shared.clearAll()
                    await loadData()
                }
            }
        } message: {
            Text("Everything posted, sent, or settled in this demo is discarded and the starting data comes back.")
        }
        .alert("Delete Your Account?", isPresented: $showDeleteAccountStep1) {
            Button("Cancel", role: .cancel) {}
            Button("Continue") { showDeleteAccountStep2 = true }
        } message: {
            Text("This will permanently delete your account and all associated data including your posts, experiences, vaults, messages, and follower relationships. This action cannot be undone.")
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
        trackingEnabled = !(u?.dataNotSold ?? false)
        isLoading = false
    }

    func updateTracking(enabled: Bool) async {
        do {
            let updated = try await AuthAPI.shared.updateMe(["data_not_sold": enabled ? 0 : 1])
            user = updated
        } catch {
            trackingEnabled = !enabled
        }
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
            UserDefaults.standard.removeObject(forKey: "nostia_pending_app_tour")
            authManager.logout()
        } catch {
            isDeletingAccount = false
            deleteAccountError = "Something went wrong. Your account was not deleted. Please try again."
        }
    }

}

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
            .nostiaCard(in: RoundedRectangle(cornerRadius: 16))
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
            Text(label).foregroundColor(Color.nostiaTextPrimary)
            Spacer()
            Text(value).foregroundColor(valueColor)
        }
        .font(.subheadline)
        .padding(responsive.spacing(16))
        .overlay(Divider().background(Color.nostiaDivider), alignment: .bottom)
    }
}
