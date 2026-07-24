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

    // MARK: - Completion verification (§6)

    /// Geofence dwell batch. A 422 means the batch didn't survive validation
    /// (too short, outside the fence, implausible) — surfaced as `httpError`
    /// with the server's reason so the UI can say why.
    func verifyDwell(planId: Int, stopId: Int, samples: [[String: Any]]) async throws -> DwellResponse {
        try await client.request(
            "/plans/\(planId)/stops/\(stopId)/dwell", method: "POST",
            body: ["samples": samples]
        )
    }

    func captureToken(planId: Int, stopId: Int) async throws -> CaptureTokenResponse {
        try await client.request("/plans/\(planId)/stops/\(stopId)/capture-token", method: "POST")
    }

    /// Multipart photo upload. Self-contained (APIClient is JSON-only): the
    /// JPEG never touches disk on the way out, matching the in-app-camera-only
    /// capture contract.
    func uploadStopPhoto(planId: Int, stopId: Int, jpeg: Data, nonce: String) async throws -> PhotoAttachResponse {
        guard let url = URL(string: AppConfig.apiBaseURL + "/plans/\(planId)/stops/\(stopId)/photo") else {
            throw APIError.invalidURL
        }
        guard let token = AuthManager.shared.getToken() else { throw APIError.noToken }

        let boundary = "nostia-\(UUID().uuidString)"
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()
        func field(_ s: String) { body.append(Data(s.utf8)) }
        field("--\(boundary)\r\nContent-Disposition: form-data; name=\"nonce\"\r\n\r\n\(nonce)\r\n")
        field("--\(boundary)\r\nContent-Disposition: form-data; name=\"photo\"; filename=\"stop.jpg\"\r\nContent-Type: image/jpeg\r\n\r\n")
        body.append(jpeg)
        field("\r\n--\(boundary)--\r\n")
        request.httpBody = body

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw APIError.unknown }
        guard (200..<300).contains(http.statusCode) else {
            let msg = (try? JSONDecoder().decode(APIErrorResponse.self, from: data))?.error
                ?? HTTPURLResponse.localizedString(forStatusCode: http.statusCode)
            throw APIError.httpError(statusCode: http.statusCode, message: msg)
        }
        return try JSONDecoder().decode(PhotoAttachResponse.self, from: data)
    }

    /// One tap, server-gated on a confirmed completion (§6).
    func rate(planId: Int, rating: Int) async throws {
        try await client.requestVoid("/plans/\(planId)/rate", method: "POST", body: ["rating": rating])
    }

    /// Contextual vault (§3): creates/links a trip for this plan with every
    /// member aboard. Idempotent — returns the existing trip when one is linked.
    func createVault(planId: Int) async throws -> PlanVaultResponse {
        try await client.request("/plans/\(planId)/vault", method: "POST")
    }

    // MARK: - Live validation (§5)

    /// Drop-and-recompose after a render-time liveness failure. The server
    /// swaps in the best same-category candidate within walking range, or
    /// drops the stop when the layer has nothing left. Only the verdict
    /// travels — never any enrichment data.
    func recompose(planId: Int, stopId: Int, reason: String) async throws -> RecomposeResponse {
        try await client.request(
            "/plans/\(planId)/stops/\(stopId)/recompose", method: "POST",
            body: ["reason": reason]
        )
    }

    /// User-reported dead venue. K distinct reporters tombstone the place so
    /// it is never served again.
    func reportPlace(placeId: Int, reason: String) async throws {
        try await client.requestVoid("/places/\(placeId)/report", method: "POST", body: ["reason": reason])
    }

    /// Map pins (§7). Verified first and always; Suggested backfills only when
    /// verified density is thin. `filter: "verified"` shows verified only.
    func placePins(
        minLat: Double, minLng: Double, maxLat: Double, maxLng: Double,
        filter: String = "all"
    ) async throws -> PlacePinsResponse {
        let bbox = "\(minLat),\(minLng),\(maxLat),\(maxLng)"
        return try await client.request("/places/map?bbox=\(bbox)&filter=\(filter)")
    }

    // MARK: - Invite (§4.6: part of the plan artifact, not a follow-up prompt)

    /// 2–3 pre-populated suggestions, dormancy-boosted. An empty list is a
    /// valid answer at n=1 — the caller collapses the row rather than nagging.
    func inviteSuggestions(planId: Int, limit: Int = 3) async throws -> InviteSuggestionsResponse {
        try await client.request("/plans/\(planId)/invite-suggestions?limit=\(limit)")
    }

    /// One tap. The invitee joins immediately and gets a push.
    func invite(planId: Int, userId: Int) async throws -> InviteResponse {
        try await client.request(
            "/plans/\(planId)/invite", method: "POST", body: ["user_id": userId]
        )
    }

    /// Shareable link for people who aren't on Nostia (or aren't followed).
    func inviteLink(planId: Int) async throws -> InviteLinkResponse {
        try await client.request("/plans/\(planId)/invite-link", method: "POST")
    }

    /// Join from a shared link token (nostia://plan/<token>).
    func redeemInvite(token: String) async throws -> PlanResponse {
        try await client.request("/plans/invites/\(token)/redeem", method: "POST")
    }
}

struct InviteSuggestionsResponse: Codable {
    let suggestions: [InviteSuggestion]
}

struct InviteSuggestion: Codable, Identifiable, Equatable {
    let id: Int
    let username: String
    let name: String?
    let isDev: Bool?

    var displayName: String { name?.isEmpty == false ? name! : username }
    var initial: String { String(displayName.prefix(1)).uppercased() }
}

struct InviteResponse: Codable {
    let planUpdated: AdventurePlan?

    enum CodingKeys: String, CodingKey {
        case planUpdated = "plan"
    }
}

struct InviteLinkResponse: Codable {
    let token: String
    let url: String
}

struct RecomposeResponse: Codable {
    let plan: AdventurePlan
    let swapped: Bool
}

struct PlanVaultResponse: Codable {
    let tripId: Int
    let created: Bool

    enum CodingKeys: String, CodingKey {
        case created
        case tripId = "trip_id"
    }
}
