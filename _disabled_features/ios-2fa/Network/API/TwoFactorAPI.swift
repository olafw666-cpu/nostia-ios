import Foundation
import UIKit

/// Settings-side 2FA endpoints (enable flow, disable, device management).
/// The login-challenge + recovery endpoints live on AuthAPI since they manage tokens.
final class TwoFactorAPI {
    static let shared = TwoFactorAPI()
    private let client = APIClient.shared
    private init() {}

    func status() async throws -> TwoFactorStatus {
        try await client.request("/2fa/status")
    }

    // Step 2 — phone verification
    func startPhone(_ phone: String) async throws -> StartCodeResponse {
        try await client.request("/2fa/phone/start", method: "POST", body: ["phone": phone])
    }
    func verifyPhone(code: String) async throws {
        let _: GenericSuccess = try await client.request("/2fa/phone/verify", method: "POST", body: ["code": code])
    }

    // Step 3 — email verification (recovery path)
    func startEmail(_ email: String?) async throws -> StartCodeResponse {
        var body: [String: Any] = [:]
        if let email, !email.isEmpty { body["email"] = email }
        return try await client.request("/2fa/email/start", method: "POST", body: body)
    }
    func verifyEmail(code: String) async throws {
        let _: GenericSuccess = try await client.request("/2fa/email/verify", method: "POST", body: ["code": code])
    }

    // Step 4 — activate. Marks the current device recognized; persists its token.
    func enable() async throws {
        let res: EnableResponse = try await client.request(
            "/2fa/enable", method: "POST", body: ["deviceName": currentDeviceName()]
        )
        if let dt = res.deviceToken { AuthManager.shared.saveDeviceToken(dt) }
    }

    func disable(password: String) async throws {
        let _: GenericSuccess = try await client.request("/2fa/disable", method: "POST", body: ["password": password])
        AuthManager.shared.deleteDeviceToken()
    }

    func devices() async throws -> [RecognizedDevice] {
        let res: DevicesResponse = try await client.request("/2fa/devices")
        return res.devices
    }
    func forgetDevice(_ id: Int) async throws {
        try await client.requestVoid("/2fa/devices/\(id)", method: "DELETE")
    }
}

// MARK: - Models

struct TwoFactorStatus: Decodable {
    let twoFactorEnabled: Bool
    let phoneVerified: Bool
    let emailVerified: Bool
    let phoneHint: String?
    let emailHint: String?
}

struct StartCodeResponse: Decodable {
    let success: Bool
    let phoneHint: String?
    let emailHint: String?
    let devCode: String?    // dev fallback only
}

struct EnableResponse: Decodable {
    let success: Bool
    let twoFactorEnabled: Bool
    let deviceToken: String?
}

struct GenericSuccess: Decodable {
    let success: Bool?
}

struct RecognizedDevice: Decodable, Identifiable {
    let id: Int
    let deviceName: String?
    let lastSeenAt: String?
    let createdAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case deviceName = "device_name"
        case lastSeenAt
        case createdAt
    }
}

struct DevicesResponse: Decodable {
    let devices: [RecognizedDevice]
}
