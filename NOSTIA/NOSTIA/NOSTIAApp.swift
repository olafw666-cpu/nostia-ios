import SwiftUI

@main
struct NOSTIAApp: App {
    @StateObject private var authManager = AuthManager.shared
    @StateObject private var locationManager = LocationManager.shared
    @StateObject private var responsive = ResponsiveLayoutManager.shared

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(authManager)
                .environmentObject(locationManager)
                .environmentObject(responsive)
        }
    }
}
