import Combine
import Foundation
import SwiftUI

@MainActor
final class FeedViewModel: ObservableObject {
    @Published var posts: [FeedPost] = []
    @Published var isLoading = false
    @Published var isSubmitting = false
    @Published var errorMessage: String?

    // Double-tap guards (per spec §4)
    @Published var likingPostIds: Set<Int> = []
    @Published var dislikingPostIds: Set<Int> = []

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
        if let cached: [FeedPost] = await CacheManager.shared.get(CacheKey.homeFeed) {
            posts = cached
        } else {
            isLoading = true
        }
        do {
            let fresh = try await FeedAPI.shared.getUserFeed()
            posts = fresh
            await CacheManager.shared.set(CacheKey.homeFeed, value: fresh)
        } catch {
            if posts.isEmpty { errorMessage = error.localizedDescription }
        }
        isLoading = false
    }

    func loadUserPosts(userId: Int) async {
        let key = CacheKey.userPosts(userId)
        if let cached: [FeedPost] = await CacheManager.shared.get(key) {
            posts = cached
        } else {
            isLoading = true
        }
        do {
            let fresh = try await FeedAPI.shared.getUserPosts(userId: userId)
            posts = fresh
            await CacheManager.shared.set(key, value: fresh)
        } catch {
            if posts.isEmpty { errorMessage = error.localizedDescription }
        }
        isLoading = false
    }

    func createPost() async {
        guard newPostImageData != nil else { return }
        isSubmitting = true
        do {
            _ = try await FeedAPI.shared.createPost(
                content: newPostContent.isEmpty ? nil : newPostContent,
                imageData: newPostImageData
            )
            await CacheManager.shared.invalidate(CacheKey.homeFeed)
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
        guard !likingPostIds.contains(post.id),
              let idx = posts.firstIndex(where: { $0.id == post.id }) else { return }
        likingPostIds.insert(post.id)
        let snapshot = posts[idx]
        let wasLiked = posts[idx].isLiked == true

        posts[idx].isLiked = !wasLiked
        posts[idx].likeCount += wasLiked ? -1 : 1
        if !wasLiked && posts[idx].isDisliked == true {
            posts[idx].isDisliked = false
            posts[idx].dislikeCount = max(0, posts[idx].dislikeCount - 1)
        }

        do {
            if wasLiked { try await FeedAPI.shared.unlikePost(id: post.id) }
            else        { try await FeedAPI.shared.likePost(id: post.id)   }
        } catch {
            if let still = posts.firstIndex(where: { $0.id == post.id }) {
                posts[still] = snapshot
            }
        }
        likingPostIds.remove(post.id)
    }

    func toggleDislike(post: FeedPost) async {
        guard !dislikingPostIds.contains(post.id),
              let idx = posts.firstIndex(where: { $0.id == post.id }) else { return }
        dislikingPostIds.insert(post.id)
        let snapshot = posts[idx]
        let wasDisliked = posts[idx].isDisliked == true

        posts[idx].isDisliked = !wasDisliked
        posts[idx].dislikeCount += wasDisliked ? -1 : 1
        if !wasDisliked && posts[idx].isLiked == true {
            posts[idx].isLiked = false
            posts[idx].likeCount = max(0, posts[idx].likeCount - 1)
        }

        do {
            if wasDisliked { try await FeedAPI.shared.undislikePost(id: post.id) }
            else           { try await FeedAPI.shared.dislikePost(id: post.id)   }
        } catch {
            if let still = posts.firstIndex(where: { $0.id == post.id }) {
                posts[still] = snapshot
            }
        }
        dislikingPostIds.remove(post.id)
    }

    func deletePost(post: FeedPost) async {
        guard let idx = posts.firstIndex(where: { $0.id == post.id }) else { return }
        posts.remove(at: idx)
        do {
            try await FeedAPI.shared.deletePost(id: post.id)
            await CacheManager.shared.invalidate(CacheKey.homeFeed)
        } catch {
            posts.insert(post, at: idx)
        }
    }

    func loadComments(for post: FeedPost) async {
        selectedPost = post
        let key = CacheKey.comments(post.id)
        if let cached: [FeedComment] = await CacheManager.shared.get(key) {
            comments = cached
        } else {
            isLoadingComments = true
        }
        do {
            let fresh = try await FeedAPI.shared.getComments(postId: post.id)
            comments = fresh
            await CacheManager.shared.set(key, value: fresh)
        } catch {
            if comments.isEmpty { errorMessage = error.localizedDescription }
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
            await CacheManager.shared.invalidate(CacheKey.comments(postId))
        } catch {}
        isSubmittingComment = false
    }
}
