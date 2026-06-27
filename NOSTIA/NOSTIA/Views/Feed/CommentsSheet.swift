import SwiftUI

struct CommentsSheet: View {
    let postId: Int
    @ObservedObject var vm: FeedViewModel
    @FocusState private var inputFocused: Bool
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var responsive: ResponsiveLayoutManager

    var body: some View {
        NavigationStack {
            Group {
                if vm.isLoadingComments {
                    CommentSkeletonView()
                } else if vm.comments.isEmpty {
                    VStack(spacing: responsive.spacing(12)) {
                        Image(systemName: "bubble.right")
                            .font(.system(size: responsive.fontSize(48)))
                            .foregroundColor(Color.nostiaAccent.opacity(0.7))
                        Text("No comments yet").font(.headline).foregroundColor(Color.nostiaTextPrimary)
                        Text("Be the first to comment!").font(.subheadline).foregroundColor(Color.nostiaTextSecond)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: responsive.spacing(12)) {
                            ForEach(vm.comments) { comment in
                                CommentRow(
                                    comment: comment,
                                    onReport: comment.userId == AuthManager.shared.currentUserId ? nil : {
                                        vm.reportTarget = ReportTarget(contentType: "comment", contentId: comment.id)
                                    },
                                    onBlockUser: comment.userId == AuthManager.shared.currentUserId ? nil : {
                                        Task { await vm.blockUser(userId: comment.userId, username: comment.username) }
                                    }
                                )
                            }
                        }
                        .padding(responsive.spacing(16))
                        .frame(maxWidth: responsive.sheetMaxWidth)
                        .frame(maxWidth: .infinity)
                    }
                }
            }
            .background(.clear)
            .navigationTitle("Comments")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { inputFocused = false; dismiss() }
                        .foregroundColor(Color.nostiaAccent)
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            HStack(spacing: 10) {
                TextField("Add a comment...", text: $vm.newComment, axis: .vertical)
                    .lineLimit(1...4)
                    .padding(.horizontal, responsive.spacing(14)).padding(.vertical, responsive.spacing(10))
                    .nostiaCard(in: RoundedRectangle(cornerRadius: 20))
                    .foregroundColor(Color.nostiaTextPrimary)
                    .focused($inputFocused)
                Button {
                    Task { await vm.submitComment(postId: postId) }
                } label: {
                    if vm.isSubmittingComment {
                        ProgressView().tint(.white).frame(width: 36, height: 36)
                    } else {
                        Image(systemName: "paperplane.fill")
                            .foregroundColor(.white).frame(width: 36, height: 36)
                            .background(
                                vm.newComment.trimmingCharacters(in: .whitespaces).isEmpty
                                    ? AnyShapeStyle(Color.nostiaTextMuted)
                                    : AnyShapeStyle(LinearGradient(colors: [Color.nostiaAccent, Color.nostriaPurple],
                                                                   startPoint: .topLeading, endPoint: .bottomTrailing))
                            )
                            .clipShape(Circle())
                            .shadow(color: Color.nostiaAccent.opacity(0.4), radius: 6)
                    }
                }
                .disabled(vm.newComment.trimmingCharacters(in: .whitespaces).isEmpty || vm.isSubmittingComment)
            }
            .padding(.horizontal, responsive.spacing(12)).padding(.vertical, responsive.spacing(8))
            .background(.ultraThinMaterial.opacity(0.9))
        }
        .presentationBackground(Color.nostiaBackground)
        .sheet(item: $vm.reportTarget) { target in
            ReportSheet(target: target)
        }
    }
}

struct CommentRow: View {
    let comment: FeedComment
    var onReport: (() -> Void)? = nil
    var onBlockUser: (() -> Void)? = nil
    @EnvironmentObject var responsive: ResponsiveLayoutManager
    @State private var showBlockConfirm = false
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            AvatarView(initial: String(comment.name.prefix(1)).uppercased(), color: Color.nostriaPurple, size: 34)
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(comment.name).font(.system(size: responsive.fontSize(13), weight: .semibold)).foregroundColor(Color.nostiaTextPrimary)
                    Text(comment.timeAgo).font(.caption).foregroundColor(Color.nostiaTextMuted)
                }
                Text(comment.content).font(.system(size: responsive.fontSize(14))).foregroundColor(Color.nostiaTextSecond)
            }
            Spacer()
            if onReport != nil || onBlockUser != nil {
                Menu {
                    if onReport != nil {
                        Button { onReport?() } label: {
                            Label("Report Comment", systemImage: "flag")
                        }
                    }
                    if onBlockUser != nil {
                        Button(role: .destructive) { showBlockConfirm = true } label: {
                            Label("Block @\(comment.username)", systemImage: "nosign")
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.footnote).foregroundColor(Color.nostiaTextMuted)
                        .padding(6)
                }
                .confirmationDialog(
                    "Block @\(comment.username)? You won't see each other's posts, comments, or messages.",
                    isPresented: $showBlockConfirm, titleVisibility: .visible
                ) {
                    Button("Block", role: .destructive) { onBlockUser?() }
                    Button("Cancel", role: .cancel) {}
                }
            }
        }
        .padding(responsive.spacing(12))
        .nostiaCard(in: RoundedRectangle(cornerRadius: 14))
    }
}
