import SwiftUI

struct MainTabView: View {
    @State private var selectedTab = 0
    @State private var unreadCount = 0
    @State private var showNotifications = false
    @State private var showProfile = false
    @State private var headerImageData: String?
    @State private var headerInitial: String = "U"

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                HomeView(selectedTab: $selectedTab)
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
                EventsView()
                    .navigationTitle("Events")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar { tabBarToolbar }
                    .toolbarBackground(.hidden, for: .navigationBar)
            }
            .tabItem { Label("Events", systemImage: "calendar") }
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
        .onChange(of: selectedTab) { Haptics.select() }
        .onAppear {
            LocationManager.shared.requestPermission()
            loadUnreadCount()
            loadHeaderUser()
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
                Button { Haptics.tap(); showProfile = true } label: {
                    UserAvatarView(
                        imageData: headerImageData,
                        initial: headerInitial,
                        color: Color.nostiaAccent,
                        size: 30
                    )
                }
            }
        }
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
