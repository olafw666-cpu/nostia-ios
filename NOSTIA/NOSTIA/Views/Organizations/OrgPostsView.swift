import SwiftUI
import PhotosUI

// Org-only posts feed (Section 7). Reuses PostCard/CommentsSheet — org posts share the
// feed_posts model and /feed/:id interaction endpoints (membership enforced server-side).
struct OrgPostsView: View {
    let org: Organization

    @StateObject private var vm = FeedViewModel()
    @EnvironmentObject private var authManager: AuthManager
    @State private var showCreate = false
    @State private var activeComments: FeedPost?
    @State private var isLoading = true

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 14) {
                if org.canPost {
                    Button { showCreate = true } label: {
                        Label("New Post", systemImage: "plus.circle.fill")
                            .font(.subheadline.bold()).foregroundColor(Color.nostiaAccent)
                            .frame(maxWidth: .infinity).padding(.vertical, 12)
                            .glassEffect(in: RoundedRectangle(cornerRadius: 14))
                    }
                }

                if isLoading && vm.posts.isEmpty {
                    ProgressView().tint(Color.nostiaAccent).padding()
                } else if vm.posts.isEmpty {
                    EmptyStateView(icon: "photo.on.rectangle.angled",
                                   text: "No posts yet",
                                   sub: org.canPost ? "Be the first to post" : "Check back later")
                } else {
                    ForEach(vm.posts) { post in
                        PostCard(
                            post: post,
                            currentUserId: authManager.currentUserId,
                            // Surfaces the delete control for owners/admins so they can
                            // remove any org post (Section 7 "Deletion").
                            isCurrentUserDev: org.canManage,
                            onLike: { Task { await vm.toggleLike(post: post) } },
                            onDislike: { Task { await vm.toggleDislike(post: post) } },
                            onDelete: { Task { await vm.deletePost(post: post) } },
                            onComment: { activeComments = post },
                            isLikeProcessing: vm.likingPostIds.contains(post.id),
                            isDislikeProcessing: vm.dislikingPostIds.contains(post.id)
                        )
                    }
                }
            }
            .padding(16)
        }
        .background(.clear)
        .task { await load() }
        .sheet(isPresented: $showCreate) {
            CreateOrgPostSheet(orgId: org.id) { Task { await load() } }
        }
        .sheet(item: $activeComments) { post in
            CommentsSheet(postId: post.id, vm: vm)
                .onAppear { Task { await vm.loadComments(for: post) } }
        }
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        vm.posts = (try? await OrganizationsAPI.shared.getPosts(id: org.id)) ?? []
    }
}

// MARK: - Create org post

struct CreateOrgPostSheet: View {
    let orgId: Int
    var onPosted: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var content = ""
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var imageData: String?
    @State private var isSubmitting = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    TextField("Say something (optional)", text: $content, axis: .vertical)
                        .lineLimit(3...8).padding(14)
                        .glassEffect(in: RoundedRectangle(cornerRadius: 14)).foregroundColor(.white)

                    if let imageData, let data = Data(base64Encoded: imageData), let img = UIImage(data: data) {
                        ZStack(alignment: .topTrailing) {
                            Image(uiImage: img).resizable().scaledToFill()
                                .frame(maxWidth: .infinity).frame(height: 180).clipped().cornerRadius(14)
                            Button { self.imageData = nil; selectedPhoto = nil } label: {
                                Image(systemName: "xmark.circle.fill").font(.title2).foregroundColor(.white).padding(6)
                            }
                        }
                    }

                    PhotosPicker(selection: $selectedPhoto, matching: .images) {
                        Label("Add Photo", systemImage: "photo.on.rectangle")
                            .foregroundColor(Color.nostiaAccent).frame(maxWidth: .infinity).padding(14)
                            .glassEffect(in: RoundedRectangle(cornerRadius: 14))
                    }

                    if let errorMessage {
                        Text(errorMessage).font(.footnote).foregroundColor(Color.nostriaDanger)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(16)
            }
            .background(.clear)
            .navigationTitle("New Org Post")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }.foregroundColor(Color.nostiaTextSecond)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await submit() }
                    } label: {
                        if isSubmitting { ProgressView().tint(.white) }
                        else { Text("Post").fontWeight(.semibold).foregroundColor(Color.nostiaAccent) }
                    }
                    .disabled(isSubmitting || (content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && imageData == nil))
                }
            }
            .onChange(of: selectedPhoto) { _, item in
                Task {
                    if let data = try? await item?.loadTransferable(type: Data.self),
                       let img = UIImage(data: data),
                       let compressed = img.resizedForUpload().jpegData(compressionQuality: 0.4) {
                        imageData = compressed.base64EncodedString()
                    }
                }
            }
        }
        .presentationBackground(.ultraThinMaterial)
    }

    private func submit() async {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty || imageData != nil else { return }
        isSubmitting = true
        defer { isSubmitting = false }
        do {
            _ = try await OrganizationsAPI.shared.createPost(
                id: orgId,
                content: trimmed.isEmpty ? nil : trimmed,
                imageData: imageData
            )
            Haptics.success()
            onPosted()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
