import Foundation

struct Trip: Codable, Identifiable {
    let id: Int
    var title: String
    var destination: String
    var description: String?
    var startDate: String?
    var endDate: String?
    var participants: [TripParticipant]?
    var createdAt: String?

    var participantCount: Int { participants?.count ?? 0 }

    var formattedDates: String {
        guard let start = startDate, let end = endDate else { return "No dates set" }
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        let outFmt = DateFormatter()
        outFmt.dateFormat = "MMM d"
        if let s = fmt.date(from: start), let e = fmt.date(from: end) {
            return "\(outFmt.string(from: s)) – \(outFmt.string(from: e))"
        }
        return "\(start) – \(end)"
    }
}

struct TripParticipant: Codable, Identifiable {
    let id: Int
    let userId: Int
    let name: String?
    let username: String?
}

struct CreateTripBody: Encodable {
    let title: String
    let destination: String
    let description: String?
    let startDate: String?
    let endDate: String?
}
