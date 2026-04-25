import Foundation

final class TripsAPI {
    static let shared = TripsAPI()
    private let client = APIClient.shared
    private init() {}

    func getAll() async throws -> [Trip] {
        return try await client.request("/trips")
    }

    func get(_ id: Int) async throws -> Trip {
        return try await client.request("/trips/\(id)")
    }

    func create(title: String, description: String?) async throws -> Trip {
        var body: [String: Any] = ["title": title]
        if let d = description { body["description"] = d }
        return try await client.request("/trips", method: "POST", body: body)
    }

    func update(_ id: Int, title: String, description: String?) async throws -> Trip {
        var body: [String: Any] = ["title": title]
        if let d = description { body["description"] = d }
        return try await client.request("/trips/\(id)", method: "PUT", body: body)
    }

    func delete(_ id: Int) async throws {
        try await client.requestVoid("/trips/\(id)", method: "DELETE")
    }

    func addParticipant(tripId: Int, userId: Int) async throws -> Trip {
        return try await client.request("/trips/\(tripId)/participants", method: "POST", body: ["userId": userId])
    }

    func removeParticipant(tripId: Int, userId: Int) async throws -> Trip {
        return try await client.request("/trips/\(tripId)/participants/\(userId)", method: "DELETE")
    }

    func kickParticipant(tripId: Int, userId: Int) async throws -> Trip {
        return try await client.request("/trips/\(tripId)/kick/\(userId)", method: "POST", body: [:])
    }

    func transferLeadership(tripId: Int, newLeaderId: Int) async throws -> Trip {
        return try await client.request("/trips/\(tripId)/vault-leader", method: "POST", body: ["newLeaderId": newLeaderId])
    }

    func getChatMessages(tripId: Int, limit: Int = 100, offset: Int = 0) async throws -> [TripChatMessage] {
        return try await client.request("/trips/\(tripId)/chat?limit=\(limit)&offset=\(offset)")
    }

    func sendChatMessage(tripId: Int, content: String) async throws -> TripChatMessage {
        return try await client.request("/trips/\(tripId)/chat", method: "POST", body: ["content": content])
    }
}
