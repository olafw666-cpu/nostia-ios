import Combine
import Foundation
import Security

final class AuthManager: ObservableObject {
    static let shared = AuthManager()

    @Published var isAuthenticated = false
    @Published var currentUserId: Int?
    @Published var isDev: Bool = false

    private let tokenKey = "nostia_jwt_token"
    private let refreshTokenKey = "nostia_refresh_token"
    private let recognizedDeviceTokenKey = "nostia_2fa_device_token"

    private init() {
        if let token = getToken() {
            isAuthenticated = true
            currentUserId = userIdFromToken(token)
        }
    }

    // MARK: - Token Storage (Keychain)

    func saveToken(_ token: String) {
        keychainWrite(key: tokenKey, value: token)
        DispatchQueue.main.async {
            self.isAuthenticated = true
            self.currentUserId = self.userIdFromToken(token)
        }
    }

    func getToken() -> String? {
        keychainRead(key: tokenKey)
    }

    func saveRefreshToken(_ token: String) {
        keychainWrite(key: refreshTokenKey, value: token)
    }

    func getRefreshToken() -> String? {
        keychainRead(key: refreshTokenKey)
    }

    // Recognized-device token (2FA "remember this device"). Survives logout on
    // purpose — the device stays recognized so the next login skips the Face ID
    // challenge; it is only cleared server-side (disable 2FA / forget device).
    func saveRecognizedDeviceToken(_ token: String) {
        keychainWrite(key: recognizedDeviceTokenKey, value: token)
    }

    func getRecognizedDeviceToken() -> String? {
        keychainRead(key: recognizedDeviceTokenKey)
    }

    func deleteToken() {
        keychainDelete(key: tokenKey)
        keychainDelete(key: refreshTokenKey)
        DispatchQueue.main.async {
            self.isAuthenticated = false
            self.currentUserId = nil
            self.isDev = false
        }
    }

    // MARK: - Keychain helpers

    private func keychainWrite(key: String, value: String) {
        let data = Data(value.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        SecItemDelete(query as CFDictionary)
        SecItemAdd(query as CFDictionary, nil)
    }

    private func keychainRead(key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private func keychainDelete(key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]
        SecItemDelete(query as CFDictionary)
    }

    func logout() {
        // Revoke token server-side (fire-and-forget) before deleting locally
        if let token = getToken(), let url = URL(string: AppConfig.apiBaseURL + "/auth/logout") {
            Task {
                var req = URLRequest(url: url)
                req.httpMethod = "POST"
                req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                req.setValue("application/json", forHTTPHeaderField: "Content-Type")
                _ = try? await URLSession.shared.data(for: req)
            }
        }
        Task { await CacheManager.shared.clearAll() }
        deleteToken()
        NotificationCenter.default.post(name: .userDidLogout, object: nil)
    }

    // MARK: - JWT decode (extract user id without a library)

    private func userIdFromToken(_ token: String) -> Int? {
        let parts = token.split(separator: ".")
        guard parts.count == 3 else { return nil }
        var base64 = String(parts[1])
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let remainder = base64.count % 4
        if remainder != 0 { base64 += String(repeating: "=", count: 4 - remainder) }
        guard let data = Data(base64Encoded: base64),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let id = json["id"] as? Int else { return nil }
        return id
    }
}

extension Notification.Name {
    static let userDidLogout = Notification.Name("userDidLogout")
    static let userDidLogin = Notification.Name("userDidLogin")
}
