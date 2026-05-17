import Foundation

final class VaultAPI {
    static let shared = VaultAPI()
    private let client = APIClient.shared
    private init() {}

    func getTripSummary(_ tripId: Int) async throws -> VaultSummary {
        return try await client.request("/vault/trip/\(tripId)")
    }

    func createEntry(tripId: Int, description: String, amount: Double, category: String?, date: String) async throws {
        var body: [String: Any] = [
            "tripId": tripId,
            "description": description,
            "amount": amount,
            "date": date
        ]
        if let cat = category { body["category"] = cat }
        try await client.requestVoid("/vault", method: "POST", body: body)
    }

    func deleteEntry(_ id: Int) async throws {
        try await client.requestVoid("/vault/\(id)", method: "DELETE")
    }

    func markSplitPaid(_ splitId: Int) async throws {
        try await client.requestVoid("/vault/splits/\(splitId)/paid", method: "PUT")
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
