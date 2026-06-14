import Combine
import Foundation

/// Drives an event's chat thread. Mirrors the post-comments flow
/// (FeedViewModel.loadComments/submitComment) with light 5s polling so the
/// thread feels live, like a chat.
@MainActor
final class EventChatViewModel: ObservableObject {
    @Published var comments: [FeedComment] = []
    @Published var newComment = ""
    @Published var isLoading = false
    @Published var isSubmitting = false
    @Published var errorMessage: String?

    // Moderation state (report / block) — reused by CommentRow.
    @Published var reportTarget: ReportTarget?
    @Published var moderationMessage: String?

    private var pollTask: Task<Void, Never>?

    func initialize(eventId: Int) async {
        isLoading = true
        await load(eventId: eventId)
        isLoading = false
        startPolling(eventId: eventId)
    }

    func load(eventId: Int) async {
        do {
            comments = try await AdventuresAPI.shared.getEventComments(eventId: eventId)
        } catch {
            if comments.isEmpty { errorMessage = error.localizedDescription }
        }
    }

    func submit(eventId: Int) async {
        let text = newComment.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }
        isSubmitting = true
        newComment = ""
        do {
            let comment = try await AdventuresAPI.shared.addEventComment(eventId: eventId, content: text)
            comments.append(comment)
        } catch {
            errorMessage = error.localizedDescription
            newComment = text // Restore on failure
        }
        isSubmitting = false
    }

    func blockUser(userId: Int, username: String) async {
        let snapshot = comments
        comments.removeAll { $0.userId == userId }
        do {
            try await ModerationAPI.shared.blockUser(userId: userId)
            moderationMessage = "@\(username) has been blocked"
        } catch {
            comments = snapshot
            errorMessage = error.localizedDescription
        }
    }

    func startPolling(eventId: Int) {
        pollTask?.cancel()
        pollTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 5_000_000_000)
                if !Task.isCancelled { await load(eventId: eventId) }
            }
        }
    }

    func stopPolling() {
        pollTask?.cancel()
        pollTask = nil
    }
}
