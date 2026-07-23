import SwiftUI

/// The second and final tab (Product Definition v2 §3): feed, graph, invites.
/// Feed first — scoped friends + local by the server; the old global backfill
/// is gone. People is the existing following/followers surface; Community
/// relocates Organizations and Crash Pads from the retired Home tab.
struct FriendsHubView: View {
    @StateObject private var feedVM = FeedViewModel()
    @State private var section: Section = .feed
    @State private var showOrganizations = false
    @State private var showCrashPads = false

    enum Section: String, CaseIterable, Identifiable {
        case feed = "Feed"
        case people = "People"
        case community = "Community"
        var id: String { rawValue }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center) {
                NostiaScreenTitle(title: "Friends")
                Spacer()
                if section == .feed {
                    Button {
                        Haptics.tap()
                        feedVM.showCreateSheet = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.nostiaBody(16, weight: .bold))
                            .foregroundColor(Color.nostiaAccent)
                            .frame(width: 40, height: 40)
                            .nostiaCard(cornerRadius: 14, elevation: .flat)
                    }
                    .buttonStyle(.nostiaTap)
                    .accessibilityLabel("Create a post")
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 6)

            Picker("Section", selection: $section) {
                ForEach(Section.allCases) { s in
                    Text(s.rawValue).tag(s)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            switch section {
            case .feed:
                FeedHubSection(vm: feedVM)
            case .people:
                FriendsView()
            case .community:
                communitySection
            }
        }
        .background(Color.nostiaBackground.ignoresSafeArea())
        .sheet(isPresented: $showOrganizations) {
            OrganizationsHubView()
                .presentationBackground(Color.nostiaBackground)
        }
        .sheet(isPresented: $showCrashPads) {
            CrashPadsView()
        }
    }

    private var communitySection: some View {
        ScrollView {
            VStack(spacing: 14) {
                communityCard(
                    icon: "building.2.fill",
                    title: "Organizations",
                    sub: "Location-gated groups with their own experiences and posts"
                ) { showOrganizations = true }
                communityCard(
                    icon: "sofa.fill",
                    title: "Crash Pads",
                    sub: "Offer or find a place to crash with mutuals"
                ) { showCrashPads = true }
            }
            .padding(16)
            .padding(.bottom, 110)
        }
    }

    private func communityCard(icon: String, title: String, sub: String, action: @escaping () -> Void) -> some View {
        Button {
            Haptics.tap()
            action()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.nostiaBody(20, weight: .bold))
                    .foregroundColor(Color.nostiaAccent)
                    .frame(width: 44, height: 44)
                    .background(Color.nostiaAccentSoft)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.nostiaBody(16, weight: .bold))
                        .foregroundColor(Color.nostiaTextPrimary)
                    Text(sub)
                        .font(.nostiaBody(13))
                        .foregroundColor(Color.nostiaTextSecond)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.nostiaBody(13, weight: .bold))
                    .foregroundColor(Color.nostiaTextMuted)
            }
            .padding(14)
        }
        .buttonStyle(.nostiaTap)
        .nostiaWarmCard(cornerRadius: 18)
        .accessibilityLabel(title)
    }
}

/// The orphaned standalone FeedView, promoted at last — wrapped so the hub's
/// shared FeedViewModel drives it (the + button above and the list below must
/// agree on one view model instance).
private struct FeedHubSection: View {
    @ObservedObject var vm: FeedViewModel
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var responsive: ResponsiveLayoutManager

    var body: some View {
        Group {
            if vm.isLoading && vm.posts.isEmpty {
                FeedSkeletonView()
            } else if vm.posts.isEmpty {
                EmptyStateView(
                    icon: "photo.on.rectangle.angled",
                    text: "Nothing from your people yet",
                    sub: "Follow friends or post something from tonight."
                )
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
                        }
                    }
                    .padding(responsive.spacing(16))
                    .padding(.bottom, 110)
                    .frame(maxWidth: responsive.contentMaxWidth)
                    .frame(maxWidth: .infinity)
                }
                .refreshable { await vm.loadFeed() }
            }
        }
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
    }
}
