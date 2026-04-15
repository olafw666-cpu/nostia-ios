import Combine
import Foundation
import Security

final class AuthManager: ObservableObject {
    static let shared = AuthManager()

    @Published var isAuthenticated = false
    @Published var currentUserId: Int?

    private let tokenKey = "nostia_jwt_token"

    private init() {
        isAuthenticated = getToken() != nil
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
        if let token = getToken() {
            Task {
                _ = try? await URLSession.shared.data(for: {
                    var req = URLRequest(url: URL(string: AppConfig.apiBaseURL + "/auth/logout")!)
                    req.httpMethod = "POST"
                    req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                    req.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    return req
                }())
            }
        }
        deleteToken()
        NotificationCenter.default.post(name: .userDidLogout, object: nil)
    }
}

extension Notification.Name {
    static let userDidLogout = Notification.Name("userDidLogout")
    static let userDidLogin = Notification.Name("userDidLogin")
}
