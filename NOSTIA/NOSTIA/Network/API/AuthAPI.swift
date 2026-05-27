import Foundation

actor AuthAPI {
    static let shared = AuthAPI()
    private let client = APIClient.shared
    private init() {}

    private var ongoingRefresh: Task<String, Error>?

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
