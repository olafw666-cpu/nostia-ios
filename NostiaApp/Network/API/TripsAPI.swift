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

    func create(title: String, destination: String, description: String?, startDate: String?, endDate: String?) async throws -> Trip {
        var body: [String: Any] = ["title": title, "destination": destination]
        if let d = description { body["description"] = d }
        if let s = startDate { body["startDate"] = s }
        if let e = endDate { body["endDate"] = e }
        return try await client.request("/trips", method: "POST", body: body)
    }

    func update(_ id: Int, title: String, destination: String, description: String?, startDate: String?, endDate: String?) async throws -> Trip {
        var body: [String: Any] = ["title": title, "destination": destination]
        if let d = description { body["description"] = d }
        if let s = startDate { body["startDate"] = s }
        if let e = endDate { body["endDate"] = e }
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
}
