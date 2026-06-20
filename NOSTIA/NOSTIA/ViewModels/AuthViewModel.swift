import Combine
import Foundation

@MainActor
final class AuthViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var errorMessage: String?
    /// Set when the server requires a 2FA code to finish login (Section 2.3).
    @Published var pendingChallenge: LoginChallenge?

    func login(username: String, password: String) async -> Bool {
        guard !username.trimmingCharacters(in: .whitespaces).isEmpty, !password.isEmpty else {
            errorMessage = "Please enter your username and password"
            return false
        }
        isLoading = true
        errorMessage = nil
        do {
            let outcome = try await AuthAPI.shared.login(
                username: username.trimmingCharacters(in: .whitespaces), password: password
            )
            isLoading = false
            switch outcome {
            case .authenticated:
                NotificationCenter.default.post(name: .userDidLogin, object: nil)
                return true
            case .twoFactorRequired(let challenge):
                pendingChallenge = challenge   // LoginView presents the code-entry screen
                return false
            }
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
            return false
        }
    }

    func register(
        username: String,
        password: String,
        name: String,
        email: String,
        locationConsent: Bool,
        dataCollectionConsent: Bool,
        tosVersion: String,
        dataNotSold: Bool = false
    ) async -> Bool {
        isLoading = true
        errorMessage = nil
        do {
            _ = try await AuthAPI.shared.register(
                username: username.trimmingCharacters(in: .whitespaces),
                password: password,
                name: name.trimmingCharacters(in: .whitespaces),
                email: email.isEmpty ? nil : email,
                locationConsent: locationConsent,
                dataCollectionConsent: dataCollectionConsent,
                tosVersion: tosVersion,
                dataNotSold: dataNotSold
            )
            UserDefaults.standard.set(true, forKey: "nostia_pending_profile_setup")
            NotificationCenter.default.post(name: .userDidLogin, object: nil)
            isLoading = false
            return true
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
            return false
        }
    }
}
