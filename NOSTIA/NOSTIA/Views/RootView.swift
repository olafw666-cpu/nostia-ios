import SwiftUI

struct RootView: View {
    @EnvironmentObject var authManager: AuthManager
    @State private var showProfileBuilder = false
    @State private var showPaymentSetupPrompt = false
    @State private var inviteJoinedVault: String?
    @State private var showInviteJoined = false
    // Cold-launch splash. `@State` on the persistent root view means this only shows once
    // when the app process starts — not when navigating between screens.
    @State private var isLaunching = true

    var body: some View {
        ZStack {
            // Atlas (Light) canvas — soft off-white base behind every screen.
            LinearGradient.nostiaGradient
                .ignoresSafeArea()

            Group {
                if authManager.isAuthenticated {
                    MainTabView()
                } else {
                    AuthNavigationView()
                }
            }
        }
        .fullScreenCover(isPresented: $showProfileBuilder, onDismiss: {
            // Right after first-time profile setup, offer to set up payments. Guarded by
            // isAuthenticated so logging out mid-setup doesn't surface the prompt.
            if authManager.isAuthenticated { showPaymentSetupPrompt = true }
        }) {
            ProfileBuilderView {
                showProfileBuilder = false
            }
        }
        .fullScreenCover(isPresented: $showPaymentSetupPrompt) {
            PaymentSetupPromptView {
                showPaymentSetupPrompt = false
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
            showPaymentSetupPrompt = false
        }
        .overlay {
            if isLaunching {
                LaunchView()
                    .transition(.opacity)
                    .zIndex(100)
            }
        }
        .task {
            // Runs once on cold launch (RootView lives for the whole session). Hold the
            // splash briefly so the mark spins ~twice, then reveal the app.
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            withAnimation(.easeOut(duration: 0.4)) { isLaunching = false }
        }
        // Atlas is a light design system; lock the whole UI to light so a device in Dark
        // Mode can't bleed black through system surfaces (List/Form/Navigation/materials).
        .preferredColorScheme(.light)
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
