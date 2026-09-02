import Foundation

/// Serialization plumbing for the on-device demo backend.
///
/// `DemoBackend` hands `APIClient` raw `Data`, exactly as `URLSession` would, so every
/// decode path, error type and cache in the app stays untouched. That leaves one real
/// problem: producing bytes whose keys match what each model's decoder expects. The
/// models are not consistent — `User` is snake_case for six keys while `isDev` is not,
/// the whole plan/adventure family is snake_case, and everything else is camelCase.
///
/// Rather than hand-write JSON and hope, we let the models do it: `CodingKeys` are
/// bidirectional, so encoding a stored `Trip` with `JSONEncoder` reproduces precisely
/// the keys `Trip`'s own decoder reads back. Fixtures are therefore typed values, and
/// `body(_:)` is the single place they become bytes.
nonisolated enum DemoJSON {

    // MARK: - Encoding

    static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        // Deliberately no `dateEncodingStrategy`: not one Codable model in this app
        // declares a `Date` property. Every timestamp travels as a `String` and is
        // parsed ad hoc by the view that shows it, which is why the formatters below
        // exist and why fixtures must pick the right one per field.
        return e
    }()

    static let decoder = JSONDecoder()

    /// Response bytes for a typed fixture.
    static func body<T: Encodable>(_ value: T) throws -> Data {
        try encoder.encode(value)
    }

    /// Response bytes for a hand-built object. Needed only for the handful of response
    /// types the app declares `Decodable`-only (so they cannot be encoded), plus the
    /// three envelopes declared *inside* a function body, which have no nameable type.
    static func body(object: Any) throws -> Data {
        try JSONSerialization.data(withJSONObject: object)
    }

    /// An empty 200 body, for the `requestVoid` endpoints.
    static var empty: Data { Data("{}".utf8) }

    // MARK: - Building typed fixtures that have private stored properties

    /// Builds a model from a wire-shaped dictionary by round-tripping it through the
    /// model's own decoder.
    ///
    /// `User` and `ConsentStatus` keep private stored properties (`data_not_sold`,
    /// `isDev`, `has_created_experience`, the consent 0/1 ints), which makes their
    /// memberwise initialisers private too — they cannot be constructed from here at
    /// all. Decoding is the only door in, and it has the pleasant side effect of
    /// proving the fixture's keys are right at seed time rather than at render time.
    static func make<T: Decodable>(_ type: T.Type, _ dict: [String: Any]) -> T {
        do {
            return try decoder.decode(T.self, from: JSONSerialization.data(withJSONObject: dict))
        } catch {
            // A malformed fixture is a programming error, not a runtime condition: it
            // would otherwise surface as a blank screen much later, far from the cause.
            fatalError("Demo fixture for \(T.self) does not decode: \(error)\n\(dict)")
        }
    }

    // MARK: - Dates
    //
    // Three formats, and the choice is not cosmetic. Several screens parse with a bare
    // `ISO8601DateFormatter()` and render an EMPTY STRING on mismatch rather than
    // failing loudly, so a timestamp in the wrong shape looks like a UI bug.
    //
    //   iso    — Message, NostiaNotification, ContactInviteRecord, DailyAdventure
    //   stamp  — Experience.eventDate, every AdventurePlan/PlanStop time, OrgMember
    //   day    — Trip start/end, TripDateOption, VaultEntry, UnpaidSplit, CrashPad

    private static let isoFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    private static func utc(_ format: String) -> DateFormatter {
        let f = DateFormatter()
        f.dateFormat = format
        f.timeZone = TimeZone(identifier: "UTC")
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }

    private static let stampFormatter = utc("yyyy-MM-dd HH:mm:ss")
    private static let dayFormatter = utc("yyyy-MM-dd")

    /// `2026-09-01T14:22:00Z`
    static func iso(_ date: Date) -> String { isoFormatter.string(from: date) }
    /// `2026-09-01 14:22:00` — the shape SQLite's CURRENT_TIMESTAMP produces.
    static func stamp(_ date: Date) -> String { stampFormatter.string(from: date) }
    /// `2026-09-01`
    static func day(_ date: Date) -> String { dayFormatter.string(from: date) }

    // MARK: - Relative time helpers
    //
    // Seed content is written relative to first launch so a demo never shows stale
    // dates — a feed of week-old posts is the fastest way to look abandoned.

    static func ago(minutes: Int = 0, hours: Int = 0, days: Int = 0) -> Date {
        Date().addingTimeInterval(-Double(minutes * 60 + hours * 3600 + days * 86_400))
    }

    static func ahead(minutes: Int = 0, hours: Int = 0, days: Int = 0) -> Date {
        Date().addingTimeInterval(Double(minutes * 60 + hours * 3600 + days * 86_400))
    }
}
