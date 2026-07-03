import Combine
import Foundation
import SafariServices
import StripePaymentSheet
import UIKit

@MainActor
final class PaymentsViewModel: ObservableObject {
    @Published var paymentMethods: [PaymentMethod] = []
    @Published var onboardingStatus: OnboardingStatus?
    @Published var isLoading = false
    @Published var isOnboarding = false
    @Published var errorMessage: String?

    func load() async {
        isLoading = true
        errorMessage = nil
        async let methods = PaymentsAPI.shared.getPaymentMethods()
        async let status = PaymentsAPI.shared.getOnboardingStatus()
        paymentMethods = (try? await methods) ?? []
        onboardingStatus = try? await status
        isLoading = false
    }

    func removeMethod(id: String) async {
        do {
            try await PaymentsAPI.shared.removePaymentMethod(id: id)
            paymentMethods.removeAll { $0.id == id }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func setDefault(id: String) async {
        do {
            try await PaymentsAPI.shared.setDefaultPaymentMethod(id: id)
            await load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// The in-app browser hosting Stripe onboarding, kept so polling can close it on success.
    private weak var onboardingSafariVC: SFSafariViewController?

    private func topViewController() -> UIViewController? {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootVC = scene.keyWindow?.rootViewController else { return nil }
        var topVC = rootVC
        while let presented = topVC.presentedViewController {
            topVC = presented
        }
        return topVC
    }

    func startOnboarding() async {
        guard !isOnboarding else { return }
        isOnboarding = true
        defer { isOnboarding = false }
        do {
            let urlString = try await PaymentsAPI.shared.startOnboarding()
            guard let url = URL(string: urlString),
                  url.scheme == "https",
                  url.host?.hasSuffix("stripe.com") == true else { return }
            // In-app browser, NOT external Safari: the hosted flow links out to Stripe's
            // legal agreements, and in external Safari that strands users on stripe.com
            // with no visible way back to the app. SFSafariViewController always shows
            // Done, and back returns from the agreement to the onboarding form.
            if let presenter = topViewController() {
                let safari = SFSafariViewController(url: url)
                safari.dismissButtonStyle = .done
                presenter.present(safari, animated: true)
                onboardingSafariVC = safari
            } else {
                await UIApplication.shared.open(url)
            }
            // Poll for onboarding completion so user doesn't have to pull-to-refresh manually
            Task { @MainActor [weak self] in
                await self?.pollOnboardingStatus()
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func pollOnboardingStatus() async {
        let interval: UInt64 = 20_000_000_000 // 20 seconds
        let maxAttempts = 30                   // 10 minutes — Stripe KYC form typically takes 3–5+ min
        for _ in 0..<maxAttempts {
            try? await Task.sleep(nanoseconds: interval)
            guard let status = try? await PaymentsAPI.shared.getOnboardingStatus() else { continue }
            onboardingStatus = status
            if status.complete {
                // Close the Stripe browser sheet if it's still up — the user is done.
                onboardingSafariVC?.dismiss(animated: true)
                onboardingSafariVC = nil
                return
            }
        }
    }

    func startAddCard() async {
        isLoading = true
        errorMessage = nil
        do {
            let intent = try await PaymentsAPI.shared.createSetupIntent()
            var config = PaymentSheet.Configuration()
            config.merchantDisplayName = "Nostia"
            config.customer = PaymentSheet.CustomerConfiguration(
                id: intent.customerId,
                ephemeralKeySecret: intent.ephemeralKey
            )
            let sheet = PaymentSheet(setupIntentClientSecret: intent.clientSecret, configuration: config)
            isLoading = false

            guard let topVC = topViewController() else {
                errorMessage = "Unable to present payment sheet."
                return
            }
            sheet.present(from: topVC) { [weak self] result in
                Task { @MainActor [weak self] in
                    await self?.handleAddCardResult(result)
                }
            }
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }

    func handleAddCardResult(_ result: PaymentSheetResult) async {
        switch result {
        case .completed:
            await load()
        case .canceled:
            break
        case .failed(let error):
            errorMessage = error.localizedDescription
        }
    }
}
