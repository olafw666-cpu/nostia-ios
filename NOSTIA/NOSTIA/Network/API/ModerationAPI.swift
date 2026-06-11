import Foundation

final class ModerationAPI {
    static let shared = ModerationAPI()
    private let client = APIClient.shared
    private init() {}

    func blockUser(userId: Int) async throws {
        try await client.requestVoid("/blocks", method: "POST", body: ["userId": userId])
    }

    func unblockUser(userId: Int) async throws {
        try await client.requestVoid("/blocks/\(userId)", method: "DELETE")
    }

    func getBlockedUsers() async throws -> [BlockedUser] {
        try await client.request("/blocks")
    }

    func report(contentType: String, contentId: Int, reason: ReportReason, details: String?) async throws {
        var body: [String: Any] = [
            "contentType": contentType,
            "contentId": contentId,
            "reason": reason.rawValue
        ]
        if let details, !details.trimmingCharacters(in: .whitespaces).isEmpty {
            body["details"] = details
        }
        try await client.requestVoid("/reports", method: "POST", body: body)
    }
}
