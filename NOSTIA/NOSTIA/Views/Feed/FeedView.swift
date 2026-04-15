import SwiftUI

struct FeedView: View {
    @StateObject private var vm = FeedViewModel()
    @EnvironmentObject var authManager: AuthManager

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Group {
                if vm.isLoading && vm.posts.isEmpty {
                    ProgressView().tint(Color.nostiaAccent)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if vm.posts.isEmpty {
                    EmptyStateView(icon: "photo.on.rectangle.angled", text: "No posts yet", sub: "Be the first to share something!")
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(vm.posts) { post in
                                PostCard(
                                    post: post,
                                    currentUserId: authManager.currentUserId,
                                    onLike: { Task { await vm.toggleLike(post: post) } },
                                    onComment: { Task { await vm.loadComments(for: post) } },
                                    onDelete: { Task { await vm.deletePost(id: post.id) } }
                                )
                            }
                        }
                        .padding(16)
                    }
                    .refreshable { await vm.loadFeed() }
                }
            }
            .background(.clear)

            // FAB
            Button { vm.showCreateSheet = true } label: {
                Image(systemName: "plus")
                    .font(.title2.weight(.semibold)).foregroundColor(.white)
                    .frame(width: 56, height: 56)
                    .background(
                        LinearGradient(colors: [Color.nostiaAccent, Color.nostriaPurple],
                                       startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .clipShape(Circle())
                    .shadow(color: Color.nostiaAccent.opacity(0.5), radius: 12, y: 6)
            }
            .padding(.trailing, 20).padding(.bottom, 20)
        }
        .task { await vm.loadFeed() }
        .sheet(isPresented: $vm.showCreateSheet) {
            CreatePostSheet(vm: vm)
        }
        .sheet(item: $vm.selectedPost) { post in
            CommentsSheet(postId: post.id, vm: vm)
                .onAppear { Task { await vm.loadComments(for: post) } }
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
