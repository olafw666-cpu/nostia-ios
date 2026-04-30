import SwiftUI

struct RootView: View {
    @EnvironmentObject var authManager: AuthManager
    @State private var showProfileBuilder = false
    @State private var inviteJoinedVault: String?
    @State private var showInviteJoined = false

    var body: some View {
        ZStack {
            // Rich gradient base — gives liquid glass surfaces something beautiful to refract
            LinearGradient(
                stops: [
                    .init(color: Color(hex: "0C1120"), location: 0.0),
                    .init(color: Color(hex: "1A0E35"), location: 0.5),
                    .init(color: Color(hex: "0A1628"), location: 1.0)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            Group {
                if authManager.isAuthenticated {
                    MainTabView()
                } else {
                    AuthNavigationView()
                }
            }
        }
        .fullScreenCover(isPresented: $showProfileBuilder) {
            ProfileBuilderView {
                showProfileBuilder = false
            }
        }
        .onOpenURL { url in
            guard url.scheme == "nostia",
                  url.host == "invite",
                  let token = url.pathComponents.last, !token.isEmpty else { return }
            if authManager.isAuthenticated {
                Task { await redeemToken(token) }
            } else {
                UserDefaults.standard.set(token, forKey: "nostia_pending_invite_token")
            }
        }
        .alert("Joined Vault", isPresented: $showInviteJoined) {
            Button("OK") {}
        } message: {
            Text("You've been added to \"\(inviteJoinedVault ?? "the vault")\". Check your Vaults tab.")
        }
        .onReceive(NotificationCenter.default.publisher(for: .userDidLogin)) { _ in
            authManager.isAuthenticated = true
            if UserDefaults.standard.bool(forKey: "nostia_pending_profile_setup") {
                UserDefaults.standard.removeObject(forKey: "nostia_pending_profile_setup")
                showProfileBuilder = true
            }
            if let token = UserDefaults.standard.string(forKey: "nostia_pending_invite_token") {
                UserDefaults.standard.removeObject(forKey: "nostia_pending_invite_token")
                Task { await redeemToken(token) }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .userDidLogout)) { _ in
            authManager.isAuthenticated = false
            showProfileBuilder = false
        }
    }

    @MainActor
    private func redeemToken(_ token: String) async {
        guard let result = try? await TripsAPI.shared.redeemInviteToken(token) else { return }
        inviteJoinedVault = result.vaultName
        showInviteJoined = true
    }
}

struct AuthNavigationView: View {
    var body: some View {
        NavigationStack {
            LoginView()
        }
    }
}
