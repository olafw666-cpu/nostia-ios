import Foundation

struct Trip: Codable, Identifiable, Hashable {
    let id: Int
    var title: String
    var destination: String?
    var description: String?
    var startDate: String?
    var endDate: String?
    var participants: [TripParticipant]?
    var createdAt: String?
    var vaultLeaderId: Int?
    // Sum of all expenses logged against this vault (server-computed). Shown on the list card.
    var vaultTotal: Double?

    var participantCount: Int { participants?.count ?? 0 }
    var activeParticipants: [TripParticipant] { participants?.filter { $0.status != "kicked" } ?? [] }

    /// The vault's total expenses, compactly formatted (see `formatCompactCurrency`).
    var formattedVaultTotal: String { formatCompactCurrency(vaultTotal ?? 0) }

    var formattedDates: String {
        guard let start = startDate, let end = endDate else { return "" }
        let fmt = DateFormatter(); fmt.dateFormat = "yyyy-MM-dd"
        let out = DateFormatter(); out.dateFormat = "MMM d"
        if let s = fmt.date(from: start), let e = fmt.date(from: end) {
            return "\(out.string(from: s)) – \(out.string(from: e))"
        }
        return "\(start) – \(end)"
    }
}

struct TripParticipant: Codable, Identifiable, Hashable {
    let id: Int
    let name: String?
    let username: String?
    let role: String?
    var status: String?

    var userId: Int { id }
    var isKicked: Bool { status == "kicked" }
}

/// Compact USD formatting for amounts shown in tight spaces (e.g. vault list cards).
/// Shows the full amount with cents and grouping while the whole-dollar part is at most
/// six digits (under $1,000,000) — "$420.00", "$12,345.67" — then abbreviates with a
/// single-decimal suffix: "$1.2M", "$3.4B", "$5.6T".
func formatCompactCurrency(_ amount: Double) -> String {
    let v = abs(amount)

    // One decimal, dropping a trailing ".0" so "$1.0M" reads as "$1M".
    func trimmed(_ x: Double) -> String {
        let s = String(format: "%.1f", x)
        return s.hasSuffix(".0") ? String(s.dropLast(2)) : s
    }

    switch v {
    case 1_000_000_000_000...: return "$\(trimmed(v / 1_000_000_000_000))T"
    case 1_000_000_000...:     return "$\(trimmed(v / 1_000_000_000))B"
    case 1_000_000...:         return "$\(trimmed(v / 1_000_000))M"
    default:
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.minimumFractionDigits = 2
        f.maximumFractionDigits = 2
        return "$" + (f.string(from: NSNumber(value: v)) ?? String(format: "%.2f", v))
    }
}

struct TripChatMessage: Codable, Identifiable {
    let id: Int
    let tripId: Int
    let senderId: Int
    let content: String
    let createdAt: String
    let senderName: String?
    let senderUsername: String?
    let isSystem: Bool?
}
