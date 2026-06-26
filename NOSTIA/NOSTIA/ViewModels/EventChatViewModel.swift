import Combine
import Foundation

/// Drives an experience's chat thread. Mirrors the post-comments flow
/// (FeedViewModel.loadComments/submitComment) with light 5s polling so the
/// thread feels live, like a chat.
@MainActor
final class ExperienceChatViewModel: ObservableObject {
    @Published var comments: [FeedComment] = []
    @Published var newComment = ""
    @Published var isLoading = false
    @Published var isSubmitting = false
    @Published var errorMessage: String?

    // Moderation state (report / block) — reused by CommentRow.
    @Published var reportTarget: ReportTarget?
    @Published var moderationMessage: String?

    private var pollTask: Task<Void, Never>?

    func initialize(experienceId: Int) async {
        isLoading = true
        await load(experienceId: experienceId)
        isLoading = false
        startPolling(experienceId: experienceId)
    }

    func load(experienceId: Int) async {
        do {
            comments = try await ExperiencesAPI.shared.getExperienceComments(experienceId: experienceId)
        } catch {
            if comments.isEmpty { errorMessage = error.localizedDescription }
        }
    }

    func submit(experienceId: Int) async {
        let text = newComment.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }
        isSubmitting = true
        newComment = ""
        do {
            let comment = try await ExperiencesAPI.shared.addExperienceComment(experienceId: experienceId, content: text)
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

    func startPolling(experienceId: Int) {
        pollTask?.cancel()
        pollTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 5_000_000_000)
                if !Task.isCancelled { await load(experienceId: experienceId) }
            }
        }
    }

    func stopPolling() {
        pollTask?.cancel()
        pollTask = nil
    }
}
