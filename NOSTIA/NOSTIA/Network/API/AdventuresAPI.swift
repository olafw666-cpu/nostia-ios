import Foundation

final class ExperiencesAPI {
    static let shared = ExperiencesAPI()
    private let client = APIClient.shared
    private init() {}

    // MARK: - Legacy Adventures (unrelated feature — endpoints/type left untouched)

    func getAll(search: String? = nil, category: String? = nil, difficulty: String? = nil) async throws -> [Adventure] {
        var params: [String] = []
        if let s = search, !s.isEmpty { params.append("search=\(s.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? s)") }
        if let c = category { params.append("category=\(c)") }
        if let d = difficulty { params.append("difficulty=\(d)") }
        let qs = params.isEmpty ? "" : "?" + params.joined(separator: "&")
        return try await client.request("/adventures\(qs)")
    }

    func createAdventure(title: String, location: String, description: String?, category: String?, difficulty: String?) async throws -> Adventure {
        var body: [String: Any] = ["title": title, "location": location]
        if let d = description, !d.isEmpty { body["description"] = d }
        if let c = category { body["category"] = c }
        if let d = difficulty { body["difficulty"] = d }
        return try await client.request("/adventures", method: "POST", body: body)
    }

    // MARK: - Experiences

    func getUpcomingExperiences(limit: Int = 10) async throws -> [Experience] {
        return try await client.request("/experiences/upcoming?limit=\(limit)")
    }

    func getNearbyExperiences(lat: Double, lng: Double, radius: Double = 50) async throws -> [Experience] {
        return try await client.request("/experiences/nearby?lat=\(lat)&lng=\(lng)&radius=\(radius)")
    }

    func getAllExperiences() async throws -> [Experience] {
        return try await client.request("/experiences")
    }

    func getMapExperiences(minLat: Double, maxLat: Double, minLng: Double, maxLng: Double, viewportRadiusMiles: Double = 20, tags: [String] = []) async throws -> [Experience] {
        var path = "/experiences/map?minLat=\(minLat)&maxLat=\(maxLat)&minLng=\(minLng)&maxLng=\(maxLng)&viewportRadiusMiles=\(viewportRadiusMiles)"
        if !tags.isEmpty {
            let joined = tags.joined(separator: ",")
            path += "&tags=\(joined.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? joined)"
        }
        return try await client.request(path)
    }

    /// Far-out-zoom heatmap density grid. Public is platform-wide; followers/private are
    /// personalized to the signed-in user. Returns normalized cells (intensity 0...1).
    func getHeatmap(includePublic: Bool, includeFollowers: Bool, includePrivate: Bool) async throws -> [HeatmapCell] {
        let path = "/experiences/heatmap?public=\(includePublic ? 1 : 0)&followers=\(includeFollowers ? 1 : 0)&private=\(includePrivate ? 1 : 0)"
        let resp: HeatmapResponse = try await client.request(path)
        return resp.cells
    }

    func getMyGoingExperiences() async throws -> [Experience] {
        return try await client.request("/experiences/mine")
    }

    func createExperience(title: String, description: String?, location: String?, lat: Double?, lng: Double?, visibility: String = "public", flyerImage: String? = nil, tags: [String] = []) async throws -> Experience {
        var body: [String: Any] = ["title": title, "visibility": visibility]
        if let d = description { body["description"] = d }
        if let l = location { body["location"] = l }
        if let la = lat { body["latitude"] = la }
        if let lo = lng { body["longitude"] = lo }
        if let fi = flyerImage { body["flyerImage"] = fi }
        if !tags.isEmpty { body["tags"] = tags }
        return try await client.request("/experiences", method: "POST", body: body)
    }

    /// D1: set or clear the caller's status. `status` ∈ "visited" | "visiting" | "none"
    /// ("none" clears it). Returns the updated experience incl. visitedCount.
    func setStatus(experienceId: Int, status: String) async throws -> Experience {
        return try await client.request("/experiences/\(experienceId)/status", method: "POST", body: ["status": status])
    }

    /// D2/D3: submit the caller's rating (0...5 in 0.5 steps). Returns the updated
    /// experience incl. avgRating, ratingCount and myRating.
    func rateExperience(experienceId: Int, rating: Double) async throws -> Experience {
        return try await client.request("/experiences/\(experienceId)/rating", method: "POST", body: ["rating": rating])
    }

    /// D6: experiences a user marked Visited. The server gates visibility by the target
    /// user's visitedVisibility relative to the caller (throws 403 when not permitted).
    func getVisited(userId: Int) async throws -> [Experience] {
        return try await client.request("/users/\(userId)/visited")
    }

    // Experience chat — reuses the FeedComment shape returned by the server.
    func getExperienceComments(experienceId: Int) async throws -> [FeedComment] {
        return try await client.request("/experiences/\(experienceId)/comments")
    }

    func addExperienceComment(experienceId: Int, content: String) async throws -> FeedComment {
        return try await client.request("/experiences/\(experienceId)/comments", method: "POST", body: ["content": content])
    }

    func adminDeleteExperience(id: Int) async throws {
        try await client.requestVoid("/admin/experiences/\(id)", method: "DELETE")
    }

    func adminDeleteUser(id: Int) async throws {
        try await client.requestVoid("/admin/users/\(id)", method: "DELETE")
    }

    func updateExperience(id: Int, flyerImage: String) async throws -> Experience {
        return try await client.request("/experiences/\(id)", method: "PUT", body: ["flyerImage": flyerImage])
    }

    func deleteExperience(_ experienceId: Int) async throws {
        try await client.requestVoid("/experiences/\(experienceId)", method: "DELETE")
    }
}
