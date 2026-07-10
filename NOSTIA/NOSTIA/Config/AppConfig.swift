import Foundation

enum AppConfig {
    static let apiBaseURL = "https://api.nostia.io/api"
    static let termsOfServiceURL = "https://nostia.io/terms"
    // TODO: Replace PLACEHOLDER_IOS_BUNDLE_ID with your Apple bundle ID (e.g. com.nostia.app)
    // See README.md for setup instructions
    static let stripePublishableKey = "pk_live_51T6Exx5toh1l5jhOUtBcd3Zjty9PDmxWezXgBdiz6T9mJC580Zsg887N6E35GT5mbHxcuCe1VeWGvqtI0sy5zqcL00rkWNRPNR"
    // Apple Pay Merchant ID — must match the Merchant ID registered in the Apple
    // Developer portal AND the entitlement in NOSTIA.entitlements exactly.
    static let stripeMerchantIdentifier = "merchant.io.nostia"
}
