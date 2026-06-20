import Foundation

actor AuthAPI {
    static let shared = AuthAPI()
    private let client = APIClient.shared
    private init() {}

    private var ongoingRefresh: Task<String, Error>?

    /// Log in. If the account has 2FA enabled and this device is unrecognized, the
    /// server returns a challenge instead of tokens (Section 2.3).
    func login(username: String, password: String) async throws -> LoginOutcome {
        var body: [String: Any] = ["username": username, "password": password]
        if let dt = AuthManager.shared.getDeviceToken() { body["deviceToken"] = dt }

        let res: LoginFlexResponse = try await client.request(
            "/auth/login",
            method: "POST",
            body: body,
            requiresAuth: false
        )

        if res.twoFactorRequired == true, let challengeToken = res.challengeToken {
            return .twoFactorRequired(LoginChallenge(
                challengeToken: challengeToken,
                channel: res.channel ?? "sms",
                destinationHint: res.destinationHint,
                emailFallbackAvailable: res.emailFallbackAvailable ?? false,
                devCode: res.devCode
            ))
        }

        guard let token = res.token, let user = res.user else {
            throw APIError.decodingError("Malformed login response")
        }
        AuthManager.shared.saveToken(token)
        if let rt = res.refreshToken { AuthManager.shared.saveRefreshToken(rt) }
        return .authenticated(AuthResponse(token: token, refreshToken: res.refreshToken, user: user))
    }

    /// Complete a 2FA login challenge with the 6-digit code. `deviceName` is computed by
    /// the (MainActor) caller so this actor never touches UIKit.
    func verifyLoginCode(challengeToken: String, code: String, rememberDevice: Bool, deviceName: String?) async throws {
        var body: [String: Any] = [
            "challengeToken": challengeToken,
            "code": code,
            "rememberDevice": rememberDevice
        ]
        if rememberDevice, let deviceName { body["deviceName"] = deviceName }
        let res: LoginVerifyResponse = try await client.request(
            "/2fa/login/verify", method: "POST", body: body, requiresAuth: false
        )
        AuthManager.shared.saveToken(res.token)
        if let rt = res.refreshToken { AuthManager.shared.saveRefreshToken(rt) }
        if let dt = res.deviceToken { AuthManager.shared.saveDeviceToken(dt) }
    }

    /// Resend the login code, optionally via the email fallback (Section 2.3).
    func resendLoginCode(challengeToken: String, channel: String) async throws -> ResendResponse {
        return try await client.request(
            "/2fa/login/resend", method: "POST",
            body: ["challengeToken": challengeToken, "channel": channel],
            requiresAuth: false
        )
    }

    // MARK: - Account recovery (Section 2.4)

    func forgotPassword(identifier: String, channel: String?) async throws -> ForgotPasswordResponse {
        var body: [String: Any] = ["identifier": identifier]
        if let channel { body["channel"] = channel }
        return try await client.request(
            "/auth/forgot-password", method: "POST", body: body, requiresAuth: false
        )
    }

    func resetPassword(challengeToken: String, code: String, newPassword: String) async throws {
        let _: ResetPasswordResponse = try await client.request(
            "/auth/reset-password", method: "POST",
            body: ["challengeToken": challengeToken, "code": code, "newPassword": newPassword],
            requiresAuth: false
        )
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

// MARK: - Login outcome + 2FA response models

enum LoginOutcome {
    case authenticated(AuthResponse)
    case twoFactorRequired(LoginChallenge)
}

struct LoginChallenge {
    let challengeToken: String
    let channel: String            // "sms" | "email"
    let destinationHint: String?
    let emailFallbackAvailable: Bool
    let devCode: String?           // populated only in dev fallback (no live SMS provider)
}

/// Flexible decode of /auth/login — the response is either tokens or a 2FA challenge.
struct LoginFlexResponse: Decodable {
    let token: String?
    let refreshToken: String?
    let user: User?
    let twoFactorRequired: Bool?
    let challengeToken: String?
    let channel: String?
    let destinationHint: String?
    let emailFallbackAvailable: Bool?
    let devCode: String?
}

struct LoginVerifyResponse: Decodable {
    let token: String
    let refreshToken: String?
    let user: User
    let deviceToken: String?
}

struct ResendResponse: Decodable {
    let success: Bool
    let channel: String?
    let destinationHint: String?
    let devCode: String?
}

struct ForgotPasswordResponse: Decodable {
    let message: String?
    let challengeToken: String?
    let channel: String?
    let destinationHint: String?
    let devCode: String?
}

struct ResetPasswordResponse: Decodable {
    let success: Bool?
    let message: String?
}
