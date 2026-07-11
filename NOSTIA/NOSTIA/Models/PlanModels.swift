import Foundation

// MARK: - Trip plan (tasks + date poll)

/// GET /trips/:id/plan — everything the Plan tab renders.
struct TripPlanResponse: Codable {
    let tasks: [TripTask]
    let dateOptions: [TripDateOption]
}

/// A claimable checklist item ("Flights — claimed by Sam").
struct TripTask: Codable, Identifiable, Equatable {
    let id: Int
    let tripId: Int
    let title: String
    let createdBy: Int
    let claimedBy: Int?
    let done: Bool
    let createdAt: String
    let creatorName: String?
    let claimerName: String?
    let claimerUsername: String?
}

/// A proposed trip date with vote count and whether I voted for it.
struct TripDateOption: Codable, Identifiable, Equatable {
    let id: Int
    let tripId: Int
    let date: String        // yyyy-MM-dd
    let createdBy: Int
    let votes: Int
    let voted: Bool

    /// "Sat, Aug 22" style display of the wire date.
    var displayDate: String {
        let parser = DateFormatter()
        parser.dateFormat = "yyyy-MM-dd"
        parser.locale = Locale(identifier: "en_US_POSIX")
        guard let d = parser.date(from: date) else { return date }
        let out = DateFormatter()
        out.dateFormat = "EEE, MMM d"
        return out.string(from: d)
    }
}
