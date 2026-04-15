import SwiftUI

struct PrivacyView: View {
    @EnvironmentObject var authManager: AuthManager
    @State private var user: User?
    @State private var consentStatus: ConsentStatus?
    @State private var isLoading = true
    @State private var showDeleteAlert = false
    @State private var showRevokeAlert = false
    @State private var message: String?

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
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
                        NavigationLink {
                            PaymentMethodsView()
                                .navigationTitle("Payment Methods")
                                .navigationBarTitleDisplayMode(.inline)
                                .toolbarBackground(.hidden, for: .navigationBar)
                        } label: {
                            HStack {
                                Image(systemName: "creditcard.fill").foregroundColor(Color.nostiaAccent).frame(width: 24)
                                Text("Payment Methods").foregroundColor(.white)
                                Spacer()
                                Image(systemName: "chevron.right").foregroundColor(Color.nostiaTextSecond)
                            }
                            .font(.subheadline).padding(16)
                            .overlay(Divider().background(Color.white.opacity(0.08)), alignment: .bottom)
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

                        Button { showRevokeAlert = true } label: {
                            HStack {
                                Image(systemName: "xmark.shield").foregroundColor(Color.nostriaDanger)
                                Text("Revoke All Consent").foregroundColor(Color.nostriaDanger)
                                Spacer()
                                Image(systemName: "chevron.right").foregroundColor(Color.nostiaTextSecond)
                            }
                            .padding(16)
                        }
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
                            .padding(16)
                        }

                        Button { showDeleteAlert = true } label: {
                            HStack {
                                Image(systemName: "trash.fill").foregroundColor(Color.nostriaDanger)
                                Text("Delete My Data").foregroundColor(Color.nostriaDanger)
                                Spacer()
                                Image(systemName: "chevron.right").foregroundColor(Color.nostiaTextSecond)
                            }
                            .padding(16)
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
                        .padding(16)
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
            .padding(16).padding(.bottom, 40)
        }
        .background(.clear)
        .task { await loadData() }
        .alert("Revoke Consent", isPresented: $showRevokeAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Revoke", role: .destructive) { Task { await revokeConsent() } }
        } message: {
            Text("This will revoke all consents and you may lose access to some features.")
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
        async let consentData: ConsentStatus? = try? APIClient.shared.request("/consent")
        let (u, c) = await (try? userData, await consentData)
        user = u; consentStatus = c
        isLoading = false
    }

    func revokeConsent() async {
        try? await APIClient.shared.requestVoid("/consent/revoke", method: "POST")
        message = "Consent revoked."
        await loadData()
    }

    func requestDataExport() async {
        try? await APIClient.shared.requestVoid("/privacy/data-request", method: "POST")
        message = "Data export requested. You'll receive an email when it's ready."
    }

    func deleteData() async {
        try? await APIClient.shared.requestVoid("/privacy/delete-data", method: "POST")
        authManager.logout()
    }
}

struct ConsentStatus: Decodable {
    let locationConsent: Bool?
    let dataCollectionConsent: Bool?
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

    var body: some View {
        HStack {
            Image(systemName: icon).foregroundColor(Color.nostiaAccent).frame(width: 24)
            Text(label).foregroundColor(.white)
            Spacer()
            Text(value).foregroundColor(valueColor)
        }
        .font(.subheadline)
        .padding(16)
        .overlay(Divider().background(Color.white.opacity(0.08)), alignment: .bottom)
    }
}
