import Foundation

// MARK: - Adventure Page models
//
// `DailyAdventure` is the pool-served daily adventure: a measured physical challenge
// with a step target and a walking-distance target. Distinct from the legacy
// `Adventure` discovery model.

struct DailyAdventure: Codable, Identifiable {
    let id: Int
    let title: String
    let description: String
    let difficulty: String
    let points: Int
    let status: String        // active | completed | expired | discarded
    let issuedAt: String?
    let completedAt: String?

    // Optional because pre-rework rows serialize as null. A row with no targets is
    // history — render it without the progress section rather than as 0/0.
    let stepsTarget: Int?
    let distanceTargetM: Int?
    let stepsProgress: Int
    let distanceProgressM: Int
    let targetsMet: Bool

    enum CodingKeys: String, CodingKey {
        case id, title, description, difficulty, points, status
        case issuedAt = "issued_at"
        case completedAt = "completed_at"
        case stepsTarget = "steps_target"
        case distanceTargetM = "distance_target_m"
        case stepsProgress = "steps_progress"
        case distanceProgressM = "distance_progress_m"
        case targetsMet = "targets_met"
    }

    /// Progress fields default rather than throw. A malformed *present* value fails the
    /// whole enclosing decode — so if a rolled-back server omits them, the synthesized
    /// initializer would leave users with no adventure at all instead of an adventure
    /// with no progress section. Degrade, don't disappear.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(Int.self, forKey: .id)
        title = try c.decode(String.self, forKey: .title)
        description = try c.decode(String.self, forKey: .description)
        difficulty = try c.decode(String.self, forKey: .difficulty)
        points = try c.decode(Int.self, forKey: .points)
        status = try c.decode(String.self, forKey: .status)
        issuedAt = try c.decodeIfPresent(String.self, forKey: .issuedAt)
        completedAt = try c.decodeIfPresent(String.self, forKey: .completedAt)
        stepsTarget = try c.decodeIfPresent(Int.self, forKey: .stepsTarget)
        distanceTargetM = try c.decodeIfPresent(Int.self, forKey: .distanceTargetM)
        stepsProgress = try c.decodeIfPresent(Int.self, forKey: .stepsProgress) ?? 0
        distanceProgressM = try c.decodeIfPresent(Int.self, forKey: .distanceProgressM) ?? 0
        targetsMet = try c.decodeIfPresent(Bool.self, forKey: .targetsMet) ?? false
    }

    var isActive: Bool { status == "active" }
    var issuedDate: Date? { AdventureDates.parse(issuedAt) }

    /// The 24h window closes on the client too: past it, progress stops accruing
    /// (the server clamps to the same boundary).
    var windowEnd: Date? { issuedDate?.addingTimeInterval(24 * 3600) }

    /// Only measured rows have a progress section to draw.
    var isMeasured: Bool { stepsTarget != nil && distanceTargetM != nil }

    var stepsFraction: Double {
        guard let t = stepsTarget, t > 0 else { return 0 }
        return min(1, Double(stepsProgress) / Double(t))
    }

    var distanceFraction: Double {
        guard let t = distanceTargetM, t > 0 else { return 0 }
        return min(1, Double(distanceProgressM) / Double(t))
    }
}

/// GET /api/adventures/current — the single source of truth for AdventureView.
struct AdventureCurrentState: Codable {
    let adventure: DailyAdventure?
    let nextAvailableAt: String?
    let pointsBalance: Int?

    enum CodingKeys: String, CodingKey {
        case adventure
        case nextAvailableAt = "next_available_at"
        case pointsBalance = "points_balance"
    }

    var nextAvailableDate: Date? { AdventureDates.parse(nextAvailableAt) }
}

/// POST /api/adventures/generate — always 200 with the adventure. Generation is a
/// draw from the pre-generated pool, so there is no job to poll.
struct AdventureGenerateResponse: Codable {
    let adventure: DailyAdventure
}

/// POST /api/adventures/:id/progress
struct AdventureProgressResponse: Codable {
    let adventure: DailyAdventure
}

/// POST /api/adventures/:id/complete
struct AdventureCompleteResponse: Codable {
    let adventure: DailyAdventure
    let pointsAwarded: Int
    let pointsBalance: Int

    enum CodingKeys: String, CodingKey {
        case adventure
        case pointsAwarded = "points_awarded"
        case pointsBalance = "points_balance"
    }
}

// MARK: - Cosmetics store (spec §9)

struct CosmeticCatalog: Codable {
    let pointsBalance: Int
    let items: [CosmeticItem]

    enum CodingKeys: String, CodingKey {
        case items
        case pointsBalance = "points_balance"
    }
}

struct CosmeticItem: Codable, Identifiable {
    let id: Int
    let key: String           // theme_blue | theme_pink | theme_dark_red
    let kind: String
    let price: Int
    let owned: Bool
}

struct CosmeticPurchaseResponse: Codable {
    let unlocked: String
    let pointsBalance: Int

    enum CodingKeys: String, CodingKey {
        case unlocked
        case pointsBalance = "points_balance"
    }
}

// MARK: - Difficulty (client mirror of the server's points table — display only; the
// server re-derives points from the difficulty enum it receives. Targets are NOT
// mirrored: they vary per adventure and only the served row knows them.)

enum AdventureDifficulty: String, CaseIterable, Identifiable {
    case easy, medium, advanced

    var id: String { rawValue }

    var label: String {
        switch self {
        case .easy: return "Easy"
        case .medium: return "Medium"
        case .advanced: return "Advanced"
        }
    }

    var points: Int {
        switch self {
        case .easy: return 25
        case .medium: return 50
        case .advanced: return 100
        }
    }

    /// Indicative ranges only — the actual pair comes from the pool row. Mirrors
    /// TARGET_ENVELOPES in services/adventureTargets.js.
    var blurb: String {
        switch self {
        case .easy: return "About 2–5k steps · 1.5–4 km"
        case .medium: return "About 6–12k steps · 5–10 km"
        case .advanced: return "About 13–25k steps · 10–18 km"
        }
    }
}

// MARK: - Formatting

enum AdventureFormat {
    static func steps(_ n: Int) -> String {
        n >= 1000 ? String(format: "%.1fk", Double(n) / 1000) : "\(n)"
    }

    /// Metric or imperial to match the device locale — a distance target is the whole
    /// point of the feature, so it has to read naturally.
    static func distance(_ meters: Int) -> String {
        let usesMetric = Locale.current.measurementSystem != .us
        if usesMetric {
            return String(format: "%.2f km", Double(meters) / 1000)
        }
        return String(format: "%.2f mi", Double(meters) / 1609.344)
    }
}

// MARK: - Date parsing

/// The API sends ISO 8601 UTC strings; `next_available_at` carries fractional
/// seconds (JS toISOString) while row timestamps don't — try both shapes.
enum AdventureDates {
    private static let fractional: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
    private static let plain = ISO8601DateFormatter()

    static func parse(_ s: String?) -> Date? {
        guard let s, !s.isEmpty else { return nil }
        return fractional.date(from: s) ?? plain.date(from: s)
    }
}
