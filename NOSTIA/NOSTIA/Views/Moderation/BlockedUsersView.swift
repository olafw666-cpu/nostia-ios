import SwiftUI

// Manage blocked users — visible unblock path (App Store Guideline 1.2).
struct BlockedUsersView: View {
    @State private var blockedUsers: [BlockedUser] = []
    @State private var isLoading = true
    @State private var unblockingIds: Set<Int> = []
    @State private var errorMessage: String?
    @EnvironmentObject var responsive: ResponsiveLayoutManager

    var body: some View {
        ScrollView {
            LazyVStack(spacing: responsive.spacing(12)) {
                if let err = errorMessage {
                    Text(err).font(.footnote).foregroundColor(Color.nostriaDanger)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(responsive.spacing(12))
                        .glassEffect(in: RoundedRectangle(cornerRadius: 10))
                }

                if isLoading {
                    ProgressView().tint(Color.nostiaAccent).padding(40)
                } else if blockedUsers.isEmpty {
                    VStack(spacing: responsive.spacing(12)) {
                        Image(systemName: "nosign")
                            .font(.system(size: responsive.fontSize(48)))
                            .foregroundColor(Color.nostiaAccent.opacity(0.7))
                        Text("No blocked users").font(.headline).foregroundColor(.white)
                        Text("Users you block won't see your content,\nand you won't see theirs.")
                            .font(.subheadline)
                            .foregroundColor(Color.nostiaTextSecond)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, responsive.spacing(60))
                } else {
                    ForEach(blockedUsers) { user in
                        HStack(spacing: 12) {
                            AvatarView(initial: String(user.name.prefix(1)).uppercased(),
                                       color: Color.nostriaPurple, size: responsive.spacing(40))
                            VStack(alignment: .leading, spacing: 2) {
                                Text(user.name)
                                    .font(.system(size: responsive.fontSize(15), weight: .semibold))
                                    .foregroundColor(.white)
                                Text("@\(user.username)")
                                    .font(.caption).foregroundColor(Color.nostiaTextMuted)
                            }
                            Spacer()
                            Button {
                                Task { await unblock(user) }
                            } label: {
                                if unblockingIds.contains(user.id) {
                                    ProgressView().tint(.white).frame(width: 80)
                                } else {
                                    Text("Unblock")
                                        .font(.subheadline.bold())
                                        .foregroundColor(.white)
                                        .frame(width: 80)
                                        .padding(.vertical, 8)
                                        .background(Color.nostiaAccent)
                                        .cornerRadius(10)
                                }
                            }
                            .disabled(unblockingIds.contains(user.id))
                        }
                        .padding(responsive.spacing(14))
                        .glassEffect(in: RoundedRectangle(cornerRadius: 14))
                    }
                }
            }
            .padding(responsive.spacing(16))
            .frame(maxWidth: responsive.contentMaxWidth)
            .frame(maxWidth: .infinity)
        }
        .background(.clear)
        .navigationTitle("Blocked Users")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .task { await load() }
        .refreshable { await load() }
    }

    private func load() async {
        do {
            blockedUsers = try await ModerationAPI.shared.getBlockedUsers()
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private func unblock(_ user: BlockedUser) async {
        unblockingIds.insert(user.id)
        do {
            try await ModerationAPI.shared.unblockUser(userId: user.id)
            blockedUsers.removeAll { $0.id == user.id }
        } catch {
            errorMessage = error.localizedDescription
        }
        unblockingIds.remove(user.id)
    }
}
