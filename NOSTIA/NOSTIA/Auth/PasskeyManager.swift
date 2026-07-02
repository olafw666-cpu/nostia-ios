import AuthenticationServices
import UIKit

/// Drives the native Face ID passkey sheets (AuthenticationServices) and shapes
/// the results as WebAuthn JSON for the backend's verifier. The relying party is
/// the API domain itself — iOS validates it against the apple-app-site-association
/// file the backend serves, so no third-party infrastructure is involved.
final class PasskeyManager: NSObject {
    static let shared = PasskeyManager()
    static let relyingPartyID = "api.nostia.io"

    enum PasskeyError: LocalizedError {
        case canceled
        case malformedChallenge
        case unexpectedCredential
        var errorDescription: String? {
            switch self {
            case .canceled: return "Face ID was canceled."
            case .malformedChallenge: return "The server sent an invalid security challenge. Please try again."
            case .unexpectedCredential: return "This device returned an unsupported credential type."
            }
        }
    }

    private var continuation: CheckedContinuation<ASAuthorization, Error>?
    private var activeController: ASAuthorizationController?

    private override init() { super.init() }

    // MARK: - Registration (create a passkey with Face ID)

    func register(options: PasskeyRegistrationOptions) async throws -> [String: Any] {
        guard let challenge = Data(base64urlEncoded: options.challenge),
              let userID = Data(base64urlEncoded: options.user.id) else {
            throw PasskeyError.malformedChallenge
        }
        let provider = ASAuthorizationPlatformPublicKeyCredentialProvider(relyingPartyIdentifier: Self.relyingPartyID)
        let request = provider.createCredentialRegistrationRequest(
            challenge: challenge,
            name: options.user.name,
            userID: userID
        )
        request.userVerificationPreference = .required

        let authorization = try await perform(request)
        guard let credential = authorization.credential as? ASAuthorizationPlatformPublicKeyCredentialRegistration,
              let attestation = credential.rawAttestationObject else {
            throw PasskeyError.unexpectedCredential
        }
        return [
            "id": credential.credentialID.base64urlEncodedString(),
            "rawId": credential.credentialID.base64urlEncodedString(),
            "type": "public-key",
            "response": [
                "clientDataJSON": credential.rawClientDataJSON.base64urlEncodedString(),
                "attestationObject": attestation.base64urlEncodedString(),
                "transports": ["internal"],
            ] as [String: Any],
            "clientExtensionResults": [:] as [String: Any],
        ]
    }

    // MARK: - Assertion (prove ownership with Face ID)

    /// Empty/absent allowCredentials → usernameless flow: iOS lists every Nostia
    /// passkey on this device and the chosen one identifies the account (recovery).
    func assert(options: PasskeyAssertionOptions) async throws -> [String: Any] {
        guard let challenge = Data(base64urlEncoded: options.challenge) else {
            throw PasskeyError.malformedChallenge
        }
        let provider = ASAuthorizationPlatformPublicKeyCredentialProvider(relyingPartyIdentifier: Self.relyingPartyID)
        let request = provider.createCredentialAssertionRequest(challenge: challenge)
        request.userVerificationPreference = .required
        let allowed = (options.allowCredentials ?? []).compactMap { cred in
            Data(base64urlEncoded: cred.id).map(ASAuthorizationPlatformPublicKeyCredentialDescriptor.init(credentialID:))
        }
        if !allowed.isEmpty { request.allowedCredentials = allowed }

        let authorization = try await perform(request)
        guard let credential = authorization.credential as? ASAuthorizationPlatformPublicKeyCredentialAssertion else {
            throw PasskeyError.unexpectedCredential
        }
        var response: [String: Any] = [
            "clientDataJSON": credential.rawClientDataJSON.base64urlEncodedString(),
            "authenticatorData": credential.rawAuthenticatorData.base64urlEncodedString(),
            "signature": credential.signature.base64urlEncodedString(),
        ]
        // Typed as Data? locally: the SDK's optionality for userID has varied.
        let handle: Data? = credential.userID
        if let handle, !handle.isEmpty {
            response["userHandle"] = handle.base64urlEncodedString()
        }
        return [
            "id": credential.credentialID.base64urlEncodedString(),
            "rawId": credential.credentialID.base64urlEncodedString(),
            "type": "public-key",
            "response": response,
            "clientExtensionResults": [:] as [String: Any],
        ]
    }

    // MARK: - ASAuthorizationController plumbing

    private func perform(_ request: ASAuthorizationRequest) async throws -> ASAuthorization {
        // One flow at a time; a dangling continuation would leak the caller.
        if let pending = continuation {
            continuation = nil
            pending.resume(throwing: PasskeyError.canceled)
        }
        return try await withCheckedThrowingContinuation { cont in
            continuation = cont
            let controller = ASAuthorizationController(authorizationRequests: [request])
            controller.delegate = self
            controller.presentationContextProvider = self
            activeController = controller
            controller.performRequests()
        }
    }

    private func finish(_ result: Result<ASAuthorization, Error>) {
        activeController = nil
        guard let cont = continuation else { return }
        continuation = nil
        cont.resume(with: result)
    }
}

extension PasskeyManager: ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
    // nonisolated: the system may invoke these off the main actor for passkey flows.

    nonisolated func authorizationController(controller: ASAuthorizationController,
                                             didCompleteWithAuthorization authorization: ASAuthorization) {
        Task { @MainActor in self.finish(.success(authorization)) }
    }

    nonisolated func authorizationController(controller: ASAuthorizationController,
                                             didCompleteWithError error: Error) {
        let mapped: Error = (error as? ASAuthorizationError)?.code == .canceled ? PasskeyError.canceled : error
        Task { @MainActor in self.finish(.failure(mapped)) }
    }

    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow } ?? ASPresentationAnchor()
    }
}

// MARK: - base64url <-> Data

extension Data {
    init?(base64urlEncoded string: String) {
        var base64 = string
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let remainder = base64.count % 4
        if remainder != 0 { base64 += String(repeating: "=", count: 4 - remainder) }
        self.init(base64Encoded: base64)
    }

    func base64urlEncodedString() -> String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
