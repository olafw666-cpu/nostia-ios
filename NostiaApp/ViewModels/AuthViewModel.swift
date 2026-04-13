import Foundation

@MainActor
final class AuthViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var errorMessage: String?

    func login(username: String, password: String) async -> Bool {
        guard !username.trimmingCharacters(in: .whitespaces).isEmpty, !password.isEmpty else {
            errorMessage = "Please enter your username and password"
            return false
        }
        isLoading = true
        errorMessage = nil
        do {
            _ = try await AuthAPI.shared.login(username: username.trimmingCharacters(in: .whitespaces), password: password)
            NotificationCenter.default.post(name: .userDidLogin, object: nil)
            isLoading = false
            return true
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
        dataCollectionConsent: Bool
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
                dataCollectionConsent: dataCollectionConsent
            )
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
