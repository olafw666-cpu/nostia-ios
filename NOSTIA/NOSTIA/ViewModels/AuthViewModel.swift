import Combine
import Foundation
import UIKit

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
            let outcome = try await AuthAPI.shared.login(username: username.trimmingCharacters(in: .whitespaces), password: password)
            switch outcome {
            case .authenticated:
                break
            case .passkeyRequired(let challengeToken, let options):
                // New device on a Face ID-secured account: the system passkey
                // sheet appears right after the password is accepted.
                let assertion = try await PasskeyManager.shared.assert(options: options)
                _ = try await PasskeyAPI.shared.verifyLogin(
                    challengeToken: challengeToken,
                    response: assertion,
                    deviceName: UIDevice.current.name
                )
            }
            NotificationCenter.default.post(name: .userDidLogin, object: nil)
            isLoading = false
            return true
        } catch PasskeyManager.PasskeyError.canceled {
            errorMessage = "This account is protected with Face ID. Confirm with Face ID to finish signing in."
            isLoading = false
            return false
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
