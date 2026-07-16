import Foundation

/// Adventure Page endpoints. The client only ever sends difficulty, pedometer
/// readings, and complete/discard calls — points, targets, cycle timing and progress
/// clamping are all server-decided.
final class AdventureAPI {
    static let shared = AdventureAPI()
    private let client = APIClient.shared
    private init() {}

    /// Single source of truth for AdventureView.
    func getCurrent() async throws -> AdventureCurrentState {
        try await client.request("/adventures/current")
    }

    /// Always 200 with the adventure — it's a pool draw, not a model call.
    /// 429 (cycle not elapsed) surfaces as `APIError.httpError`.
    func generate(difficulty: AdventureDifficulty) async throws -> AdventureGenerateResponse {
        try await client.request(
            "/adventures/generate", method: "POST",
            body: ["difficulty": difficulty.rawValue]
        )
    }

    /// Cumulative pedometer reading since the adventure was issued — not a delta, so
    /// re-sends are idempotent. The server clamps against elapsed time and only ever
    /// ratchets progress upward.
    func reportProgress(adventureId: Int, steps: Int, distanceM: Double) async throws -> AdventureProgressResponse {
        try await client.request(
            "/adventures/\(adventureId)/progress", method: "POST",
            body: ["steps": steps, "distance_m": Int(distanceM.rounded())]
        )
    }

    /// Checks the server's stored progress, never anything sent here. Sync first.
    func complete(adventureId: Int) async throws -> AdventureCompleteResponse {
        try await client.request("/adventures/\(adventureId)/complete", method: "POST")
    }

    /// Valid only within 5 minutes of issuance, once per cycle.
    func discard(adventureId: Int) async throws {
        try await client.requestVoid("/adventures/\(adventureId)/discard", method: "POST")
    }

    // MARK: - Cosmetics store

    func getCosmetics() async throws -> CosmeticCatalog {
        try await client.request("/cosmetics")
    }

    func purchase(itemId: Int) async throws -> CosmeticPurchaseResponse {
        try await client.request("/cosmetics/\(itemId)/purchase", method: "POST")
    }
}
