import SwiftUI

struct MainTabView: View {
    @EnvironmentObject private var deepLinkRouter: DeepLinkRouter
    @State private var unreadCount = 0
    @State private var showNotifications = false
    @State private var showProfile = false
    @State private var deepLinkProfileUserId: Int?
    @State private var headerImageData: String?
    @State private var headerInitial: String = "U"

    // Atlas bottom-nav order: Home · Explore · Vaults · Map · Following.
    private let tabs: [AtlasTabBar.Item] = [
        .init(tab: 0, icon: "house.fill", label: "Home"),
        .init(tab: 1, icon: "safari.fill", label: "Explore"),
        .init(tab: 2, icon: "wallet.bifold.fill", label: "Vaults"),
        .init(tab: 3, icon: "map.fill", label: "Map"),
        .init(tab: 4, icon: "person.2.fill", label: "Following"),
    ]

    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $deepLinkRouter.selectedTab) {
                tab(0) {
                    HomeView(selectedTab: $deepLinkRouter.selectedTab)
                }
                tab(1) {
                    ExperiencesView()
                }
                tab(2) {
                    TripsView()
                }
                tab(3) {
                    FriendsMapView()
                }
                tab(4) {
                    FriendsView()
                }
            }
            .tint(Color.nostiaAccent)

            AtlasTabBar(selected: $deepLinkRouter.selectedTab, items: tabs)
                .ignoresSafeArea(.keyboard)
        }
        .onChange(of: deepLinkRouter.selectedTab) { Haptics.select() }
        .onAppear {
            LocationManager.shared.requestPermission()
            loadUnreadCount()
            loadHeaderUser()
            // Request push permission once the user is in the app (not on first launch).
            PushNotificationManager.shared.requestAuthorizationIfAppropriate()
        }
        .onChange(of: deepLinkRouter.pendingTarget) {
            handleDeepLink(deepLinkRouter.pendingTarget)
        }
        .sheet(isPresented: $showNotifications) {
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
                                    .font(.system(size: 18))
                                    .foregroundColor(Color(hex: "4B5563"))
                            )
                        if unreadCount > 0 {
                            Text(unreadCount > 9 ? "9+" : "\(unreadCount)")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white)
                                .padding(3)
                                .background(Color.nostriaDanger)
                                .clipShape(Circle())
                                .offset(x: 4, y: -4)
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

    /// React to a tapped push (Section 3.3). Tab switching is handled by the router;
    /// here we present the modal targets (profile, notifications).
    private func handleDeepLink(_ target: DeepLinkRouter.Target?) {
        guard let target else { return }
        switch target {
        case .profile(let userId):
            deepLinkProfileUserId = userId
        case .notifications:
            showNotifications = true
            PushNotificationManager.shared.clearBadge()
        case .vault, .event:
            break // tab already selected by the router
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
                    VStack(spacing: 3) {
                        ZStack {
                            if on {
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(Color.nostiaAccentSoft)
                            }
                            Image(systemName: item.icon)
                                .font(.system(size: 21, weight: .semibold))
                                .foregroundColor(on ? Color.nostiaAccent : Color.nostiaTextMuted)
                        }
                        .frame(width: 44, height: 30)
                        Text(item.label)
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(on ? Color.nostiaAccent : Color.nostiaTextMuted)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(item.label)
                .accessibilityAddTraits(on ? [.isButton, .isSelected] : .isButton)
            }
        }
        .padding(.horizontal, 6)
        .frame(height: 74)
        .background(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(Color.nostiaCard)
                .shadow(color: Color.nostiaShadow.opacity(0.20), radius: 34, x: 0, y: 14)
        )
        .padding(.horizontal, 14)
        .padding(.bottom, 6)
    }
}
