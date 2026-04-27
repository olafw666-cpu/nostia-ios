import Combine
import Foundation
import Security

final class AuthManager: ObservableObject {
    static let shared = AuthManager()

    @Published var isAuthenticated = false
    @Published var currentUserId: Int?

    private let tokenKey = "nostia_jwt_token"

    private init() {
        if let token = getToken() {
            isAuthenticated = true
            currentUserId = userIdFromToken(token)
        }
    }

    // MARK: - Token Storage (Keychain)

    func saveToken(_ token: String) {
        let data = Data(token.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: tokenKey,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        SecItemDelete(query as CFDictionary)
        SecItemAdd(query as CFDictionary, nil)

        DispatchQueue.main.async {
            self.isAuthenticated = true
            self.currentUserId = self.userIdFromToken(token)
        }
    }

    func getToken() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: tokenKey,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    func deleteToken() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: tokenKey
        ]
        SecItemDelete(query as CFDictionary)

        DispatchQueue.main.async {
            self.isAuthenticated = false
            self.currentUserId = nil
        }
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
