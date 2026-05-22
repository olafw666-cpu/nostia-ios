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

    func startOnboarding() async {
        do {
            let urlString = try await PaymentsAPI.shared.startOnboarding()
            guard let url = URL(string: urlString),
                  url.scheme == "https",
                  url.host?.hasSuffix("stripe.com") == true else { return }
            guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                  let rootVC = scene.keyWindow?.rootViewController else { return }
            var topVC = rootVC
            while let presented = topVC.presentedViewController { topVC = presented }
            let safari = SFSafariViewController(url: url)
            topVC.present(safari, animated: true)
        } catch {
            errorMessage = error.localizedDescription
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

            guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                  let rootVC = scene.keyWindow?.rootViewController else {
                errorMessage = "Unable to present payment sheet."
                return
            }
            var topVC = rootVC
            while let presented = topVC.presentedViewController {
                topVC = presented
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
