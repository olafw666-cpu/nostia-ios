import SwiftUI

struct MainTabView: View {
    @EnvironmentObject private var deepLinkRouter: DeepLinkRouter
    @EnvironmentObject private var responsive: ResponsiveLayoutManager
    @State private var unreadCount = 0
    @State private var showNotifications = false
    @State private var showProfile = false
    @State private var deepLinkProfileUserId: Int?
    @State private var deepLinkExperience: Experience?
    @State private var deepLinkActionsVM = ExperienceActionsViewModel()
    @State private var showVaults = false
    @State private var headerImageData: String?
    @State private var headerInitial: String = "U"

    // IA collapse (Product Definition v2 §3): two tabs. Adventure is the home
    // screen and the app's identity (List/Map toggle inside it — the old Map
    // tab is a view mode now); Friends holds the feed, the graph, and
    // Community. Vault is contextual (inside a plan / Profile), not a
    // destination. Old surfaces stay compiled and reachable as screens.
    private let tabs: [AtlasTabBar.Item] = [
        .init(tab: 0, icon: "sparkles", label: "Adventure"),
        .init(tab: 1, icon: "person.2.fill", label: "Friends"),
    ]

    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $deepLinkRouter.selectedTab) {
                tab(0) {
                    AdventureHomeView()
                }
                tab(1) {
                    FriendsHubView()
                }
            }
            .tint(Color.nostiaAccent)

            // Hidden while a pushed screen (e.g. a chat) needs the full bottom area, so its
            // input bar isn't covered by the floating bar. On iPad the bar is centered and
            // capped rather than stretched edge-to-edge across the wide landscape canvas.
            if !deepLinkRouter.isTabBarHidden {
                AtlasTabBar(selected: $deepLinkRouter.selectedTab, items: tabs)
                    .frame(maxWidth: responsive.isTablet ? 540 : .infinity)
                    .ignoresSafeArea(.keyboard)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.22), value: deepLinkRouter.isTabBarHidden)
        .onChange(of: deepLinkRouter.selectedTab) { Haptics.select() }
        .onAppear {
            LocationManager.shared.requestPermission()
            loadUnreadCount()
            loadHeaderUser()
            // Request push permission once the user is in the app (not on first launch).
            PushNotificationManager.shared.requestAuthorizationIfAppropriate()
            // A deep link that arrived before this view mounted (e.g. an invite link
            // opened while logged out) is already sitting in pendingTarget — .onChange
            // below never fires for it, so consume it here.
            if deepLinkRouter.pendingTarget != nil {
                handleDeepLink(deepLinkRouter.pendingTarget)
            }
        }
        .onChange(of: deepLinkRouter.pendingTarget) {
            handleDeepLink(deepLinkRouter.pendingTarget)
        }
        // "Replay App Tour" lives in Settings, two sheets deep (Profile → Settings).
        // Close them so the tour overlay RootView is about to show isn't buried.
        .onReceive(NotificationCenter.default.publisher(for: .replayAppTour)) { _ in
            showProfile = false
            showNotifications = false
        }
        // Re-fetch the unread count on dismiss — reads/deletes made inside the sheet
        // must clear the bell badge as soon as the sheet closes.
        .sheet(isPresented: $showNotifications, onDismiss: { loadUnreadCount() }) {
            NavigationStack {
                NotificationsView()
                    .navigationTitle("Notifications")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            Button("Close") { showNotifications = false }
                                .foregroundColor(Color.nostiaAccent)
                        }
                    }
                    .toolbarBackground(.hidden, for: .navigationBar)
            }
            .presentationBackground(Color.nostiaBackground)
        }
        .sheet(item: deepLinkProfileBinding) { wrapper in
            NavigationStack {
                PublicProfileView(userId: wrapper.id)
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            Button("Close") { deepLinkProfileUserId = nil }
                                .foregroundColor(Color.nostiaAccent)
                        }
                    }
            }
            .presentationBackground(Color.nostiaBackground)
        }
        // Experience-invite deep links present over whatever tab is active — the target
        // screen no longer depends on which tab (if any) shows experiences.
        .sheet(item: $deepLinkExperience) { event in
            ExperienceDetailSheet(event: event, vm: deepLinkActionsVM)
        }
        // Vaults are contextual now, not a tab (v2 §3): vault pushes and the
        // Profile → Your Vaults row land here.
        .sheet(isPresented: $showVaults) {
            NavigationStack {
                TripsView()
                    .background(Color.nostiaBackground.ignoresSafeArea())
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            Button("Close") { showVaults = false }
                                .foregroundColor(Color.nostiaAccent)
                        }
                    }
                    .toolbarBackground(.hidden, for: .navigationBar)
            }
            .presentationBackground(Color.nostiaBackground)
        }
        .sheet(isPresented: $showProfile, onDismiss: { loadHeaderUser() }) {
            NavigationStack {
                ProfileView()
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            Button("Close") { showProfile = false }
                                .foregroundColor(Color.nostiaAccent)
                        }
                    }
                    .toolbarBackground(.hidden, for: .navigationBar)
            }
            .presentationBackground(Color.nostiaBackground)
        }
    }

    // Each tab: a NavigationStack with the system tab bar hidden (we draw our own),
    // a transparent nav bar, and the floating bell + avatar cluster top-right.
    @ViewBuilder
    private func tab<Content: View>(_ tag: Int, @ViewBuilder _ content: () -> Content) -> some View {
        NavigationStack {
            content()
                // Themed canvas for every tab (white in light, grey in dark). Without this,
                // screens that don't paint their own background fall through to the system
                // black in dark mode (Explore / Vaults / Following did exactly that).
                .background(Color.nostiaBackground.ignoresSafeArea())
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { tabBarToolbar }
                .toolbarBackground(.hidden, for: .navigationBar)
                .toolbar(.hidden, for: .tabBar)
        }
        .tag(tag)
    }

    @ToolbarContentBuilder
    var tabBarToolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            HStack(spacing: 10) {
                Button {
                    Haptics.tap()
                    showNotifications = true
                    loadUnreadCount()
                    PushNotificationManager.shared.clearBadge()
                } label: {
                    ZStack(alignment: .topTrailing) {
                        Circle()
                            .fill(Color.nostiaCard)
                            .frame(width: 40, height: 40)
                            .shadow(color: Color.nostiaShadow.opacity(0.08), radius: 8, y: 2)
                            .overlay(
                                Image(systemName: "bell")
                                    .font(.nostiaBody(18))
                                    .foregroundColor(Color.nostiaTextSecond)
                            )
                        if unreadCount > 0 {
                            // No offset: the badge must stay inside the 40pt circle, or the
                            // toolbar's glass capsule clips it half-out of the bubble.
                            Text(unreadCount > 9 ? "9+" : "\(unreadCount)")
                                .font(.nostiaBody(10, weight: .bold))
                                .foregroundColor(.white)
                                .padding(3)
                                .background(Color.nostriaDanger)
                                .clipShape(Circle())
                        }
                    }
                }
                .accessibilityLabel(unreadCount > 0 ? "Notifications, \(unreadCount) unread" : "Notifications")
                .accessibilityHint("Opens your notifications")
                Button { Haptics.tap(); showProfile = true } label: {
                    UserAvatarView(
                        imageData: headerImageData,
                        initial: headerInitial,
                        color: Color.nostiaAccent,
                        size: 40
                    )
                }
                .accessibilityLabel("Profile")
                .accessibilityHint("Opens your profile and settings")
            }
        }
    }

    // Bridges the optional Int to a `.sheet(item:)`-friendly Identifiable value.
    private var deepLinkProfileBinding: Binding<IdentifiableInt?> {
        Binding(
            get: { deepLinkProfileUserId.map(IdentifiableInt.init) },
            set: { deepLinkProfileUserId = $0?.id }
        )
    }

    /// React to a tapped push (Section 3.3). Adventure targets switch to the
    /// home tab via the router; modal targets present here. Vaults stopped
    /// being a tab in the IA collapse, so vault pushes present the vault list
    /// as a sheet — TripsView still consumes pendingVaultTripId to open the
    /// right trip.
    private func handleDeepLink(_ target: DeepLinkRouter.Target?) {
        guard let target else { return }
        switch target {
        case .profile(let userId):
            deepLinkProfileUserId = userId
        case .event(let eventId):
            Task {
                let event = try? await ExperiencesAPI.shared.getExperience(id: eventId)
                await MainActor.run { deepLinkExperience = event }
            }
        case .notifications:
            showNotifications = true
            PushNotificationManager.shared.clearBadge()
        case .vault:
            showVaults = true
        case .adventure, .planInvite:
            break // handled on the home tab (AdventureHomeView consumes the token)
        }
        loadUnreadCount()
        deepLinkRouter.clear()
    }

    func loadUnreadCount() {
        Task {
            let count = try? await NotificationsAPI.shared.getUnreadCount()
            await MainActor.run { unreadCount = count ?? 0 }
        }
    }

    func loadHeaderUser() {
        Task {
            let user = try? await AuthAPI.shared.getMe()
            await MainActor.run {
                headerImageData = user?.profilePictureUrl
                headerInitial = user?.initial ?? "U"
                AuthManager.shared.isDev = user?.isDev ?? false
            }
        }
    }
}

// MARK: - Atlas floating bottom nav

struct AtlasTabBar: View {
    struct Item: Identifiable {
        let tab: Int
        let icon: String
        let label: String
        var id: Int { tab }
    }

    @Binding var selected: Int
    let items: [Item]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(items) { item in
                let on = selected == item.tab
                Button {
                    Haptics.select()
                    selected = item.tab
                } label: {
                    // Icon-only (labels removed per design). The active tab keeps its
                    // soft-green pill so the selection is still obvious without text.
                    Image(systemName: item.icon)
                        .font(.nostiaBody(23, weight: .semibold))
                        .foregroundColor(on ? Color.nostiaAccent : Color.nostiaTextSecond)
                        .frame(width: 54, height: 40)
                        .background {
                            if on {
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(Color.nostiaAccentSoft)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.nostiaTap)
                .accessibilityLabel(item.label)
                .accessibilityAddTraits(on ? [.isButton, .isSelected] : .isButton)
            }
        }
        .padding(.horizontal, 8)
        .frame(height: 60)
        // iOS 26 Liquid Glass: the floating bar refracts the content scrolling behind it. A
        // warm-grey tint keeps the bar from reading as a cold, too-dark slab in dark mode.
        .glassEffect(.regular.tint(Color.nostiaCard.opacity(0.5)),
                     in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(Color.nostiaCardStroke, lineWidth: 0.75)
        )
        .shadow(color: Color.nostiaShadow.opacity(0.22), radius: 28, x: 0, y: 12)
        .padding(.horizontal, 14)
        // Dock to the physical bottom and float a small gap above the home
        // indicator. Previously the bar stacked on top of the TabView's
        // (hidden-but-still-reserved) tab-bar inset *plus* the home-indicator
        // inset, which pushed it far too high up the screen.
        .padding(.bottom, 6)
        .ignoresSafeArea(.container, edges: .bottom)
    }
}
