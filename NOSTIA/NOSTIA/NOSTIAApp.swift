import StripePaymentSheet
import SwiftUI

@main
struct NOSTIAApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var authManager = AuthManager.shared

    init() {
        // Without this every PaymentSheet call (save card, pay vault split) fails —
        // the Stripe SDK has no key to talk to the API with.
        STPAPIClient.shared.publishableKey = AppConfig.stripePublishableKey
    }
    @StateObject private var locationManager = LocationManager.shared
    @StateObject private var responsive = ResponsiveLayoutManager.shared
    @StateObject private var deepLinkRouter = DeepLinkRouter.shared
    @StateObject private var themeManager = ThemeManager.shared

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(authManager)
                .environmentObject(locationManager)
                .environmentObject(responsive)
                .environmentObject(deepLinkRouter)
                .environmentObject(themeManager)
                // App type scales with Dynamic Type (via the nostiaDisplay/nostiaBody
                // helpers), capped at the first accessibility size — beyond that the
                // fixed-frame chrome (tab bar, avatars, stat cards) stops fitting.
                .dynamicTypeSize(...DynamicTypeSize.accessibility1)
        }
    }
}
