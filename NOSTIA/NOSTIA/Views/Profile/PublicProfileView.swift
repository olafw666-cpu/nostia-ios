import SwiftUI

struct PublicProfileView: View {
    let userId: Int

    @State private var user: User?
    @State private var followStatus: FollowStatus?
    @State private var currentUserId: Int?
    @State private var isLoading = true
    @State private var isFollowActionInProgress = false
    @State private var isBlockedByMe = false
    @State private var showBlockConfirm = false
    @State private var profileTab: ProfileTab = .posts
    @State private var canViewVisited = false
    @State private var visitedExperiences: [Experience] = []
    @StateObject private var feedVM = FeedViewModel()
    @EnvironmentObject var responsive: ResponsiveLayoutManager

    var body: some View {
        ScrollView {
            VStack(spacing: responsive.spacing(20)) {
                if isLoading {
                    ProfileSkeletonView()
                } else if let u = user {
                    UserAvatarView(
                        imageData: u.profilePictureUrl,
                        initial: u.initial,
                        color: Color.nostiaAccent,
                        size: responsive.spacing(100)
                    )
                    .padding(.top, responsive.spacing(20))

                    Text("@\(u.username)")
                        .font(.nostiaDisplay(22, weight: .heavy))
                        .foregroundColor(Color.nostiaTextPrimary)

                    let bioText = u.bio?.isEmpty == false ? u.bio! : nil
                    Text(bioText ?? "No bio yet")
                        .font(.body)
                        .foregroundColor(bioText != nil ? Color.nostiaTextPrimary : Color.nostiaTextMuted)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, responsive.spacing(24))

                    Text("\(u.followersCount ?? 0) Followers")
                        .font(.subheadline.bold())
                        .foregroundColor(Color.nostiaTextSecond)

                    if isBlockedByMe {
                        Text("You have blocked this user")
                            .font(.subheadline)
                            .foregroundColor(Color.nostriaDanger)
                            .padding(.vertical, 4)
                    }

                    if let status = followStatus, currentUserId != userId, !isBlockedByMe {
                        Button {
                            Task { await toggleFollow(status: status) }
                        } label: {
                            if isFollowActionInProgress {
                                ProgressView().tint(.white)
                            } else {
                                Text(status.isFollowing ? "Unfollow" : "Follow")
                                    .font(.subheadline.bold())
                                    .foregroundColor(.white)
                                    .frame(width: 120)
                                    .padding(.vertical, 10)
                                    .background(status.isFollowing ? Color.clear : Color.nostiaAccent)
                                    .cornerRadius(10)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(status.isFollowing ? Color.nostiaTextSecond : Color.clear, lineWidth: 1)
                                    )
                            }
                        }
                        .disabled(isFollowActionInProgress)
                    }

                    // Posts / Visited section. The Visited tab only appears when the
                    // viewer is permitted (server-gated; D6).
                    Divider()
                        .background(Color.white.opacity(0.15))
                        .padding(.horizontal, responsive.spacing(20))

                    if canViewVisited && !isBlockedByMe {
                        Picker("", selection: $profileTab) {
                            Text("Posts").tag(ProfileTab.posts)
                            Text("Visited").tag(ProfileTab.visited)
                        }
                        .pickerStyle(.segmented)
                        .padding(.horizontal, responsive.spacing(20))
                        .onChange(of: profileTab) { _, _ in Haptics.select() }

                        if profileTab == .posts {
                            postsSection
                        } else {
                            VisitedExperiencesView(userId: userId, preloaded: visitedExperiences)
                        }
                    } else {
                        SectionHeader(title: "Posts")
                            .padding(.horizontal, responsive.spacing(20))
                            .padding(.top, 4)
                        postsSection
                    }
                }
            }
            .padding(.bottom, 40)
            .frame(maxWidth: responsive.contentMaxWidth)
            .frame(maxWidth: .infinity)
        }
        .background(.clear)
        .navigationTitle(user?.username ?? "Profile")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if currentUserId != nil, currentUserId != userId {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            feedVM.reportTarget = ReportTarget(contentType: "user", contentId: userId)
                        } label: {
                            Label("Report User", systemImage: "flag")
                        }
                        if isBlockedByMe {
                            Button { Task { await unblockUser() } } label: {
                                Label("Unblock User", systemImage: "person.crop.circle.badge.checkmark")
                            }
                        } else {
                            Button(role: .destructive) { showBlockConfirm = true } label: {
                                Label("Block User", systemImage: "nosign")
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .foregroundColor(Color.nostiaAccent)
                    }
                }
            }
        }
        .confirmationDialog(
            "Block @\(user?.username ?? "user")? You won't see each other's posts, comments, or messages.",
            isPresented: $showBlockConfirm, titleVisibility: .visible
        ) {
            Button("Block", role: .destructive) { Task { await blockUser() } }
            Button("Cancel", role: .cancel) {}
        }
        .task { await load() }
        .sheet(item: $feedVM.selectedPost) { post in
            CommentsSheet(postId: post.id, vm: feedVM)
                .onAppear { Task { await feedVM.loadComments(for: post) } }
        }
        .sheet(item: $feedVM.reportTarget) { target in
            ReportSheet(target: target)
        }
        .alert("Blocked", isPresented: Binding(
            get: { feedVM.moderationMessage != nil },
            set: { if !$0 { feedVM.moderationMessage = nil } }
        )) {
            Button("OK") { feedVM.moderationMessage = nil }
        } message: {
            Text(feedVM.moderationMessage ?? "")
        }
    }

    // Shared posts list (used in both the gated tab layout and the no-tab fallback).
    @ViewBuilder
    private var postsSection: some View {
        if feedVM.posts.isEmpty {
            Text("No posts yet.")
                .font(.subheadline)
                .foregroundColor(Color.nostiaTextMuted)
                .padding(.vertical, 12)
        } else {
            ForEach(feedVM.posts) { post in
                PostCard(
                    post: post,
                    currentUserId: currentUserId,
                    onLike: { Task { await feedVM.toggleLike(post: post) } },
                    onDislike: { Task { await feedVM.toggleDislike(post: post) } },
                    onComment: { Task { await feedVM.loadComments(for: post) } },
                    onReport: { feedVM.reportTarget = ReportTarget(contentType: "post", contentId: post.id) },
                    onBlockUser: { Task { await blockUser() } }
                )
                .padding(.horizontal, responsive.spacing(16))
            }
        }
    }

    private func load() async {
        isLoading = true
        async let profileData = ProfileAPI.shared.getPublicProfile(userId: userId)
        async let statusData = FriendsAPI.shared.getFollowStatus(userId: userId)
        async let meData = AuthAPI.shared.getMe()
        async let postsData = FeedAPI.shared.getUserPosts(userId: userId)
        // Probe Visited-tab permission: a non-nil result (incl. empty []) means the
        // viewer is allowed to see it; a thrown 403 (→ nil) means hide the tab.
        async let visitedData = ExperiencesAPI.shared.getVisited(userId: userId)
        user = try? await profileData
        followStatus = try? await statusData
        currentUserId = (try? await meData)?.id
        feedVM.posts = (try? await postsData) ?? []
        let visited = try? await visitedData
        canViewVisited = (visited != nil)
        visitedExperiences = visited ?? []
        isBlockedByMe = user?.isBlockedByMe ?? false
        isLoading = false
    }

    private func blockUser() async {
        await feedVM.blockUser(userId: userId, username: user?.username)
        isBlockedByMe = true
        followStatus = try? await FriendsAPI.shared.getFollowStatus(userId: userId)
    }

    private func unblockUser() async {
        do {
            try await ModerationAPI.shared.unblockUser(userId: userId)
            isBlockedByMe = false
            await load()
        } catch {}
    }

    private func toggleFollow(status: FollowStatus) async {
        isFollowActionInProgress = true
        do {
            if status.isFollowing {
                try await FriendsAPI.shared.unfollow(userId: userId)
            } else {
                try await FriendsAPI.shared.follow(userId: userId)
            }
            followStatus = try? await FriendsAPI.shared.getFollowStatus(userId: userId)
            user = try? await ProfileAPI.shared.getPublicProfile(userId: userId)
        } catch {}
        isFollowActionInProgress = false
    }
}
