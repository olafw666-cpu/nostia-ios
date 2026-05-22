import SwiftUI

struct PostCard: View {
    let post: FeedPost
    let currentUserId: Int?
    var isCurrentUserDev: Bool = false
    var onLike: () -> Void = {}
    var onDislike: () -> Void = {}
    var onDelete: (() -> Void)? = nil
    var onEdit: (() -> Void)? = nil
    var onComment: () -> Void = {}
    var onProfileTap: ((Int) -> Void)? = nil
    var isLikeProcessing: Bool = false
    var isDislikeProcessing: Bool = false
    @EnvironmentObject var responsive: ResponsiveLayoutManager

    @State private var showDeleteConfirm = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack(spacing: 10) {
                Button {
                    onProfileTap?(post.userId)
                } label: {
                    HStack(spacing: 10) {
                        AvatarView(initial: String(post.name.prefix(1)).uppercased(), color: Color.nostiaAccent, size: responsive.spacing(40))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(post.name).font(.system(size: responsive.fontSize(15), weight: .semibold)).foregroundColor(.white)
                            Text("@\(post.username) · \(post.timeAgo)")
                                .font(.caption).foregroundColor(Color.nostiaTextMuted)
                        }
                    }
                }
                .buttonStyle(.plain)
                Spacer()
                HStack(spacing: 4) {
                    if post.userId == currentUserId, let onEdit {
                        Button { onEdit() } label: {
                            Image(systemName: "pencil")
                                .font(.footnote).foregroundColor(Color.nostiaTextMuted)
                                .padding(8)
                        }
                    }
                    if (post.userId == currentUserId || isCurrentUserDev), onDelete != nil {
                        Button { showDeleteConfirm = true } label: {
                            Image(systemName: "trash")
                                .font(.footnote).foregroundColor(Color.nostriaDanger)
                                .padding(8)
                        }
                        .confirmationDialog("Delete this post?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
                            Button("Delete", role: .destructive) { onDelete?() }
                            Button("Cancel", role: .cancel) {}
                        }
                    }
                }
            }
            .padding(.horizontal, responsive.spacing(14)).padding(.top, responsive.spacing(14)).padding(.bottom, responsive.spacing(10))

            // Image (if any)
            if let imgData = post.imageData,
               let data = Data(base64Encoded: imgData),
               let uiImage = UIImage(data: data) {
                Color.clear
                    .frame(maxWidth: .infinity)
                    .frame(height: responsive.spacing(200))
                    .overlay(
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFill()
                    )
                    .clipped()
            }

            // Content
            if let content = post.content, !content.isEmpty {
                Text(content)
                    .font(.system(size: responsive.fontSize(15))).foregroundColor(Color.nostiaTextSecond)
                    .lineLimit(5)
                    .padding(.horizontal, responsive.spacing(14)).padding(.vertical, responsive.spacing(10))
            }

            // Trip/event tag
            if let tripTitle = post.tripTitle {
                Label(tripTitle, systemImage: "airplane")
                    .font(.caption).foregroundColor(Color.nostiaAccent)
                    .padding(.horizontal, responsive.spacing(14)).padding(.bottom, 8)
            }

            Divider().background(Color.white.opacity(0.1)).padding(.horizontal, responsive.spacing(14))

            // Footer
            HStack(spacing: 20) {
                Button(action: onLike) {
                    Label("\(post.likeCount)", systemImage: post.isLiked == true ? "heart.fill" : "heart")
                        .font(.system(size: responsive.fontSize(14)))
                        .foregroundColor(post.isLiked == true ? Color.nostriaDanger : Color.nostiaTextMuted)
                }
                .disabled(isLikeProcessing || isDislikeProcessing)
                Button(action: onDislike) {
                    Label("\(post.dislikeCount)", systemImage: post.isDisliked == true ? "hand.thumbsdown.fill" : "hand.thumbsdown")
                        .font(.system(size: responsive.fontSize(14)))
                        .foregroundColor(post.isDisliked == true ? Color.nostiaWarning : Color.nostiaTextMuted)
                }
                .disabled(isLikeProcessing || isDislikeProcessing)
                Button(action: onComment) {
                    Label("\(post.commentCount)", systemImage: "bubble.right")
                        .font(.system(size: responsive.fontSize(14))).foregroundColor(Color.nostiaTextMuted)
                }
                Spacer()
            }
            .padding(.horizontal, responsive.spacing(14)).padding(.vertical, responsive.spacing(10))
        }
        .glassEffect(in: RoundedRectangle(cornerRadius: 18))
    }
}
