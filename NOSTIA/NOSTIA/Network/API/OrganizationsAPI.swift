import Foundation

final class OrganizationsAPI {
    static let shared = OrganizationsAPI()
    private let client = APIClient.shared
    private init() {}

    // MARK: - Org lifecycle

    func create(name: String, description: String?, imageData: String?,
                locationVerificationEnabled: Bool, postPermission: String,
                privacy: String, rulesText: String?, zones: [ZoneDraft]) async throws -> Organization {
        var body: [String: Any] = [
            "name": name,
            "locationVerificationEnabled": locationVerificationEnabled,
            "postPermission": postPermission,
            "privacy": privacy,
            "zones": zones.map { $0.asPayload }
        ]
        if let description { body["description"] = description }
        if let imageData { body["imageData"] = imageData }
        if let rulesText { body["rulesText"] = rulesText }
        return try await client.request("/orgs", method: "POST", body: body)
    }

    func search(query: String) async throws -> [Organization] {
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        return try await client.request("/orgs/search?query=\(encoded)")
    }

    func mine() async throws -> [Organization] {
        try await client.request("/orgs/mine")
    }

    func get(id: Int) async throws -> Organization {
        try await client.request("/orgs/\(id)")
    }

    func update(id: Int, fields: [String: Any]) async throws -> Organization {
        try await client.request("/orgs/\(id)", method: "PUT", body: fields)
    }

    func delete(id: Int) async throws {
        try await client.requestVoid("/orgs/\(id)", method: "DELETE")
    }

    // MARK: - Membership

    func join(id: Int, latitude: Double?, longitude: Double?) async throws -> OrgJoinResult {
        var body: [String: Any] = [:]
        if let latitude { body["latitude"] = latitude }
        if let longitude { body["longitude"] = longitude }
        return try await client.request("/orgs/\(id)/join", method: "POST", body: body.isEmpty ? nil : body)
    }

    func leave(id: Int) async throws {
        try await client.requestVoid("/orgs/\(id)/leave", method: "POST")
    }

    // MARK: - Zones

    func getZones(id: Int) async throws -> [OrgZone] {
        try await client.request("/orgs/\(id)/zones")
    }

    func setZones(id: Int, zones: [ZoneDraft]) async throws -> [OrgZone] {
        try await client.request("/orgs/\(id)/zones", method: "PUT", body: ["zones": zones.map { $0.asPayload }])
    }

    // MARK: - Members & roles

    func getMembers(id: Int) async throws -> [OrgMember] {
        try await client.request("/orgs/\(id)/members")
    }

    func removeMember(id: Int, userId: Int) async throws {
        try await client.requestVoid("/orgs/\(id)/members/\(userId)", method: "DELETE")
    }

    func setRole(id: Int, userId: Int, role: String) async throws {
        try await client.requestVoid("/orgs/\(id)/members/\(userId)/role", method: "PUT", body: ["role": role])
    }

    func transfer(id: Int, newOwnerId: Int) async throws -> Organization {
        try await client.request("/orgs/\(id)/transfer", method: "POST", body: ["newOwnerId": newOwnerId])
    }

    // MARK: - Join requests (private orgs)

    func getRequests(id: Int) async throws -> [OrgJoinRequest] {
        try await client.request("/orgs/\(id)/requests")
    }

    func actOnRequest(id: Int, userId: Int, approve: Bool) async throws {
        try await client.requestVoid("/orgs/\(id)/requests/\(userId)", method: "POST",
                                     body: ["action": approve ? "approve" : "reject"])
    }

    // MARK: - Org content

    func getPosts(id: Int) async throws -> [FeedPost] {
        try await client.request("/orgs/\(id)/posts")
    }

    func createPost(id: Int, content: String?, imageData: String) async throws -> FeedPost {
        var body: [String: Any] = ["imageData": imageData]
        if let content { body["content"] = content }
        return try await client.request("/orgs/\(id)/posts", method: "POST", body: body)
    }

    func getEvents(id: Int) async throws -> [Event] {
        try await client.request("/orgs/\(id)/events")
    }

    func createEvent(id: Int, title: String, description: String?, location: String?,
                     eventDate: String, latitude: Double, longitude: Double,
                     flyerImage: String?) async throws -> Event {
        var body: [String: Any] = [
            "title": title,
            "eventDate": eventDate,
            "latitude": latitude,
            "longitude": longitude
        ]
        if let description { body["description"] = description }
        if let location { body["location"] = location }
        if let flyerImage { body["flyerImage"] = flyerImage }
        return try await client.request("/orgs/\(id)/events", method: "POST", body: body)
    }
}
