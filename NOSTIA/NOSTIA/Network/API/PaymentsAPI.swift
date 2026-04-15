import Foundation

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

    func startOnboarding() async throws -> String {
        struct OnboardingResponse: Decodable { let url: String }
        let resp: OnboardingResponse = try await client.request("/stripe/onboard", method: "POST")
        return resp.url
    }

    func getOnboardingStatus() async throws -> OnboardingStatus {
        try await client.request("/stripe/onboard/status")
    }
}
