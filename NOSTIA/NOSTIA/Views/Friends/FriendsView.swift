import SwiftUI

struct FriendsView: View {
    @StateObject private var vm = FriendsViewModel()
    @State private var chatTarget: (conversationId: Int, name: String, friendId: Int)?

    var body: some View {
        VStack(spacing: 0) {
            // Search bar
            HStack(spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass").foregroundColor(Color.nostiaTextSecond)
                    TextField("Search users...", text: $vm.searchQuery)
                        .foregroundColor(.white)
                        .submitLabel(.search)
                        .onSubmit { Task { await vm.search() } }
                        .autocorrectionDisabled().textInputAutocapitalization(.never)
                    if !vm.searchQuery.isEmpty {
                        Button { vm.clearSearch() } label: {
                            Image(systemName: "xmark.circle.fill").foregroundColor(Color.nostiaTextMuted)
                        }
                    }
                }
                .padding(12)
                .glassEffect(in: RoundedRectangle(cornerRadius: 12))

                Button("Search") { Task { await vm.search() } }
                    .font(.subheadline.bold()).foregroundColor(.white)
                    .padding(.horizontal, 16).padding(.vertical, 12)
                    .background(Color.nostiaAccent).cornerRadius(12)
            }
            .padding(.horizontal, 16).padding(.vertical, 12)

            if vm.isSearching {
                LoadingView()
            } else if vm.searchPerformed {
                if vm.searchResults.isEmpty {
                    EmptyStateView(icon: "person", text: "No users found", sub: "Try a different name or username")
                } else {
                    List(vm.searchResults) { user in
                        UserSearchRow(user: user, onFollow: { Task { await vm.follow(userId: user.id) } })
                            .listRowBackground(Color.clear).listRowSeparator(.hidden)
                    }
                    .listStyle(.plain).background(.clear).scrollContentBackground(.hidden)
                }
            } else {
                // Tab selector
                HStack(spacing: 8) {
                    TabButton(title: "Followers (\(vm.followers.count))", isActive: vm.activeTab == .followers) {
                        vm.activeTab = .followers
                    }
                    TabButton(title: "Following (\(vm.following.count))", isActive: vm.activeTab == .following) {
                        vm.activeTab = .following
                    }
                }
                .padding(.horizontal, 16).padding(.bottom, 8)

                if vm.isLoading { LoadingView() }
                else if vm.activeTab == .followers {
                    List(vm.followers) { user in
                        FollowUserRow(
                            user: user,
                            trailingContent: {
                                AnyView(HStack(spacing: 8) {
                                    if vm.followingIds.contains(user.id) {
                                        messageButton(for: user)
                                    } else {
                                        followBackButton(for: user)
                                    }
                                })
                            }
                        )
                        .listRowBackground(Color.clear).listRowSeparator(.hidden)
                    }
                    .listStyle(.plain).background(.clear).scrollContentBackground(.hidden)
                    .refreshable { await vm.loadAll() }
                    .overlay {
                        if vm.followers.isEmpty {
                            EmptyStateView(icon: "person.2", text: "No one is following you yet.", sub: "Share your profile to gain followers")
                        }
                    }
                } else {
                    List(vm.following) { user in
                        FollowUserRow(
                            user: user,
                            trailingContent: {
                                AnyView(HStack(spacing: 8) {
                                    if vm.followerIds.contains(user.id) {
                                        messageButton(for: user)
                                    }
                                    unfollowButton(for: user)
                                })
                            }
                        )
                        .listRowBackground(Color.clear).listRowSeparator(.hidden)
                    }
                    .listStyle(.plain).background(.clear).scrollContentBackground(.hidden)
                    .refreshable { await vm.loadAll() }
                    .overlay {
                        if vm.following.isEmpty {
                            EmptyStateView(icon: "person.badge.plus", text: "You are not following anyone yet.", sub: "Search for users to follow them")
                        }
                    }
                }
            }
        }
        .background(.clear)
        .task { await vm.loadAll() }
        .alert("Error", isPresented: Binding(get: { vm.errorMessage != nil }, set: { if !$0 { vm.errorMessage = nil } })) {
            Button("OK") { vm.errorMessage = nil }
        } message: { Text(vm.errorMessage ?? "") }
        .navigationDestination(item: Binding(
            get: { chatTarget.map { t in ChatDestination(id: t.conversationId, name: t.name, friendId: t.friendId) } },
            set: { if $0 == nil { chatTarget = nil } }
        )) { dest in
            ChatView(conversationId: dest.id, friendName: dest.name)
        }
    }

    @ViewBuilder
    private func messageButton(for user: FollowUser) -> some View {
        Button {
            Task {
                if let conv = try? await MessagesAPI.shared.getOrCreateConversation(withUserId: user.id) {
                    chatTarget = (conv.id, user.name, user.id)
                }
            }
        } label: {
            Image(systemName: "bubble.left.fill")
                .foregroundColor(.white).padding(8)
                .background(Color.nostiaAccent).clipShape(Circle())
                .shadow(color: Color.nostiaAccent.opacity(0.4), radius: 6)
        }
    }

    @ViewBuilder
    private func followBackButton(for user: FollowUser) -> some View {
        Button {
            Task { await vm.follow(userId: user.id) }
        } label: {
            Text("Follow")
                .font(.caption.bold()).foregroundColor(.white)
                .padding(.horizontal, 12).padding(.vertical, 6)
                .background(Color.nostiaAccent).cornerRadius(8)
        }
    }

    @ViewBuilder
    private func unfollowButton(for user: FollowUser) -> some View {
        Button {
            Task { await vm.unfollow(userId: user.id) }
        } label: {
            Text("Unfollow")
                .font(.caption.bold()).foregroundColor(Color.nostiaTextSecond)
                .padding(.horizontal, 12).padding(.vertical, 6)
                .glassEffect(in: RoundedRectangle(cornerRadius: 8))
        }
    }
}

struct ChatDestination: Identifiable, Hashable {
    let id: Int
    let name: String
    let friendId: Int
}

struct FollowUserRow<Trailing: View>: View {
    let user: FollowUser
    let trailingContent: () -> Trailing

    var body: some View {
        HStack(spacing: 12) {
            AvatarView(initial: user.initial, color: Color.nostiaAccent, size: 50)
            VStack(alignment: .leading, spacing: 2) {
                Text(user.name).font(.headline).foregroundColor(.white)
                Text("@\(user.username)").font(.footnote).foregroundColor(Color.nostiaTextSecond)
            }
            Spacer()
            trailingContent()
        }
        .padding(16)
        .glassEffect(in: RoundedRectangle(cornerRadius: 16))
        .padding(.vertical, 4)
    }
}

struct UserSearchRow: View {
    let user: UserSearchResult
    let onFollow: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            AvatarView(initial: String(user.name.prefix(1)).uppercased(), color: Color.nostiaAccent, size: 50)
            VStack(alignment: .leading, spacing: 2) {
                Text(user.name).font(.headline).foregroundColor(.white)
                Text("@\(user.username)").font(.footnote).foregroundColor(Color.nostiaTextSecond)
            }
            Spacer()
            Button { onFollow() } label: {
                Image(systemName: "person.badge.plus").foregroundColor(.white).padding(8)
                    .background(Color.nostiaAccent).clipShape(Circle())
                    .shadow(color: Color.nostiaAccent.opacity(0.4), radius: 6)
            }
        }
        .padding(16)
        .glassEffect(in: RoundedRectangle(cornerRadius: 16))
        .padding(.vertical, 4)
    }
}

struct TabButton: View {
    let title: String; let isActive: Bool; let action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.bold())
                .foregroundColor(isActive ? .white : Color.nostiaTextSecond)
                .frame(maxWidth: .infinity).padding(.vertical, 10)
                .glassEffect(in: RoundedRectangle(cornerRadius: 10))
                .overlay(isActive ? RoundedRectangle(cornerRadius: 10).stroke(Color.nostiaAccent, lineWidth: 1) : nil)
        }
    }
}
