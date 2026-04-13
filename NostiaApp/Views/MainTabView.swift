import SwiftUI

struct MainTabView: View {
    @State private var selectedTab = 0
    @State private var unreadCount = 0
    @State private var showNotifications = false
    @State private var showSettings = false
    @State private var showAnalytics = false
    @State private var userRole: String = "user"

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                HomeView()
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar { tabBarToolbar }
                    .toolbarBackground(.hidden, for: .navigationBar)
            }
            .tabItem { Label("Home", systemImage: selectedTab == 0 ? "house.fill" : "house") }
            .tag(0)

            NavigationStack {
                TripsView()
                    .navigationTitle("My Trips")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar { tabBarToolbar }
                    .toolbarBackground(.hidden, for: .navigationBar)
            }
            .tabItem { Label("Trips", systemImage: "airplane") }
            .tag(1)

            NavigationStack {
                FeedView()
                    .navigationTitle("Feed")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar { tabBarToolbar }
                    .toolbarBackground(.hidden, for: .navigationBar)
            }
            .tabItem { Label("Feed", systemImage: selectedTab == 2 ? "photo.on.rectangle.angled.fill" : "photo.on.rectangle.angled") }
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
                    .navigationTitle("Friends")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar { tabBarToolbar }
                    .toolbarBackground(.hidden, for: .navigationBar)
            }
            .tabItem { Label("Friends", systemImage: selectedTab == 4 ? "person.2.fill" : "person.2") }
            .tag(4)

            NavigationStack {
                FriendsMapView()
                    .navigationTitle("Friends Map")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar { tabBarToolbar }
                    .toolbarBackground(.hidden, for: .navigationBar)
            }
            .tabItem { Label("Map", systemImage: selectedTab == 5 ? "map.fill" : "map") }
            .tag(5)
        }
        .tint(Color.nostiaAccent)
        .onAppear {
            loadUnreadCount()
            loadUserRole()
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
        .sheet(isPresented: $showSettings) {
            NavigationStack {
                PrivacyView()
                    .navigationTitle("Settings")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            Button("Close") { showSettings = false }
                                .foregroundColor(Color.nostiaAccent)
                        }
                        if userRole == "admin" {
                            ToolbarItem(placement: .topBarTrailing) {
                                Button("Analytics") { showAnalytics = true }
                                    .foregroundColor(Color.nostiaAccent)
                            }
                        }
                    }
                    .toolbarBackground(.hidden, for: .navigationBar)
            }
            .presentationBackground(.ultraThinMaterial)
        }
        .sheet(isPresented: $showAnalytics) {
            NavigationStack {
                AnalyticsView()
                    .navigationTitle("Analytics")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            Button("Close") { showAnalytics = false }
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
            HStack(spacing: 4) {
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
                Button { showSettings = true } label: {
                    Image(systemName: "gear").foregroundColor(.white)
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

    func loadUserRole() {
        Task {
            let user = try? await AuthAPI.shared.getMe()
            await MainActor.run { userRole = user?.role ?? "user" }
        }
    }
}
