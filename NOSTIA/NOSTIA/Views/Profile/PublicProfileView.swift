import SwiftUI

struct PublicProfileView: View {
    let userId: Int

    @State private var user: User?
    @State private var followStatus: FollowStatus?
    @State private var currentUserId: Int?
    @State private var isLoading = true
    @State private var isFollowActionInProgress = false
    @StateObject private var feedVM = FeedViewModel()

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                if isLoading {
                    ProgressView().tint(Color.nostiaAccent).padding(60)
                } else if let u = user {
                    UserAvatarView(
                        imageData: u.profilePictureUrl,
                        initial: u.initial,
                        color: Color.nostiaAccent,
                        size: 100
                    )
                    .padding(.top, 20)

                    Text("@\(u.username)")
                        .font(.title2.bold())
                        .foregroundColor(.white)

                    let bioText = u.bio?.isEmpty == false ? u.bio! : nil
                    Text(bioText ?? "No bio yet")
                        .font(.body)
                        .foregroundColor(bioText != nil ? .white : Color.nostiaTextMuted)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)

                    Text("\(u.followersCount ?? 0) Followers")
                        .font(.subheadline.bold())
                        .foregroundColor(Color.nostiaTextSecond)

                    if let status = followStatus, currentUserId != userId {
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

                    // Posts section
                    Divider()
                        .background(Color.white.opacity(0.15))
                        .padding(.horizontal, 20)

                    SectionHeader(title: "Posts")
                        .padding(.horizontal, 20)
                        .padding(.top, 4)

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
                                onComment: { Task { await feedVM.loadComments(for: post) } }
                            )
                            .padding(.horizontal, 16)
                        }
                    }
                }
            }
            .padding(.bottom, 40)
        }
        .background(.clear)
        .navigationTitle(user?.username ?? "Profile")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .sheet(item: $feedVM.selectedPost) { post in
            CommentsSheet(postId: post.id, vm: feedVM)
                .onAppear { Task { await feedVM.loadComments(for: post) } }
        }
    }

    private func load() async {
        isLoading = true
        async let profileData = ProfileAPI.shared.getPublicProfile(userId: userId)
        async let statusData = FriendsAPI.shared.getFollowStatus(userId: userId)
        async let meData = AuthAPI.shared.getMe()
        async let postsData = FeedAPI.shared.getUserPosts(userId: userId)
        user = try? await profileData
        followStatus = try? await statusData
        currentUserId = (try? await meData)?.id
        feedVM.posts = (try? await postsData) ?? []
        isLoading = false
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
