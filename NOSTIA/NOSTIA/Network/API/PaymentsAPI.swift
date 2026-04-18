import Foundation

struct SetupIntentResponse: Decodable {
    let clientSecret: String
    let customerId: String
    let ephemeralKey: String
}

final class PaymentsAPI {
    static let shared = PaymentsAPI()
    private let client = APIClient.shared
    private init() {}

    func getPaymentMethods() async throws -> [PaymentMethod] {
        try await client.request("/stripe/payment-methods")
    }

    func removePaymentMethod(id: String) async throws {
        try await client.requestVoid("/stripe/payment-methods/\(id)", method: "DELETE")
    }

    func setDefaultPaymentMethod(id: String) async throws {
        try await client.requestVoid("/stripe/payment-methods/\(id)/default", method: "PUT")
    }

    func createSetupIntent() async throws -> SetupIntentResponse {
        try await client.request("/stripe/setup-intent", method: "POST")
    }

    func savePaymentMethod(paymentMethodId: String) async throws {
        try await client.requestVoid("/stripe/payment-methods/save", method: "POST",
                                     body: ["paymentMethodId": paymentMethodId])
    }

    func startOnboarding() async throws -> String {
        struct OnboardingResponse: Decodable { let url: String }
        let resp: OnboardingResponse = try await client.request("/stripe/onboard", method: "POST")
        return resp.url
    }

    func getOnboardingStatus() async throws -> OnboardingStatus {
        try await client.request("/stripe/onboard/status")
    }
}
