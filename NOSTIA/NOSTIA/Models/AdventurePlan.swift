import Foundation

// MARK: - Adventure plan models (Product Definition v2 §4.5)
//
// An `AdventurePlan` is a composed outing: a named, sequenced 2–4-stop route
// with walking legs and timings, generated server-side from the owned places
// layer. Distinct from `DailyAdventure` (the pedometer quest) — the two ship
// side by side until the IA collapse retires the pedometer surface.

struct AdventurePlan: Codable, Identifiable, Equatable {
    let id: Int
    let title: String
    let description: String
    let state: String          // generated | provisional | verified | expired | archived
    let vibe: String?
    let budget: String?
    let groupSize: Int?
    let windowStart: String?
    let windowMinutes: Int
    let rerollCount: Int
    let tripId: Int?
    let createdAt: String?
    let expiresAt: String?
    let stops: [PlanStop]
    let members: [PlanMember]

    enum CodingKeys: String, CodingKey {
        case id, title, description, state, vibe, budget, stops, members
        case groupSize = "group_size"
        case windowStart = "window_start"
        case windowMinutes = "window_minutes"
        case rerollCount = "reroll_count"
        case tripId = "trip_id"
        case createdAt = "created_at"
        case expiresAt = "expires_at"
    }

    var isGenerated: Bool { state == "generated" }
    var isLive: Bool { state == "generated" || state == "provisional" || state == "verified" }

    /// Legs + dwells — the whole outing, minutes.
    var totalMinutes: Int {
        stops.reduce(0) { $0 + $1.legWalkMinutes + $1.dwellMinutes }
    }

    var totalWalkMeters: Int {
        stops.reduce(0) { $0 + $1.legMeters }
    }
}

struct PlanStop: Codable, Identifiable, Equatable {
    let id: Int
    let ord: Int
    let placeId: Int?
    let name: String
    let lat: Double
    let lng: Double
    let category: String?
    let plannedArrival: String?
    let dwellMinutes: Int
    let legMeters: Int
    let legWalkMinutes: Int
    let status: String         // planned | dropped | completed

    enum CodingKeys: String, CodingKey {
        case id, ord, name, lat, lng, category, status
        case placeId = "place_id"
        case plannedArrival = "planned_arrival"
        case dwellMinutes = "dwell_minutes"
        case legMeters = "leg_meters"
        case legWalkMinutes = "leg_walk_minutes"
    }

    var arrivalDate: Date? { PlanDates.parse(plannedArrival) }

    /// SF Symbol per composition bucket (poi_category_map.json vocabulary).
    var symbolName: String {
        switch category {
        case "coffee": return "cup.and.saucer.fill"
        case "dessert": return "birthday.cake.fill"
        case "bar": return "wineglass.fill"
        case "food": return "fork.knife"
        case "park": return "tree.fill"
        case "scenic": return "mountain.2.fill"
        case "culture": return "theatermasks.fill"
        case "activity": return "figure.bowling"
        case "shop": return "bag.fill"
        default: return "mappin.circle.fill"
        }
    }
}

struct PlanMember: Codable, Identifiable, Equatable {
    let userId: Int
    let username: String
    let name: String?
    let role: String           // owner | member

    var id: Int { userId }

    enum CodingKeys: String, CodingKey {
        case username, name, role
        case userId = "user_id"
    }
}

/// Shared envelope for generate / reroll / current / accept. A dead zone
/// (§13 degradation) is an honest `plan: nil` + reason, never an error.
struct PlanResponse: Codable {
    let plan: AdventurePlan?
    let reason: String?
}

// MARK: - Date parsing

/// Plan timestamps use the app-wide UTC "yyyy-MM-dd HH:mm:ss" wire format
/// (same as experiences), not ISO 8601.
enum PlanDates {
    private static let wire: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm:ss"
        f.timeZone = TimeZone(identifier: "UTC")
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    static func parse(_ s: String?) -> Date? {
        guard let s, !s.isEmpty else { return nil }
        return wire.date(from: s)
    }
}

// MARK: - Vibe refinements (§4.4: optional, defaulted, skippable)

enum PlanVibe: String, CaseIterable, Identifiable {
    case chill, lively, outdoors, artsy, foodie

    var id: String { rawValue }

    var label: String {
        switch self {
        case .chill: return "Chill"
        case .lively: return "Lively"
        case .outdoors: return "Outdoors"
        case .artsy: return "Artsy"
        case .foodie: return "Foodie"
        }
    }

    var symbolName: String {
        switch self {
        case .chill: return "moon.stars.fill"
        case .lively: return "flame.fill"
        case .outdoors: return "leaf.fill"
        case .artsy: return "paintpalette.fill"
        case .foodie: return "fork.knife"
        }
    }
}
