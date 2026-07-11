import Foundation

struct RedeemResult: Codable {
    let trip: Trip
    let alreadyMember: Bool
    // Optional so decoding survives a backend that omits it (pre-fix servers sent
    // `followsAdded` on fresh joins, which made every successful scan look like a failure).
    let friendsAdded: Int?
    let vaultName: String
}

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

    func getInviteToken(tripId: Int) async throws -> String {
        struct R: Decodable { let token: String }
        let r: R = try await client.request("/trips/\(tripId)/invite-token")
        return r.token
    }

    func redeemInviteToken(_ token: String) async throws -> RedeemResult {
        return try await client.request("/invite/redeem", method: "POST", body: ["token": token])
    }

    func addVaultMembers(tripId: Int, userIds: [Int]) async throws -> Trip {
        return try await client.request("/trips/\(tripId)/vault-add-members", method: "POST", body: ["userIds": userIds])
    }

    // MARK: - Trip plan (tasks + date poll)

    func getPlan(tripId: Int) async throws -> TripPlanResponse {
        return try await client.request("/trips/\(tripId)/plan")
    }

    func addTask(tripId: Int, title: String) async throws -> TripTask {
        return try await client.request("/trips/\(tripId)/plan/tasks", method: "POST", body: ["title": title])
    }

    func toggleTaskClaim(tripId: Int, taskId: Int) async throws -> TripTask {
        return try await client.request("/trips/\(tripId)/plan/tasks/\(taskId)/claim", method: "POST", body: [:])
    }

    func toggleTaskDone(tripId: Int, taskId: Int) async throws -> TripTask {
        return try await client.request("/trips/\(tripId)/plan/tasks/\(taskId)/done", method: "POST", body: [:])
    }

    func deleteTask(tripId: Int, taskId: Int) async throws {
        try await client.requestVoid("/trips/\(tripId)/plan/tasks/\(taskId)", method: "DELETE")
    }

    func addDateOption(tripId: Int, date: String) async throws -> [TripDateOption] {
        return try await client.request("/trips/\(tripId)/plan/dates", method: "POST", body: ["date": date])
    }

    func toggleDateVote(tripId: Int, optionId: Int) async throws -> [TripDateOption] {
        return try await client.request("/trips/\(tripId)/plan/dates/\(optionId)/vote", method: "POST", body: [:])
    }

    func deleteDateOption(tripId: Int, optionId: Int) async throws {
        try await client.requestVoid("/trips/\(tripId)/plan/dates/\(optionId)", method: "DELETE")
    }
}
