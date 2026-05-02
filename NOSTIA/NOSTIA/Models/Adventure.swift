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

struct Event: Codable, Identifiable {
    let id: Int
    var title: String
    var description: String?
    var location: String?
    var eventDate: String?
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

    var formattedDate: String {
        let fmt = ISO8601DateFormatter()
        if let d = fmt.date(from: eventDate ?? "") {
            let out = DateFormatter()
            out.dateFormat = "MMM d, h:mm a"
            return out.string(from: d)
        }
        return eventDate ?? ""
    }

    var formattedDistance: String? {
        guard let d = distance else { return nil }
        return d < 1 ? "\(Int(d * 1000))m" : String(format: "%.1fkm", d)
    }
}
