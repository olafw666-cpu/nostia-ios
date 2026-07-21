import Foundation

enum AppConfig {
    static let apiBaseURL = "https://api.nostia.io/api"
    static let termsOfServiceURL = "https://nostia.io/terms"
    /// Public landing page for shared experience invites (`<base>/<eventId>`). Served by the
    /// backend; deep-links back into the app via nostia://event/<id> — Messages won't linkify
    /// a bare custom-scheme URL, so shared invites must carry an https link.
    static let experienceInviteBaseURL = "https://api.nostia.io/e"
    // TODO: Replace PLACEHOLDER_IOS_BUNDLE_ID with your Apple bundle ID (e.g. com.nostia.app)
    // See README.md for setup instructions
    static let stripePublishableKey = "pk_live_51T6Exx5toh1l5jhOUtBcd3Zjty9PDmxWezXgBdiz6T9mJC580Zsg887N6E35GT5mbHxcuCe1VeWGvqtI0sy5zqcL00rkWNRPNR"
}
