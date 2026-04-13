import Foundation

struct PaymentMethod: Codable, Identifiable {
    let id: String
    let brand: String?
    let last4: String?
    let expMonth: Int?
    let expYear: Int?
    let isDefault: Bool?

    var displayName: String {
        let b = brand?.capitalized ?? "Card"
        let l = last4 ?? "••••"
        return "\(b) ••••\(l)"
    }
    var expiry: String {
        guard let m = expMonth, let y = expYear else { return "" }
        return String(format: "%02d/%02d", m, y % 100)
    }
}

struct OnboardingStatus: Codable {
    let complete: Bool
    let stripeAccountId: String?
}

struct AddPaymentMethodRequest: Codable {
    let paymentMethodId: String
}
