import Foundation

final class AdventuresAPI {
    static let shared = AdventuresAPI()
    private let client = APIClient.shared
    private init() {}

    func getAll(search: String? = nil, category: String? = nil, difficulty: String? = nil) async throws -> [Adventure] {
        var params: [String] = []
        if let s = search, !s.isEmpty { params.append("search=\(s.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? s)") }
        if let c = category { params.append("category=\(c)") }
        if let d = difficulty { params.append("difficulty=\(d)") }
        let qs = params.isEmpty ? "" : "?" + params.joined(separator: "&")
        return try await client.request("/adventures\(qs)")
    }

    func getUpcomingEvents(limit: Int = 10) async throws -> [Event] {
        return try await client.request("/events/upcoming?limit=\(limit)")
    }

    func getNearbyEvents(lat: Double, lng: Double, radius: Double = 50) async throws -> [Event] {
        return try await client.request("/events/nearby?lat=\(lat)&lng=\(lng)&radius=\(radius)")
    }

    func getAllEvents() async throws -> [Event] {
        return try await client.request("/events")
    }

    func createEvent(title: String, description: String?, location: String?, eventDate: String?, lat: Double?, lng: Double?, visibility: String = "public") async throws -> Event {
        var body: [String: Any] = ["title": title, "visibility": visibility]
        if let d = description { body["description"] = d }
        if let l = location { body["location"] = l }
        if let d = eventDate { body["eventDate"] = d }
        if let la = lat { body["latitude"] = la }
        if let lo = lng { body["longitude"] = lo }
        return try await client.request("/events", method: "POST", body: body)
    }

    func rsvp(eventId: Int, status: String) async throws -> Event {
        return try await client.request("/events/\(eventId)/rsvp", method: "POST", body: ["status": status])
    }

    func updateEvent(id: Int, flyerImage: String) async throws -> Event {
        return try await client.request("/events/\(id)", method: "PUT", body: ["flyerImage": flyerImage])
    }

    func deleteEvent(_ eventId: Int) async throws {
        try await client.requestVoid("/events/\(eventId)", method: "DELETE")
    }

    func createAdventure(title: String, location: String, description: String?, category: String?, difficulty: String?) async throws -> Adventure {
        var body: [String: Any] = ["title": title, "location": location]
        if let d = description, !d.isEmpty { body["description"] = d }
        if let c = category { body["category"] = c }
        if let d = difficulty { body["difficulty"] = d }
        return try await client.request("/adventures", method: "POST", body: body)
    }
}
