import SwiftUI
import StripePaymentSheet

@main
struct NostiaApp: App {
    @StateObject private var authManager = AuthManager.shared
    @StateObject private var locationManager = LocationManager.shared

    init() {
        StripeAPI.defaultPublishableKey = AppConfig.stripePublishableKey
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(authManager)
                .environmentObject(locationManager)
                .preferredColorScheme(.dark)
        }
    }
}
