import Combine
import Foundation
import StripePaymentSheet

@MainActor
final class PaymentsViewModel: ObservableObject {
    @Published var paymentMethods: [PaymentMethod] = []
    @Published var onboardingStatus: OnboardingStatus?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var onboardingURL: URL?
    @Published var showOnboarding = false
    @Published var addCardSheet: PaymentSheet?
    @Published var showAddCard = false

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
            if let url = URL(string: urlString) {
                onboardingURL = url
                showOnboarding = true
            }
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
            addCardSheet = PaymentSheet(setupIntentClientSecret: intent.clientSecret, configuration: config)
            showAddCard = true
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func handleAddCardResult(_ result: PaymentSheetResult) async {
        showAddCard = false
        switch result {
        case .completed:
            // Payment method is now attached to the Stripe customer on Stripe's side.
            // Reload so the server can reflect the saved card.
            await load()
        case .canceled:
            break
        case .failed(let error):
            errorMessage = error.localizedDescription
        }
        addCardSheet = nil
    }
}
