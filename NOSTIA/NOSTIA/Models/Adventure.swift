import Foundation

struct Adventure: Codable, Identifiable {
    let id: Int
    var title: String
    var description: String?
    var location: String?
    var category: String?
    var difficulty: String?
    var duration: String?
    var price: Double?
    var rating: Double?
    var imageUrl: String?
    var createdAt: String?
}

struct Experience: Codable, Identifiable {
    let id: Int
    var title: String
    var description: String?
    var location: String?
    var latitude: Double?
    var longitude: Double?
    var distance: Double?
    var visibility: String?
    var createdBy: Int?
    var creatorName: String?
    var createdAt: String?
    // D5: how many people marked Visited (replaces the old goingCount).
    var visitedCount: Int?
    // Q-B: tracked silently — not surfaced on the card today.
    var visitingCount: Int?
    // D1: the caller's own status — wire "visited" | "visiting" | nil (cleared).
    var myStatus: String?
    // D4: server-computed average rating + how many ratings it's based on.
    var avgRating: Double?
    var ratingCount: Int?
    // D3: the caller's own submitted rating (0...5 in 0.5 steps), nil when never rated.
    var myRating: Double?
    var flyerImage: String?
    var tags: [String]?
    // Non-nil when this experience belongs to an organization (members-only). Lets the map
    // bucket it under the Orgs filter and style its pin distinctly.
    var orgId: Int?

    var isOrgExperience: Bool { orgId != nil }

    var formattedDistance: String? {
        guard let d = distance else { return nil }
        return d < 1 ? "\(Int(d * 1000))m" : String(format: "%.1fkm", d)
    }

    /// Average rating formatted to one decimal, e.g. "2.5". Nil when there are no ratings.
    var formattedAvgRating: String? {
        guard let avg = avgRating, (ratingCount ?? 0) > 0 else { return nil }
        return String(format: "%.1f", avg)
    }
}

// MARK: - Experience tags (D3)

/// Fixed preset activity tags — no user-created tags. Single source of truth, reused by
/// the create forms (multi-select picker) and the map tag-search bar.
let experienceTags: [String] = [
    "water", "outdoors", "hiking", "food", "culture", "music",
    "sports", "nightlife", "art", "fitness", "nature", "social"
]

/// Maximum tags a single experience may carry.
let maxExperienceTags = 3

// MARK: - Heatmap (far-out zoom event density)

/// One geographic cell of the heatmap density grid. `intensity` is normalized over all
/// qualifying platform events (0...1) per the heatmap spec.
struct HeatmapCell: Codable, Identifiable {
    let lat: Double
    let lng: Double
    let intensity: Double
    // Stable id from the cell coordinates (the API does not send one).
    var id: String { "\(lat),\(lng)" }
}

struct HeatmapResponse: Codable {
    let cells: [HeatmapCell]
    let total: Int
}
