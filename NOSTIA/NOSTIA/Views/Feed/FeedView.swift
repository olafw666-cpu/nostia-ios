import SwiftUI

struct FeedView: View {
    @StateObject private var vm = FeedViewModel()
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var responsive: ResponsiveLayoutManager

    // Per-card dwell timers for session-only cycle-out. A card visible for ~5s is marked
    // seen; once it scrolls off screen it cycles out for fresh content.
    @State private var seenTasks: [Int: Task<Void, Never>] = [:]

    var body: some View {
        Group {
            if vm.isLoading && vm.posts.isEmpty {
                FeedSkeletonView()
            } else if vm.posts.isEmpty {
                EmptyStateView(icon: "photo.on.rectangle.angled", text: "No posts yet", sub: "Be the first to share something!")
            } else {
                ScrollView {
                    LazyVStack(spacing: responsive.spacing(12)) {
                        ForEach(vm.posts) { post in
                            PostCard(
                                post: post,
                                currentUserId: authManager.currentUserId,
                                isCurrentUserDev: authManager.isDev,
                                onLike: { Task { await vm.toggleLike(post: post) } },
                                onDislike: { Task { await vm.toggleDislike(post: post) } },
                                onDelete: {
                                    if authManager.isDev && post.userId != authManager.currentUserId {
                                        Task { await vm.adminDeletePost(post: post) }
                                    } else {
                                        Task { await vm.deletePost(post: post) }
                                    }
                                },
                                onComment: { Task { await vm.loadComments(for: post) } },
                                onReport: { vm.reportTarget = ReportTarget(contentType: "post", contentId: post.id) },
                                onBlockUser: { Task { await vm.blockUser(userId: post.userId, username: post.username) } },
                                isLikeProcessing: vm.likingPostIds.contains(post.id),
                                isDislikeProcessing: vm.dislikingPostIds.contains(post.id)
                            )
                            .onAppear {
                                guard seenTasks[post.id] == nil, !vm.hasSeen(post.id) else { return }
                                seenTasks[post.id] = Task {
                                    try? await Task.sleep(nanoseconds: FeedViewModel.seenDwellNanos)
                                    if !Task.isCancelled { vm.markSeen(post.id) }
                                }
                            }
                            .onDisappear {
                                seenTasks[post.id]?.cancel()
                                seenTasks[post.id] = nil
                                if vm.hasSeen(post.id) { Task { await vm.cycleOut(post.id) } }
                            }
                        }
                    }
                    .padding(responsive.spacing(16))
                    .frame(maxWidth: responsive.contentMaxWidth)
                    .frame(maxWidth: .infinity)
                }
                .refreshable { await vm.loadFeed() }
            }
        }
        .background(.clear)
        .task { await vm.loadFeed() }
        .sheet(isPresented: $vm.showCreateSheet) {
            CreatePostSheet(vm: vm)
        }
        .sheet(item: $vm.selectedPost) { post in
            CommentsSheet(postId: post.id, vm: vm)
                .onAppear { Task { await vm.loadComments(for: post) } }
        }
        .sheet(item: $vm.reportTarget) { target in
            ReportSheet(target: target)
        }
        .alert("Error", isPresented: Binding(
            get: { vm.errorMessage != nil },
            set: { if !$0 { vm.errorMessage = nil } }
        )) {
            Button("OK") { vm.errorMessage = nil }
        } message: {
            Text(vm.errorMessage ?? "")
        }
        .alert("Blocked", isPresented: Binding(
            get: { vm.moderationMessage != nil },
            set: { if !$0 { vm.moderationMessage = nil } }
        )) {
            Button("OK") { vm.moderationMessage = nil }
        } message: {
            Text(vm.moderationMessage ?? "")
        }
    }
}
