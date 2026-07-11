import Foundation

/// Adventure Page endpoints (spec §11). The client only ever sends difficulty,
/// an optional prompt, and step-check/complete calls — points, step counts,
/// cycle timing and source are all server-decided.
final class AdventureAPI {
    static let shared = AdventureAPI()
    private let client = APIClient.shared
    private init() {}

    /// Single source of truth for AdventureView.
    func getCurrent() async throws -> AdventureCurrentState {
        try await client.request("/adventures/current")
    }

    /// 202 → `jobId` set (poll). 200 → `adventure` set (instant fallback path).
    /// 422 (prompt filtered, credit intact) and 429 (cycle not elapsed) surface
    /// as `APIError.httpError` — match on the status code.
    func generate(difficulty: AdventureDifficulty, prompt: String?) async throws -> AdventureGenerateResponse {
        var body: [String: Any] = ["difficulty": difficulty.rawValue]
        if let prompt, !prompt.isEmpty { body["prompt"] = prompt }
        return try await client.request("/adventures/generate", method: "POST", body: body)
    }

    func jobStatus(id: Int) async throws -> AdventureJobStatus {
        try await client.request("/adventures/jobs/\(id)")
    }

    /// Toggle-ON only (no uncheck in V1).
    func checkStep(adventureId: Int, order: Int) async throws {
        try await client.requestVoid("/adventures/\(adventureId)/steps/\(order)/check", method: "POST")
    }

    func complete(adventureId: Int) async throws -> AdventureCompleteResponse {
        try await client.request("/adventures/\(adventureId)/complete", method: "POST")
    }

    /// Valid only within 5 minutes of issuance with zero steps checked (§6).
    func discard(adventureId: Int) async throws {
        try await client.requestVoid("/adventures/\(adventureId)/discard", method: "POST")
    }

    // MARK: - Cosmetics store (§9)

    func getCosmetics() async throws -> CosmeticCatalog {
        try await client.request("/cosmetics")
    }

    func purchase(itemId: Int) async throws -> CosmeticPurchaseResponse {
        try await client.request("/cosmetics/\(itemId)/purchase", method: "POST")
    }
}
