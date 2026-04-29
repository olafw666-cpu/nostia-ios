import SwiftUI

struct PublicProfileView: View {
    let userId: Int

    @State private var user: User?
    @State private var isLoading = true

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

                    Text("\(u.friendsCount ?? 0) Friends")
                        .font(.subheadline.bold())
                        .foregroundColor(Color.nostiaTextSecond)
                }
            }
            .padding(.bottom, 40)
        }
        .background(.clear)
        .navigationTitle(user?.username ?? "Profile")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
    }

    private func load() async {
        isLoading = true
        user = try? await ProfileAPI.shared.getPublicProfile(userId: userId)
        isLoading = false
    }
}
