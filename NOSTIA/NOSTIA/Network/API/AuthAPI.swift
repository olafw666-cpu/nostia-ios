import Foundation

final class AuthAPI {
    static let shared = AuthAPI()
    private let client = APIClient.shared
    private init() {}

    func login(username: String, password: String) async throws -> AuthResponse {
        let res: AuthResponse = try await client.request(
            "/auth/login",
            method: "POST",
            body: ["username": username, "password": password],
            requiresAuth: false
        )
        AuthManager.shared.saveToken(res.token)
        if let rt = res.refreshToken { AuthManager.shared.saveRefreshToken(rt) }
        return res
    }

    func register(
        username: String,
        password: String,
        name: String,
        email: String?,
        locationConsent: Bool,
        dataCollectionConsent: Bool,
        tosVersion: String
    ) async throws -> AuthResponse {
        var body: [String: Any] = [
            "username": username,
            "password": password,
            "name": name,
            "locationConsent": locationConsent,
            "dataCollectionConsent": dataCollectionConsent,
            "tosVersion": tosVersion
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

    // Exchange a refresh token for a new access + refresh token pair.
    // Saves both to Keychain and returns the new access token.
    func refreshAccessToken() async throws -> String {
        guard let refreshToken = AuthManager.shared.getRefreshToken() else {
            throw APIError.noToken
        }
        let res: TokenRefreshResponse = try await client.request(
            "/auth/refresh",
            method: "POST",
            body: ["refreshToken": refreshToken],
            requiresAuth: false
        )
        AuthManager.shared.saveToken(res.token)
        AuthManager.shared.saveRefreshToken(res.refreshToken)
        return res.token
    }

    func getMe() async throws -> User {
        return try await client.request("/users/me")
    }

    func updateMe(_ body: [String: Any]) async throws -> User {
        return try await client.request("/users/me", method: "PUT", body: body)
    }
}
