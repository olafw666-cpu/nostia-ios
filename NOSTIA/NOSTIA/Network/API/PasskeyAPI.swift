import Foundation

// MARK: - Wire models

/// Subset of the WebAuthn registration options the client actually consumes;
/// the raw challenge/user handle are passed straight into AuthenticationServices.
struct PasskeyRegistrationOptions: Codable {
    struct User: Codable {
        let id: String   // base64url user handle
        let name: String
    }
    let challenge: String  // base64url
    let user: User
}

struct PasskeyAssertionOptions: Codable {
    struct AllowedCredential: Codable {
        let id: String  // base64url credential id
    }
    let challenge: String  // base64url
    let allowCredentials: [AllowedCredential]?
}

struct PasskeyStatus: Codable {
    struct Credential: Codable, Identifiable {
        let id: Int
        let deviceName: String?
        let createdAt: String?
        let lastUsedAt: String?
    }
    let enabled: Bool
    let credentials: [Credential]
}

struct PasskeyEnableResponse: Codable {
    let success: Bool
    let enabled: Bool
    let deviceToken: String?
}

/// Completion of a 2FA-challenged login (mirrors AuthResponse + the
/// remembered-device token issued when rememberDevice was requested).
struct TwoFactorLoginResponse: Codable {
    let token: String
    let refreshToken: String?
    let user: User
    let deviceToken: String?
}

struct PasskeyRecoveryOptionsResponse: Codable {
    let assertionOptions: PasskeyAssertionOptions
}

struct PasskeySimpleResponse: Codable {
    let success: Bool
    let message: String?
}

// MARK: - API

actor PasskeyAPI {
    static let shared = PasskeyAPI()
    private let client = APIClient.shared
    private init() {}

    func status() async throws -> PasskeyStatus {
        try await client.request("/passkey/status")
    }

    func registrationOptions() async throws -> PasskeyRegistrationOptions {
        try await client.request("/passkey/register/options", method: "POST", body: [:])
    }

    /// Verifies the attestation server-side; on success passkey 2FA is enabled and
    /// this device is remembered (token stored so this device skips future challenges).
    func verifyRegistration(response: [String: Any], deviceName: String) async throws -> PasskeyEnableResponse {
        let res: PasskeyEnableResponse = try await client.request(
            "/passkey/register/verify",
            method: "POST",
            body: ["response": response, "deviceName": deviceName]
        )
        if let deviceToken = res.deviceToken {
            AuthManager.shared.saveRecognizedDeviceToken(deviceToken)
        }
        return res
    }

    func disable(password: String) async throws {
        let _: PasskeySimpleResponse = try await client.request(
            "/passkey/disable",
            method: "POST",
            body: ["password": password]
        )
    }

    /// Completes a passkey-challenged login. Persists the session and the
    /// remembered-device token on success.
    func verifyLogin(challengeToken: String, response: [String: Any], deviceName: String) async throws -> TwoFactorLoginResponse {
        let res: TwoFactorLoginResponse = try await client.request(
            "/passkey/login/verify",
            method: "POST",
            body: [
                "challengeToken": challengeToken,
                "response": response,
                "rememberDevice": true,
                "deviceName": deviceName,
            ],
            requiresAuth: false
        )
        if let deviceToken = res.deviceToken {
            AuthManager.shared.saveRecognizedDeviceToken(deviceToken)
        }
        AuthManager.shared.saveToken(res.token)
        if let rt = res.refreshToken { AuthManager.shared.saveRefreshToken(rt) }
        return res
    }

    /// Usernameless recovery: no identifier is sent; the passkey the user picks
    /// identifies the account.
    func recoveryOptions() async throws -> PasskeyAssertionOptions {
        let res: PasskeyRecoveryOptionsResponse = try await client.request(
            "/auth/recovery/passkey/options",
            method: "POST",
            body: [:],
            requiresAuth: false
        )
        return res.assertionOptions
    }

    func resetPassword(response: [String: Any], newPassword: String) async throws {
        let _: PasskeySimpleResponse = try await client.request(
            "/auth/recovery/passkey/reset",
            method: "POST",
            body: ["response": response, "newPassword": newPassword],
            requiresAuth: false
        )
    }
}
