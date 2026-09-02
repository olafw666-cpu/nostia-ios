import Foundation

nonisolated enum AppConfig {
    static let apiBaseURL = "https://api.nostia.io/api"
    static let termsOfServiceURL = "https://nostia.io/terms"
    /// Public landing page for shared experience invites (`<base>/<eventId>`). Served by the
    /// backend; deep-links back into the app via nostia://event/<id> — Messages won't linkify
    /// a bare custom-scheme URL, so shared invites must carry an https link.
    static let experienceInviteBaseURL = "https://api.nostia.io/e"

    /// Runs the app entirely against an on-device fixture backend: `APIClient` never
    /// opens a socket, and `DemoBackend` answers every request from `DemoStore`.
    /// Set to `false` to point the app back at `apiBaseURL` — nothing else changes,
    /// because the switch lives at the single seam every API service already funnels
    /// through. Everything that is not the Nostia backend (Apple map tiles, MapKit
    /// place search, Sign in with Apple) is untouched either way.
    static let isDemoMode = true
}
