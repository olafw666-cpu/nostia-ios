import Foundation

/// Adventure plan endpoints (Product Definition v2 §4). The client sends the
/// origin and optional refinements; composition, validation, and lifecycle are
/// all server-decided. A dead zone comes back as `plan: nil` + reason, not an
/// error — the UI degrades honestly instead of faking a plan.
final class PlansAPI {
    static let shared = PlansAPI()
    private let client = APIClient.shared
    private init() {}

    /// One primary action (§4.4). Refinements are optional and defaulted so the
    /// whole call works as `generate(lat:lng:)`. `localHour` lets the server
    /// pick morning/afternoon/evening/night templates in the user's own clock.
    func generate(
        lat: Double,
        lng: Double,
        vibe: String? = nil,
        budget: String? = nil,
        groupSize: Int? = nil,
        windowMinutes: Int? = nil,
        distanceM: Double? = nil,
        localHour: Int = Calendar.current.component(.hour, from: Date())
    ) async throws -> PlanResponse {
        var body: [String: Any] = ["lat": lat, "lng": lng, "local_hour": localHour]
        if let vibe { body["vibe"] = vibe }
        if let budget { body["budget"] = budget }
        if let groupSize { body["group_size"] = groupSize }
        if let windowMinutes { body["window_minutes"] = windowMinutes }
        if let distanceM { body["distance_m"] = distanceM }
        return try await client.request("/plans/generate", method: "POST", body: body)
    }

    /// Free, unlimited, one tap (§4.7). The server excludes every place the
    /// rerolled plan showed, so the next roll is guaranteed different.
    func reroll(planId: Int, localHour: Int = Calendar.current.component(.hour, from: Date())) async throws -> PlanResponse {
        try await client.request(
            "/plans/\(planId)/reroll", method: "POST",
            body: ["local_hour": localHour]
        )
    }

    /// Newest live plan (generated/provisional/verified) for this user,
    /// including plans they're a member of.
    func current() async throws -> PlanResponse {
        try await client.request("/plans/current")
    }

    /// generated → provisional (§6): the user is keeping this plan.
    func accept(planId: Int) async throws -> PlanResponse {
        try await client.request("/plans/\(planId)/accept", method: "POST")
    }
}
