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
    var goingCount: Int?
    var myRsvp: String?
    var flyerImage: String?
    var tags: [String]?

    var formattedDistance: String? {
        guard let d = distance else { return nil }
        return d < 1 ? "\(Int(d * 1000))m" : String(format: "%.1fkm", d)
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
