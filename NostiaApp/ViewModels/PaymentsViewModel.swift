import Foundation

@MainActor
final class PaymentsViewModel: ObservableObject {
    @Published var paymentMethods: [PaymentMethod] = []
    @Published var onboardingStatus: OnboardingStatus?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var onboardingURL: URL?
    @Published var showOnboarding = false

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
}
