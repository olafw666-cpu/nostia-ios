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

    var participantCount: Int { participants?.count ?? 0 }
    var activeParticipants: [TripParticipant] { participants?.filter { $0.status != "kicked" } ?? [] }
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

struct TripChatMessage: Codable, Identifiable {
    let id: Int
    let tripId: Int
    let senderId: Int
    let content: String
    let createdAt: String
    let senderName: String?
    let senderUsername: String?
}
