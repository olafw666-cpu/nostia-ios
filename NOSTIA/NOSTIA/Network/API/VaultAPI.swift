import Foundation

final class VaultAPI {
    static let shared = VaultAPI()
    private let client = APIClient.shared
    private init() {}

    func getTripSummary(_ tripId: Int) async throws -> VaultSummary {
        return try await client.request("/vault/trip/\(tripId)")
    }

    func createEntry(tripId: Int, description: String, amount: Double, category: String?, date: String, splits: [ExpenseSplitInput]) async throws {
        var body: [String: Any] = [
            "tripId": tripId,
            "description": description,
            "amount": amount,
            "date": date,
            "splits": splits.map { ["userId": $0.userId, "amount": $0.amount] }
        ]
        if let cat = category { body["category"] = cat }
        try await client.requestVoid("/vault", method: "POST", body: body)
    }

    func deleteEntry(_ id: Int) async throws {
        try await client.requestVoid("/vault/\(id)", method: "DELETE")
    }

    /// Cash claim: no longer marks the split paid — asks the expense payer to verify.
    func requestCashVerification(_ splitId: Int) async throws {
        try await client.requestVoid("/vault/splits/\(splitId)/paid", method: "PUT")
    }

    /// Expense payer confirms they received the cash (this marks the split paid).
    func verifyCashPayment(_ splitId: Int) async throws {
        try await client.requestVoid("/vault/splits/\(splitId)/cash-verify", method: "POST")
    }

    /// Expense payer declines the cash claim (split stays unpaid).
    func declineCashPayment(_ splitId: Int) async throws {
        try await client.requestVoid("/vault/splits/\(splitId)/cash-decline", method: "POST")
    }

    func createPaymentIntent(splitId: Int) async throws -> PaymentIntentResponse {
        return try await client.request("/vault/splits/\(splitId)/payment-intent", method: "POST")
    }

    func createBulkPaymentIntent(splitIds: [Int], tripId: Int) async throws -> BulkPaymentIntentResponse {
        let body: [String: Any] = ["splitIds": splitIds, "tripId": tripId]
        return try await client.request("/vault/bulk-payment-intent", method: "POST", body: body)
    }

    func sendReminder(targetUserId: Int, tripId: Int) async throws {
        let body: [String: Any] = ["targetUserId": targetUserId, "tripId": tripId]
        try await client.requestVoid("/vault/remind", method: "POST", body: body)
    }
}
