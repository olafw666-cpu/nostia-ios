import Foundation

/// Either a completed login or a passkey (Face ID) 2FA challenge that the client
/// must satisfy via PasskeyAPI.verifyLogin before a session exists.
enum LoginOutcome {
    case authenticated(AuthResponse)
    case passkeyRequired(challengeToken: String, options: PasskeyAssertionOptions)
}

actor AuthAPI {
    static let shared = AuthAPI()
    private let client = APIClient.shared
    private init() {}

    private var ongoingRefresh: Task<String, Error>?

    func login(username: String, password: String) async throws -> LoginOutcome {
        // Superset of AuthResponse: the same endpoint answers with a 2FA challenge
        // when the account has passkey 2FA and this device is unrecognized.
        struct LoginResponse: Codable {
            let token: String?
            let refreshToken: String?
            let user: User?
            let twoFactorRequired: Bool?
            let challengeToken: String?
            let assertionOptions: PasskeyAssertionOptions?
        }

        var body: [String: Any] = ["username": username, "password": password]
        if let deviceToken = AuthManager.shared.getRecognizedDeviceToken() {
            body["deviceToken"] = deviceToken
        }
        let res: LoginResponse = try await client.request(
            "/auth/login",
            method: "POST",
            body: body,
            requiresAuth: false
        )

        if res.twoFactorRequired == true {
            guard let challengeToken = res.challengeToken, let options = res.assertionOptions else {
                throw APIError.decodingError("Two-factor challenge was missing its assertion options")
            }
            return .passkeyRequired(challengeToken: challengeToken, options: options)
        }
        guard let token = res.token, let user = res.user else {
            throw APIError.decodingError("Login response was missing the session token")
        }
        AuthManager.shared.saveToken(token)
        if let rt = res.refreshToken { AuthManager.shared.saveRefreshToken(rt) }
        return .authenticated(AuthResponse(token: token, refreshToken: res.refreshToken, user: user))
    }

    func register(
        username: String,
        password: String,
        name: String,
        email: String?,
        locationConsent: Bool,
        dataCollectionConsent: Bool,
        tosVersion: String,
        dataNotSold: Bool = false
    ) async throws -> AuthResponse {
        var body: [String: Any] = [
            "username": username,
            "password": password,
            "name": name,
            "locationConsent": locationConsent,
            "dataCollectionConsent": dataCollectionConsent,
            "tosVersion": tosVersion,
            "dataNotSold": dataNotSold
        ]
        if let email, !email.isEmpty { body["email"] = email }
        let res: AuthResponse = try await client.request(
            "/auth/register",
            method: "POST",
            body: body,
            requiresAuth: false
        )
        AuthManager.shared.saveToken(res.token)
        if let rt = res.refreshToken { AuthManager.shared.saveRefreshToken(rt) }
        return res
    }

    /// Sign in with Apple (v2 §4.1: minimal auth). The server verifies the
    /// identity token against Apple's JWKS and finds-or-creates the account by
    /// its stable `sub`. `created` = brand-new account (queue first-run setup).
    func appleLogin(identityToken: String, name: String?) async throws -> (response: AuthResponse, created: Bool) {
        struct AppleLoginResponse: Codable {
            let token: String
            let refreshToken: String?
            let user: User
            let created: Bool?
        }
        var body: [String: Any] = ["identity_token": identityToken]
        if let name, !name.isEmpty { body["name"] = name }
        let res: AppleLoginResponse = try await client.request(
            "/auth/apple",
            method: "POST",
            body: body,
            requiresAuth: false
        )
        AuthManager.shared.saveToken(res.token)
        if let rt = res.refreshToken { AuthManager.shared.saveRefreshToken(rt) }
        return (AuthResponse(token: res.token, refreshToken: res.refreshToken, user: res.user), res.created ?? false)
    }

    // Exchange a refresh token for a new access + refresh token pair.
    // Deduplicates concurrent calls — if a refresh is already in flight, all callers
    // await the same Task so token rotation only happens once.
    func refreshAccessToken() async throws -> String {
        if let existing = ongoingRefresh {
            return try await existing.value
        }
        let task = Task<String, Error> {
            guard let rt = AuthManager.shared.getRefreshToken() else { throw APIError.noToken }
            let res: TokenRefreshResponse = try await APIClient.shared.request(
                "/auth/refresh",
                method: "POST",
                body: ["refreshToken": rt],
                requiresAuth: false
            )
            AuthManager.shared.saveToken(res.token)
            AuthManager.shared.saveRefreshToken(res.refreshToken)
            return res.token
        }
        ongoingRefresh = task
        do {
            let token = try await task.value
            ongoingRefresh = nil
            return token
        } catch {
            ongoingRefresh = nil
            throw error
        }
    }

    func getMe() async throws -> User {
        return try await client.request("/users/me")
    }

    func updateMe(_ body: [String: Any]) async throws -> User {
        return try await client.request("/users/me", method: "PUT", body: body)
    }
}
