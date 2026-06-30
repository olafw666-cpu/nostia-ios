import Combine
import Foundation
import SwiftUI

@MainActor
final class FeedViewModel: ObservableObject {
    @Published var posts: [FeedPost] = []
    @Published var isLoading = false

    // Session-only cycle-out: a post dwelled on (~5s on screen) is marked seen; once it
    // scrolls out of view it's removed so fresh content takes its place. Resets when the
    // app (and this VM) is recreated. Only ever applied to the home feed (loadFeed), never
    // to profile posts (loadUserPosts).
    static let seenDwellNanos: UInt64 = 5_000_000_000  // ~5 seconds
    private var seenIds: Set<Int> = []
    func markSeen(_ id: Int) { seenIds.insert(id) }
    func hasSeen(_ id: Int) -> Bool { seenIds.contains(id) }
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

    // Moderation state (report / block)
    @Published var reportTarget: ReportTarget?
    @Published var moderationMessage: String?

    func loadFeed() async {
        if let cached: [FeedPost] = await CacheManager.shared.get(CacheKey.homeFeed) {
            posts = displayOrder(cached)
        } else {
            isLoading = true
        }
        do {
            let fresh = try await FeedAPI.shared.getUserFeed()
            posts = displayOrder(fresh)
            await CacheManager.shared.set(CacheKey.homeFeed, value: fresh)
        } catch {
            if posts.isEmpty { errorMessage = error.localizedDescription }
        }
        isLoading = false
    }

    // Hide already-seen posts when unseen content remains (they've cycled out); if every
    // post has been seen, show them anyway so the feed is never empty.
    private func displayOrder(_ all: [FeedPost]) -> [FeedPost] {
        let unseen = all.filter { !seenIds.contains($0.id) }
        return unseen.isEmpty ? all : unseen
    }

    // Called when a seen post scrolls out of view: remove it so fresh content takes its
    // place. Guarded so the feed is never emptied; tops up from the server when low.
    func cycleOut(_ id: Int) async {
        guard seenIds.contains(id),
              posts.contains(where: { $0.id != id && !seenIds.contains($0.id) }),
              let idx = posts.firstIndex(where: { $0.id == id }) else { return }
        withAnimation(.easeInOut(duration: 0.25)) {
            _ = posts.remove(at: idx)
        }
        if posts.filter({ !seenIds.contains($0.id) }).count <= 2 {
            await topUp()
        }
    }

    // Pull fresh content and append any posts not already shown or seen, so the cycle can
    // continue without the user manually refreshing.
    private func topUp() async {
        guard let fresh = try? await FeedAPI.shared.getUserFeed() else { return }
        await CacheManager.shared.set(CacheKey.homeFeed, value: fresh)
        let existing = Set(posts.map { $0.id })
        let additions = fresh.filter { !existing.contains($0.id) && !seenIds.contains($0.id) }
        if !additions.isEmpty { posts.append(contentsOf: additions) }
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
        let trimmedContent = newPostContent.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedContent.isEmpty || newPostImageData != nil else { return }
        isSubmitting = true
        do {
            _ = try await FeedAPI.shared.createPost(
                content: trimmedContent.isEmpty ? nil : trimmedContent,
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
            await CacheManager.shared.invalidate(CacheKey.userPosts(post.userId))
        } catch {
            posts.insert(post, at: idx)
        }
    }

    func editPost(post: FeedPost, newContent: String) async {
        guard let idx = posts.firstIndex(where: { $0.id == post.id }) else { return }
        let snapshot = posts[idx]
        posts[idx].content = newContent
        do {
            let updated = try await FeedAPI.shared.updatePost(id: post.id, content: newContent)
            posts[idx] = updated
            await CacheManager.shared.invalidate(CacheKey.homeFeed)
        } catch {
            posts[idx] = snapshot
        }
    }

    func adminDeletePost(post: FeedPost) async {
        guard let idx = posts.firstIndex(where: { $0.id == post.id }) else { return }
        posts.remove(at: idx)
        do {
            try await FeedAPI.shared.adminDeletePost(id: post.id)
            await CacheManager.shared.invalidate(CacheKey.homeFeed)
            await CacheManager.shared.invalidate(CacheKey.userPosts(post.userId))
        } catch {
            posts.insert(post, at: idx)
        }
    }

    // Blocks a user and removes their content from the local feed instantly,
    // mirroring the optimistic deletePost flow. Rolls back on API failure.
    func blockUser(userId: Int, username: String? = nil) async {
        let postsSnapshot = posts
        let commentsSnapshot = comments
        posts.removeAll { $0.userId == userId }
        comments.removeAll { $0.userId == userId }
        do {
            try await ModerationAPI.shared.blockUser(userId: userId)
            await CacheManager.shared.invalidate(CacheKey.homeFeed)
            await CacheManager.shared.invalidate(CacheKey.userPosts(userId))
            await CacheManager.shared.invalidatePrefix("comments:")
            await CacheManager.shared.invalidate(CacheKey.followersList)
            await CacheManager.shared.invalidate(CacheKey.followingList)
            await CacheManager.shared.invalidate(CacheKey.experienceList)
            moderationMessage = username.map { "@\($0) has been blocked" } ?? "User blocked"
        } catch {
            posts = postsSnapshot
            comments = commentsSnapshot
            errorMessage = error.localizedDescription
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
