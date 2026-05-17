import Foundation

struct VaultSummary: Codable {
    let entries: [VaultEntry]
    let balances: [VaultBalance]
    let totalAmount: Double?
    let vaultLeaderId: Int?
    let currentUserId: Int?
    let unpaidSplits: [UnpaidSplit]?
}

struct VaultEntry: Codable, Identifiable {
    let id: Int
    var description: String
    var amount: Double
    var currency: String
    var category: String?
    var date: String
    var paidById: Int?
    var paidByName: String?
    var paidByUsername: String?
    var splits: [VaultSplit]?

    enum CodingKeys: String, CodingKey {
        case id, description, amount, currency, category, date, splits
        case paidById = "paidBy"
        case paidByName
        case paidByUsername
    }

    var formattedDate: String {
        let fmt = DateFormatter(); fmt.dateFormat = "yyyy-MM-dd"
        let out = DateFormatter(); out.dateFormat = "MMM d, yyyy"
        if let d = fmt.date(from: date) { return out.string(from: d) }
        return date
    }
}

struct VaultSplit: Codable, Identifiable {
    let id: Int
    let userId: Int
    let userName: String?
    let userUsername: String?
    let amount: Double
    var paid: Bool
    var paidAt: String?
}

struct VaultBalance: Codable, Identifiable {
    let id: Int          // userId
    let name: String
    let username: String?
    var paid: Double
    var owes: Double
    var balance: Double
}

struct UnpaidSplit: Codable, Identifiable {
    let id: Int
    let vaultEntryId: Int
    let userId: Int
    let amount: Double
    let paid: Bool
    let description: String
    let date: String
    let currency: String

    var formattedDate: String {
        let fmt = DateFormatter(); fmt.dateFormat = "yyyy-MM-dd"
        let out = DateFormatter(); out.dateFormat = "MMM d, yyyy"
        if let d = fmt.date(from: date) { return out.string(from: d) }
        return date
    }
}

struct PaymentIntentResponse: Codable {
    let clientSecret: String
    let chargedAmount: Double
    let customerId: String?
    let ephemeralKeySecret: String?
}

struct BulkPaymentIntentResponse: Codable {
    let clientSecret: String
    let chargedAmount: Double
    let customerId: String?
    let ephemeralKeySecret: String?
    let splitIds: [Int]
}

// Stripe fee passthrough: mirrors server-side calculateChargedAmount
func calculateChargedAmount(_ owed: Double) -> Double {
    return (ceil(((owed + 0.30) / (1.0 - 0.029)) * 100) / 100)
}
