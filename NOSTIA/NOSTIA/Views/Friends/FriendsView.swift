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
                        UserSearchRow(user: user, onAdd: { Task { await vm.sendRequest(to: user.id) } })
                            .listRowBackground(Color.clear).listRowSeparator(.hidden)
                    }
                    .listStyle(.plain).background(.clear).scrollContentBackground(.hidden)
                }
            } else {
                // Tab selector
                HStack(spacing: 8) {
                    TabButton(title: "Friends (\(vm.friends.count))", isActive: vm.activeTab == .friends) {
                        vm.activeTab = .friends
                    }
                    TabButton(title: "Requests (\(vm.receivedRequests.count))", isActive: vm.activeTab == .requests) {
                        vm.activeTab = .requests
                    }
                }
                .padding(.horizontal, 16).padding(.bottom, 8)

                if vm.isLoading { LoadingView() }
                else if vm.activeTab == .friends {
                    List(vm.friends) { friend in
                        FriendRow(friend: friend,
                                  onMessage: {
                                      Task {
                                          if let conv = try? await MessagesAPI.shared.getOrCreateConversation(withUserId: friend.id) {
                                              chatTarget = (conv.id, friend.name, friend.id)
                                          }
                                      }
                                  })
                            .listRowBackground(Color.clear).listRowSeparator(.hidden)
                    }
                    .listStyle(.plain).background(.clear).scrollContentBackground(.hidden)
                    .refreshable { await vm.loadAll() }
                    .overlay {
                        if vm.friends.isEmpty {
                            EmptyStateView(icon: "person.2", text: "No friends yet", sub: "Search for users to connect!")
                        }
                    }
                } else {
                    List(vm.receivedRequests) { req in
                        RequestRow(request: req,
                                   onAccept: { Task { await vm.acceptRequest(req.id) } },
                                   onReject: { Task { await vm.rejectRequest(req.id) } })
                            .listRowBackground(Color.clear).listRowSeparator(.hidden)
                    }
                    .listStyle(.plain).background(.clear).scrollContentBackground(.hidden)
                    .refreshable { await vm.loadAll() }
                    .overlay {
                        if vm.receivedRequests.isEmpty {
                            EmptyStateView(icon: "envelope", text: "No pending requests", sub: "")
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
}

struct ChatDestination: Identifiable, Hashable {
    let id: Int
    let name: String
    let friendId: Int
}

struct FriendRow: View {
    let friend: Friend
    let onMessage: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            AvatarView(initial: friend.initial, color: Color.nostiaAccent, size: 50)
            VStack(alignment: .leading, spacing: 2) {
                Text(friend.name).font(.headline).foregroundColor(.white)
                Text("@\(friend.username)").font(.footnote).foregroundColor(Color.nostiaTextSecond)
            }
            Spacer()
            HStack(spacing: 8) {
                Button { onMessage() } label: {
                    Image(systemName: "bubble.left.fill")
                        .foregroundColor(.white).padding(8)
                        .background(Color.nostiaAccent).clipShape(Circle())
                        .shadow(color: Color.nostiaAccent.opacity(0.4), radius: 6)
                }
                Text(friend.isHomeOpen ? "🏠 Open" : "🔒 Closed")
                    .font(.caption.bold()).foregroundColor(.white)
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .glassEffect(in: Capsule())
                    .overlay(Capsule().stroke(
                        friend.isHomeOpen ? Color.nostiaSuccess.opacity(0.6) : Color.nostriaBorder,
                        lineWidth: 1
                    ))
            }
        }
        .padding(16)
        .glassEffect(in: RoundedRectangle(cornerRadius: 16))
        .padding(.vertical, 4)
    }
}

struct RequestRow: View {
    let request: FriendRequest
    let onAccept: () -> Void
    let onReject: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            AvatarView(initial: String(request.name.prefix(1)).uppercased(), color: Color.nostiaAccent, size: 50)
            VStack(alignment: .leading, spacing: 2) {
                Text(request.name).font(.headline).foregroundColor(.white)
                Text("@\(request.username)").font(.footnote).foregroundColor(Color.nostiaTextSecond)
            }
            Spacer()
            HStack(spacing: 8) {
                Button { onAccept() } label: {
                    Image(systemName: "checkmark").foregroundColor(.white).padding(8)
                        .background(Color.nostiaSuccess).clipShape(Circle())
                }
                Button { onReject() } label: {
                    Image(systemName: "xmark").foregroundColor(.white).padding(8)
                        .background(Color.nostriaDanger).clipShape(Circle())
                }
            }
        }
        .padding(16)
        .glassEffect(in: RoundedRectangle(cornerRadius: 16))
        .padding(.vertical, 4)
    }
}

struct UserSearchRow: View {
    let user: UserSearchResult
    let onAdd: () -> Void
    var body: some View {
        HStack(spacing: 12) {
            AvatarView(initial: String(user.name.prefix(1)).uppercased(), color: Color.nostiaAccent, size: 50)
            VStack(alignment: .leading, spacing: 2) {
                Text(user.name).font(.headline).foregroundColor(.white)
                Text("@\(user.username)").font(.footnote).foregroundColor(Color.nostiaTextSecond)
            }
            Spacer()
            Button { onAdd() } label: {
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
