import Foundation
import SwiftUI

@MainActor
final class FeedViewModel: ObservableObject {
    @Published var posts: [FeedPost] = []
    @Published var isLoading = false
    @Published var isSubmitting = false
    @Published var errorMessage: String?

    // Create post state
    @Published var newPostContent = ""
    @Published var newPostImageData: String?
    @Published var showCreateSheet = false

    // Comments state
    @Published var selectedPost: FeedPost?
    @Published var comments: [FeedComment] = []
    @Published var newComment = ""
    @Published var isLoadingComments = false
    @Published var isSubmittingComment = false

    func loadFeed() async {
        isLoading = true
        errorMessage = nil
        do {
            posts = try await FeedAPI.shared.getUserFeed()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func createPost() async {
        guard !newPostContent.trimmingCharacters(in: .whitespaces).isEmpty || newPostImageData != nil else { return }
        isSubmitting = true
        do {
            _ = try await FeedAPI.shared.createPost(
                content: newPostContent.isEmpty ? nil : newPostContent,
                imageData: newPostImageData
            )
            // Reload to get full post data (with username, etc.)
            await loadFeed()
            newPostContent = ""
            newPostImageData = nil
            showCreateSheet = false
        } catch {
            errorMessage = error.localizedDescription
        }
        isSubmitting = false
    }

    func toggleLike(post: FeedPost) async {
        guard let idx = posts.firstIndex(where: { $0.id == post.id }) else { return }
        let wasLiked = posts[idx].isLiked == true
        do {
            if wasLiked {
                try await FeedAPI.shared.unlikePost(id: post.id)
            } else {
                try await FeedAPI.shared.likePost(id: post.id)
            }
            await loadFeed()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func deletePost(id: Int) async {
        do {
            try await FeedAPI.shared.deletePost(id: id)
            posts.removeAll { $0.id == id }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func loadComments(for post: FeedPost) async {
        selectedPost = post
        isLoadingComments = true
        do {
            comments = try await FeedAPI.shared.getComments(postId: post.id)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoadingComments = false
    }

    func submitComment(postId: Int) async {
        let text = newComment.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }
        isSubmittingComment = true
        do {
            let comment = try await FeedAPI.shared.addComment(postId: postId, content: text)
            comments.append(comment)
            newComment = ""
            // Update comment count in post list
            if posts.firstIndex(where: { $0.id == postId }) != nil {
                await loadFeed()
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        isSubmittingComment = false
    }
}
