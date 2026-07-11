import Foundation

// MARK: - Crash pads ("find a place to crash")

/// A mutual follower's pad as listed by GET /crashpads.
struct FriendCrashPad: Codable, Identifiable, Equatable {
    let id: Int
    let userId: Int
    let title: String
    let description: String?
    let area: String?
    let capacity: Int
    let createdAt: String?
    let hostName: String?
    let hostUsername: String?
    let hostProfilePictureUrl: String?
    /// My latest request's status for this pad ("pending"/"accepted"/"declined"/"cancelled").
    let myRequestStatus: String?
}

/// My own pad (GET /crashpads/mine → pad).
struct MyCrashPad: Codable, Equatable {
    let id: Int
    let userId: Int
    let title: String
    let description: String?
    let area: String?
    let capacity: Int
    let isActive: Bool
    let createdAt: String?
    let updatedAt: String?
}

/// A stay request — used for both incoming (on my pad) and outgoing (mine to others).
struct CrashPadRequest: Codable, Identifiable, Equatable {
    let id: Int
    let padId: Int
    let requesterId: Int
    let startDate: String?
    let endDate: String?
    let message: String?
    let status: String
    let createdAt: String?
    let padTitle: String?
    let padArea: String?
    let requesterName: String?
    let requesterUsername: String?
    let requesterProfilePictureUrl: String?
    let hostId: Int?
    let hostName: String?
    let hostUsername: String?

    var dateRangeText: String? {
        switch (startDate, endDate) {
        case let (s?, e?): return "\(Self.pretty(s)) – \(Self.pretty(e))"
        case let (s?, nil): return "from \(Self.pretty(s))"
        case let (nil, e?): return "until \(Self.pretty(e))"
        default: return nil
        }
    }

    private static func pretty(_ wire: String) -> String {
        let parser = DateFormatter()
        parser.dateFormat = "yyyy-MM-dd"
        parser.locale = Locale(identifier: "en_US_POSIX")
        guard let d = parser.date(from: wire) else { return wire }
        let out = DateFormatter()
        out.dateFormat = "MMM d"
        return out.string(from: d)
    }
}

/// GET /crashpads/mine — my pad plus both request queues.
struct CrashPadMineResponse: Codable {
    let pad: MyCrashPad?
    let incoming: [CrashPadRequest]
    let outgoing: [CrashPadRequest]
}

// MARK: - API

final class CrashPadsAPI {
    static let shared = CrashPadsAPI()
    private let client = APIClient.shared
    private init() {}

    func getFriendPads() async throws -> [FriendCrashPad] {
        return try await client.request("/crashpads")
    }

    func getMine() async throws -> CrashPadMineResponse {
        return try await client.request("/crashpads/mine")
    }

    func upsertMine(title: String, description: String?, area: String?, capacity: Int, isActive: Bool) async throws -> MyCrashPad {
        var body: [String: Any] = ["title": title, "capacity": capacity, "isActive": isActive]
        if let d = description, !d.isEmpty { body["description"] = d }
        if let a = area, !a.isEmpty { body["area"] = a }
        return try await client.request("/crashpads/mine", method: "PUT", body: body)
    }

    func deleteMine() async throws {
        try await client.requestVoid("/crashpads/mine", method: "DELETE")
    }

    func request(padId: Int, startDate: String?, endDate: String?, message: String?) async throws -> CrashPadRequest {
        var body: [String: Any] = [:]
        if let s = startDate { body["startDate"] = s }
        if let e = endDate { body["endDate"] = e }
        if let m = message, !m.isEmpty { body["message"] = m }
        return try await client.request("/crashpads/\(padId)/request", method: "POST", body: body)
    }

    func respond(requestId: Int, accept: Bool) async throws -> CrashPadRequest {
        return try await client.request("/crashpads/requests/\(requestId)/respond", method: "POST", body: ["accept": accept])
    }

    func cancel(requestId: Int) async throws {
        try await client.requestVoid("/crashpads/requests/\(requestId)", method: "DELETE")
    }
}
