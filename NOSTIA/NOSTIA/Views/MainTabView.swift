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
            .tabItem { Label("Home", systemImage: selectedTab == 0 ? "house.fill" : "house") }
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
            .tabItem { Label("Map", systemImage: selectedTab == 2 ? "map.fill" : "map") }
            .tag(2)

            NavigationStack {
                AdventuresView()
                    .navigationTitle("Discover")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar { tabBarToolbar }
                    .toolbarBackground(.hidden, for: .navigationBar)
            }
            .tabItem { Label("Discover", systemImage: selectedTab == 3 ? "safari.fill" : "safari") }
            .tag(3)

            NavigationStack {
                FriendsView()
                    .navigationTitle("Following")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar { tabBarToolbar }
                    .toolbarBackground(.hidden, for: .navigationBar)
            }
            .tabItem { Label("Following", systemImage: selectedTab == 4 ? "person.2.fill" : "person.2") }
            .tag(4)
        }
        .tint(Color.nostiaAccent)
        .onAppear {
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
                Button { showProfile = true } label: {
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
            }
        }
    }
}
