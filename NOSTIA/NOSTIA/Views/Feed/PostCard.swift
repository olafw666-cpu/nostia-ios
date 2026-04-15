import SwiftUI

struct PostCard: View {
    let post: FeedPost
    let currentUserId: Int?
    var onLike: () -> Void = {}
    var onComment: () -> Void = {}
    var onDelete: () -> Void = {}

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack(spacing: 10) {
                AvatarView(initial: String(post.name.prefix(1)).uppercased(), color: Color.nostiaAccent, size: 40)
                VStack(alignment: .leading, spacing: 2) {
                    Text(post.name).font(.system(size: 15, weight: .semibold)).foregroundColor(.white)
                    Text("@\(post.username) · \(post.timeAgo)")
                        .font(.caption).foregroundColor(Color.nostiaTextMuted)
                }
                Spacer()
                if post.userId == currentUserId {
                    Button(action: onDelete) {
                        Image(systemName: "trash")
                            .font(.footnote).foregroundColor(Color.nostriaDanger)
                    }
                }
            }
            .padding(.horizontal, 14).padding(.top, 14).padding(.bottom, 10)

            // Image (if any)
            if let imgData = post.imageData,
               let data = Data(base64Encoded: imgData),
               let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable().scaledToFill()
                    .frame(maxWidth: .infinity).frame(height: 200)
                    .clipped()
            }

            // Content
            if let content = post.content, !content.isEmpty {
                Text(content)
                    .font(.system(size: 15)).foregroundColor(Color.nostiaTextSecond)
                    .lineLimit(5)
                    .padding(.horizontal, 14).padding(.vertical, 10)
            }

            // Trip/event tag
            if let tripTitle = post.tripTitle {
                Label(tripTitle, systemImage: "airplane")
                    .font(.caption).foregroundColor(Color.nostiaAccent)
                    .padding(.horizontal, 14).padding(.bottom, 8)
            }

            Divider().background(Color.white.opacity(0.1)).padding(.horizontal, 14)

            // Footer
            HStack(spacing: 20) {
                Button(action: onLike) {
                    Label("\(post.likeCount)", systemImage: post.isLiked == true ? "heart.fill" : "heart")
                        .font(.system(size: 14))
                        .foregroundColor(post.isLiked == true ? Color.nostriaDanger : Color.nostiaTextMuted)
                }
                Button(action: onComment) {
                    Label("\(post.commentCount)", systemImage: "bubble.right")
                        .font(.system(size: 14)).foregroundColor(Color.nostiaTextMuted)
                }
                Spacer()
            }
            .padding(.horizontal, 14).padding(.vertical, 10)
        }
        .glassEffect(in: RoundedRectangle(cornerRadius: 18))
    }
}
