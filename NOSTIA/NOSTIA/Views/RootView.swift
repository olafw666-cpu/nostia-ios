import SwiftUI

struct RootView: View {
    @EnvironmentObject var authManager: AuthManager
    @State private var showProfileBuilder = false

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
        .onReceive(NotificationCenter.default.publisher(for: .userDidLogin)) { _ in
            authManager.isAuthenticated = true
            if UserDefaults.standard.bool(forKey: "nostia_pending_profile_setup") {
                UserDefaults.standard.removeObject(forKey: "nostia_pending_profile_setup")
                showProfileBuilder = true
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .userDidLogout)) { _ in
            authManager.isAuthenticated = false
            showProfileBuilder = false
        }
    }
}

struct AuthNavigationView: View {
    var body: some View {
        NavigationStack {
            LoginView()
        }
    }
}
