import Foundation

// Organizations feature (Organizations spec). All server responses use camelCase keys,
// so these decode without custom CodingKeys.

struct Organization: Codable, Identifiable {
    let id: Int
    let ownerId: Int
    let ownerName: String?
    let name: String
    let description: String?
    let imageUrl: String?
    let locationVerificationEnabled: Bool
    let postPermission: String   // "members" | "locked"
    let privacy: String          // "public" | "private"
    let rulesText: String?
    let createdAt: String?
    let memberCount: Int
    let zoneCount: Int
    let myRole: String?          // "owner" | "admin" | "member" | nil
    let isMember: Bool
    let hasPendingRequest: Bool
    let canPost: Bool

    var isOwner: Bool { myRole == "owner" }
    var canManage: Bool { myRole == "owner" || myRole == "admin" }
    var initial: String { String(name.prefix(1)).uppercased() }
}

struct OrgZonePoint: Codable, Equatable {
    let lat: Double
    let lng: Double
}

struct OrgZone: Codable, Identifiable {
    let id: Int
    let type: String             // "radius" | "freehand"
    let centerLat: Double?
    let centerLng: Double?
    let radius: Double?          // metres
    let polygonCoords: [OrgZonePoint]?
}

struct OrgMember: Codable, Identifiable {
    let userId: Int
    let role: String
    let joinedAt: String?
    let username: String
    let name: String
    let profilePictureUrl: String?

    var id: Int { userId }
    var initial: String { String(name.prefix(1)).uppercased() }
}

struct OrgJoinRequest: Codable, Identifiable {
    let userId: Int
    let status: String
    let requestedAt: String?
    let username: String
    let name: String
    let profilePictureUrl: String?

    var id: Int { userId }
    var initial: String { String(name.prefix(1)).uppercased() }
}

struct OrgJoinResult: Codable {
    let status: String           // "joined" | "pending"
    let org: Organization
}

// Client-side draft for the zone editor (Section 3.1). Converted to the wire format by
// OrganizationsAPI before sending.
struct ZoneDraft: Identifiable {
    let id = UUID()
    var type: String             // "radius" | "freehand"
    var centerLat: Double?
    var centerLng: Double?
    var radius: Double?          // metres
    var polygon: [OrgZonePoint]?

    var asPayload: [String: Any] {
        if type == "radius" {
            return [
                "type": "radius",
                "center_lat": centerLat ?? 0,
                "center_lng": centerLng ?? 0,
                "radius": radius ?? 0
            ]
        }
        return [
            "type": "freehand",
            "polygon_coords": (polygon ?? []).map { ["lat": $0.lat, "lng": $0.lng] }
        ]
    }

    // Build a draft from a server zone so the editor can show existing zones.
    static func from(_ zone: OrgZone) -> ZoneDraft {
        ZoneDraft(
            type: zone.type,
            centerLat: zone.centerLat,
            centerLng: zone.centerLng,
            radius: zone.radius,
            polygon: zone.polygonCoords
        )
    }
}
