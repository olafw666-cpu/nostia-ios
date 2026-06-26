import SwiftUI

struct MainTabView: View {
    @EnvironmentObject private var deepLinkRouter: DeepLinkRouter
    @State private var unreadCount = 0
    @State private var showNotifications = false
    @State private var showProfile = false
    @State private var deepLinkProfileUserId: Int?
    @State private var headerImageData: String?
    @State private var headerInitial: String = "U"

    var body: some View {
        TabView(selection: $deepLinkRouter.selectedTab) {
            NavigationStack {
                HomeView(selectedTab: $deepLinkRouter.selectedTab)
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar { tabBarToolbar }
                    .toolbarBackground(.hidden, for: .navigationBar)
            }
            .tabItem { Label("Home", systemImage: "house") }
            .tag(0)

            NavigationStack {
                TripsView()
                    .navigationTitle("My Vaults")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar { tabBarToolbar }
                    .toolbarBackground(.hidden, for: .navigationBar)
            }
            .tabItem { Label("Vaults", systemImage: "creditcard") }
            .tag(1)

            NavigationStack {
                FriendsMapView()
                    .navigationTitle("Map")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar { tabBarToolbar }
                    .toolbarBackground(.hidden, for: .navigationBar)
            }
            .tabItem { Label("Map", systemImage: "map") }
            .tag(2)

            NavigationStack {
                ExperiencesView()
                    .navigationTitle("Experiences")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar { tabBarToolbar }
                    .toolbarBackground(.hidden, for: .navigationBar)
            }
            .tabItem { Label("Experiences", systemImage: "figure.walk") }
            .tag(3)

            NavigationStack {
                FriendsView()
                    .navigationTitle("Following")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar { tabBarToolbar }
                    .toolbarBackground(.hidden, for: .navigationBar)
            }
            .tabItem { Label("Following", systemImage: "person.2") }
            .tag(4)
        }
        .tabViewStyle(.sidebarAdaptable)
        .tint(Color.nostiaAccent)
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
            .presentationBackground(.ultraThinMaterial)
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
            .presentationBackground(.ultraThinMaterial)
        }
        .sheet(isPresented: $showProfile, onDismiss: { loadHeaderUser() }) {
            NavigationStack {
                ProfileView()
                    .navigationTitle("Profile")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            Button("Close") { showProfile = false }
                                .foregroundColor(Color.nostiaAccent)
                        }
                    }
                    .toolbarBackground(.hidden, for: .navigationBar)
            }
            .presentationBackground(.ultraThinMaterial)
        }
    }

    @ToolbarContentBuilder
    var tabBarToolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            HStack(spacing: 8) {
                Button {
                    Haptics.tap()
                    showNotifications = true
                    loadUnreadCount()
                    PushNotificationManager.shared.clearBadge()
                } label: {
                    ZStack(alignment: .topTrailing) {
                        Image(systemName: "bell")
                            .foregroundColor(.white)
                        if unreadCount > 0 {
                            Text(unreadCount > 9 ? "9+" : "\(unreadCount)")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white)
                                .padding(3)
                                .background(Color.nostriaDanger)
                                .clipShape(Circle())
                                .offset(x: 8, y: -8)
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
                        size: 30
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
