import SwiftUI

struct RootView: View {
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.scenePhase) private var scenePhase
    @State private var showProfileBuilder = false
    @State private var showPaymentSetupPrompt = false
    @State private var showThemePrompt = false
    @State private var inviteJoinedVault: String?
    @State private var showInviteJoined = false
    // Cold-launch splash. `@State` on the persistent root view means this only shows once
    // when the app process starts — not when navigating between screens.
    @State private var isLaunching = true

    var body: some View {
        ZStack {
            // Atlas (Dark) canvas — near-black charcoal base behind every screen.
            LinearGradient.nostiaGradient
                .ignoresSafeArea()

            Group {
                if authManager.isAuthenticated {
                    MainTabView()
                } else {
                    AuthNavigationView()
                }
            }
            // Rebuild the tree when the unlockable accent palette changes — the
            // `Color.nostiaAccent` tokens are computed from `AccentTheme.current`
            // at render time, so a full rebuild is what repaints every screen.
            .id(themeManager.accentTheme)
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
        .sheet(isPresented: $showThemePrompt, onDismiss: { themeManager.markFirstRunPromptShown() }) {
            ThemeChooserSheet()
                .presentationBackground(Color.nostiaBackground)
        }
        .onOpenURL { url in
            guard url.scheme == "nostia" else { return }
            switch url.host {
            case "invite":
                guard let token = url.pathComponents.last, !token.isEmpty else { return }
                if authManager.isAuthenticated {
                    Task { await redeemToken(token) }
                } else {
                    UserDefaults.standard.set(token, forKey: "nostia_pending_invite_token")
                }
            case "event":
                // nostia://event/<id> — from the shared-invite landing page's "Open in
                // Nostia" button. Routes through the same target pushes use.
                guard let idPart = url.pathComponents.last, let eventId = Int(idPart) else { return }
                if authManager.isAuthenticated {
                    DeepLinkRouter.shared.route(.event(eventId: eventId))
                } else {
                    UserDefaults.standard.set(eventId, forKey: "nostia_pending_event_id")
                }
            default:
                break
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
            let pendingEventId = UserDefaults.standard.integer(forKey: "nostia_pending_event_id")
            if pendingEventId > 0 {
                UserDefaults.standard.removeObject(forKey: "nostia_pending_event_id")
                // MainTabView mounts on the isAuthenticated flip above and picks this
                // pending target up in its .onAppear (its .onChange can't fire for a
                // target set before it exists).
                DeepLinkRouter.shared.route(.event(eventId: pendingEventId))
            }
            maybeShowThemePrompt()
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
            maybeShowThemePrompt()
        }
        // Drive the whole UI's appearance from the user's choice (default Dark) by pushing the
        // interface-style override onto the window directly. `.system` → `.unspecified`, which
        // makes the window track the device's Light/Dark setting and react to live toggles —
        // the previous `.preferredColorScheme(nil)` left a stale override and stopped updating.
        // Re-applied when the scene becomes active so it survives backgrounding / scene reconnect.
        .onAppear { themeManager.applyToWindows() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { themeManager.applyToWindows() }
        }
    }

    /// Show the one-time appearance prompt once the user is in the app — but never on top of
    /// the first-run profile/payment setup covers.
    private func maybeShowThemePrompt() {
        guard authManager.isAuthenticated,
              themeManager.shouldShowFirstRunPrompt,
              !showProfileBuilder, !showPaymentSetupPrompt else { return }
        showThemePrompt = true
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
