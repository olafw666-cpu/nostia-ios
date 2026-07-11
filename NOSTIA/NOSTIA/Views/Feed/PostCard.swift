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
    var onReport: (() -> Void)? = nil
    var onBlockUser: (() -> Void)? = nil
    var isLikeProcessing: Bool = false
    var isDislikeProcessing: Bool = false
    @EnvironmentObject var responsive: ResponsiveLayoutManager

    @State private var showDeleteConfirm = false
    @State private var showBlockConfirm = false

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
                            Text(post.name).font(.nostiaBody(responsive.fontSize(15), weight: .bold))
                                .foregroundStyle(.nostiaUsername(isDev: post.isDev == true, fallback: Color.nostiaTextPrimary))
                            Text("@\(post.username) · \(post.timeAgo)")
                                .font(.caption)
                                .foregroundStyle(.nostiaUsername(isDev: post.isDev == true, fallback: Color.nostiaTextMuted))
                            // Badge org content so it's identifiable in the mixed feed.
                            if let orgName = post.orgName {
                                Label(orgName, systemImage: "building.2")
                                    .font(.nostiaBody(responsive.fontSize(11), weight: .semibold))
                                    .foregroundColor(Color.nostiaAccent)
                            }
                        }
                    }
                }
                .buttonStyle(.nostiaTap)
                Spacer()
                HStack(spacing: 4) {
                    if post.userId == currentUserId, let onEdit {
                        Button { onEdit() } label: {
                            Image(systemName: "pencil")
                                .font(.footnote).foregroundColor(Color.nostiaTextMuted)
                                .frame(width: 40, height: 40)
                        }
                        .buttonStyle(.nostiaTap)
                        .accessibilityLabel("Edit post")
                    }
                    if (post.userId == currentUserId || isCurrentUserDev), onDelete != nil {
                        Button { showDeleteConfirm = true } label: {
                            Image(systemName: "trash")
                                .font(.footnote).foregroundColor(Color.nostriaDanger)
                                .frame(width: 40, height: 40)
                        }
                        .buttonStyle(.nostiaTap)
                        .accessibilityLabel("Delete post")
                        .confirmationDialog("Delete this post?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
                            Button("Delete", role: .destructive) { onDelete?() }
                            Button("Cancel", role: .cancel) {}
                        }
                    }
                    if post.userId != currentUserId, onReport != nil || onBlockUser != nil {
                        Menu {
                            if onReport != nil {
                                Button { onReport?() } label: {
                                    Label("Report Post", systemImage: "flag")
                                }
                            }
                            if onBlockUser != nil {
                                Button(role: .destructive) { showBlockConfirm = true } label: {
                                    Label("Block @\(post.username)", systemImage: "nosign")
                                }
                            }
                        } label: {
                            // Menus don't take a ButtonStyle, so the tap shape is declared
                            // on the label itself.
                            Image(systemName: "ellipsis")
                                .font(.footnote).foregroundColor(Color.nostiaTextMuted)
                                .frame(width: 40, height: 40)
                                .contentShape(Rectangle())
                        }
                        .accessibilityLabel("More options")
                        .confirmationDialog(
                            "Block @\(post.username)? You won't see each other's posts, comments, or messages.",
                            isPresented: $showBlockConfirm, titleVisibility: .visible
                        ) {
                            Button("Block", role: .destructive) { onBlockUser?() }
                            Button("Cancel", role: .cancel) {}
                        }
                    }
                }
            }
            .padding(.horizontal, responsive.spacing(14)).padding(.top, responsive.spacing(14)).padding(.bottom, responsive.spacing(10))

            // Image (if any) — shown in full (scaledToFit) so vertical phone photos and
            // user-cropped images aren't cut off. The image bytes already reflect the
            // crop / scale-to-fit choice made when the post was created.
            if let imgData = post.imageData,
               let data = Data(base64Encoded: imgData),
               let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity)
                    .frame(maxHeight: responsive.spacing(440))
            }

            // Content
            if let content = post.content, !content.isEmpty {
                Text(content)
                    .font(.nostiaBody(responsive.fontSize(15))).foregroundColor(Color.nostiaTextSecond)
                    .lineLimit(5)
                    .padding(.horizontal, responsive.spacing(14)).padding(.vertical, responsive.spacing(10))
            }

            // Trip/event tag
            if let tripTitle = post.tripTitle {
                Label(tripTitle, systemImage: "airplane")
                    .font(.caption).foregroundColor(Color.nostiaAccent)
                    .padding(.horizontal, responsive.spacing(14)).padding(.bottom, 8)
            }

            Divider().background(Color.nostiaDivider).padding(.horizontal, responsive.spacing(14))

            // Footer
            HStack(spacing: 20) {
                Button(action: onLike) {
                    Label("\(post.likeCount)", systemImage: post.isLiked == true ? "heart.fill" : "heart")
                        .font(.nostiaBody(responsive.fontSize(14)))
                        .foregroundColor(post.isLiked == true ? Color.nostriaDanger : Color.nostiaTextMuted)
                        .padding(.vertical, 8).padding(.horizontal, 4)
                }
                .buttonStyle(.nostiaTap)
                .disabled(isLikeProcessing || isDislikeProcessing)
                .accessibilityLabel(post.isLiked == true ? "Unlike, \(post.likeCount) likes" : "Like, \(post.likeCount) likes")
                Button(action: onDislike) {
                    Label("\(post.dislikeCount)", systemImage: post.isDisliked == true ? "hand.thumbsdown.fill" : "hand.thumbsdown")
                        .font(.nostiaBody(responsive.fontSize(14)))
                        .foregroundColor(post.isDisliked == true ? Color.nostiaWarning : Color.nostiaTextMuted)
                        .padding(.vertical, 8).padding(.horizontal, 4)
                }
                .buttonStyle(.nostiaTap)
                .disabled(isLikeProcessing || isDislikeProcessing)
                .accessibilityLabel(post.isDisliked == true ? "Remove dislike, \(post.dislikeCount) dislikes" : "Dislike, \(post.dislikeCount) dislikes")
                Button(action: onComment) {
                    Label("\(post.commentCount)", systemImage: "bubble.right")
                        .font(.nostiaBody(responsive.fontSize(14))).foregroundColor(Color.nostiaTextMuted)
                        .padding(.vertical, 8).padding(.horizontal, 4)
                }
                .buttonStyle(.nostiaTap)
                .accessibilityLabel("Comments, \(post.commentCount)")
                Spacer()
            }
            .padding(.horizontal, responsive.spacing(14)).padding(.vertical, responsive.spacing(10))
        }
        .nostiaCard(in: RoundedRectangle(cornerRadius: 18))
    }
}
