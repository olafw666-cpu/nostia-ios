import Foundation

// MARK: - Adventure Page models (Adventure Page spec §3/§11)
//
// `DailyAdventure` is the AI-generated (or pool-served — the client can't tell,
// by design) daily quest. Distinct from the legacy `Adventure` discovery model.

struct DailyAdventure: Codable, Identifiable {
    let id: Int
    let title: String
    let description: String
    let difficulty: String
    let stepCount: Int
    let points: Int
    let status: String        // active | completed | expired | discarded
    let issuedAt: String?
    let completedAt: String?
    var steps: [DailyAdventureStep]

    enum CodingKeys: String, CodingKey {
        case id, title, description, difficulty, points, status, steps
        case stepCount = "step_count"
        case issuedAt = "issued_at"
        case completedAt = "completed_at"
    }

    var isActive: Bool { status == "active" }
    var allStepsChecked: Bool { steps.allSatisfy(\.checked) }
    var checkedCount: Int { steps.filter(\.checked).count }
    var issuedDate: Date? { AdventureDates.parse(issuedAt) }
}

struct DailyAdventureStep: Codable, Identifiable {
    let order: Int
    let text: String
    var checked: Bool
    var id: Int { order }
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

/// POST /api/adventures/generate — 202 carries job_id, 200 carries the adventure
/// (instant fallback path). Both fields optional so one type decodes either.
struct AdventureGenerateResponse: Codable {
    let jobId: Int?
    let adventure: DailyAdventure?

    enum CodingKeys: String, CodingKey {
        case adventure
        case jobId = "job_id"
    }
}

/// GET /api/adventures/jobs/:id
struct AdventureJobStatus: Codable {
    let status: String        // queued | running | done | error
    let adventure: DailyAdventure?
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

// MARK: - Difficulty (client mirror of the server's §5 table — display only;
// the server re-derives steps/points from the difficulty enum it receives)

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

    var stepCount: Int {
        switch self {
        case .easy: return 3
        case .medium: return 5
        case .advanced: return 8
        }
    }

    var points: Int {
        switch self {
        case .easy: return 25
        case .medium: return 50
        case .advanced: return 100
        }
    }

    var blurb: String {
        switch self {
        case .easy: return "Short, low-effort tasks"
        case .medium: return "Moderate multi-part tasks"
        case .advanced: return "Long-form, multi-part tasks"
        }
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
