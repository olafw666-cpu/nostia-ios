import SwiftUI
import Contacts

struct FriendsView: View {
    @StateObject private var vm = FriendsViewModel()
    @State private var chatTarget: (conversationId: Int, name: String, friendId: Int)?
    @State private var profileDestination: ProfileDestination?
    @State private var showContactsPicker = false

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

            // Find via Contacts
            Button {
                showContactsPicker = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "person.crop.circle.badge.plus")
                    Text("Find via Contacts")
                        .font(.subheadline)
                }
                .foregroundColor(Color.nostiaTextSecond)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .glassEffect(in: RoundedRectangle(cornerRadius: 12))
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 8)

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
                            onProfileTap: { profileDestination = ProfileDestination(id: user.id) },
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
                            onProfileTap: { profileDestination = ProfileDestination(id: user.id) },
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
        .navigationDestination(item: $profileDestination) { dest in
            PublicProfileView(userId: dest.id)
        }
        .navigationDestination(item: Binding(
            get: { chatTarget.map { t in ChatDestination(id: t.conversationId, name: t.name, friendId: t.friendId) } },
            set: { if $0 == nil { chatTarget = nil } }
        )) { dest in
            ChatView(conversationId: dest.id, friendName: dest.name)
        }
        .sheet(isPresented: $showContactsPicker) {
            ContactsPickerView { name in
                showContactsPicker = false
                vm.searchQuery = name
                Task { await vm.search() }
            }
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
            Image(systemName: "person.badge.minus")
                .foregroundColor(Color.nostiaTextSecond).padding(8)
                .background(Color.white.opacity(0.1)).clipShape(Circle())
        }
    }
}

struct ProfileDestination: Identifiable, Hashable {
    let id: Int
}

struct ChatDestination: Identifiable, Hashable {
    let id: Int
    let name: String
    let friendId: Int
}

struct FollowUserRow<Trailing: View>: View {
    let user: FollowUser
    var onProfileTap: (() -> Void)? = nil
    let trailingContent: () -> Trailing

    var body: some View {
        HStack(spacing: 12) {
            Button {
                onProfileTap?()
            } label: {
                HStack(spacing: 12) {
                    AvatarView(initial: user.initial, color: Color.nostiaAccent, size: 50)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(user.name).font(.headline).foregroundColor(.white)
                        Text("@\(user.username)").font(.footnote).foregroundColor(Color.nostiaTextSecond)
                    }
                }
            }
            .buttonStyle(.plain)
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

struct ContactsPickerView: View {
    let onSelect: (String) -> Void

    @State private var contactNames: [String] = []
    @State private var isLoading = true
    @State private var denied = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    LoadingView()
                } else if denied {
                    EmptyStateView(
                        icon: "person.crop.circle.badge.xmark",
                        text: "Contacts Access Denied",
                        sub: "Enable contacts access in Settings to find people on Nostia"
                    )
                } else if contactNames.isEmpty {
                    EmptyStateView(icon: "person.2", text: "No Contacts Found", sub: "")
                } else {
                    List(contactNames, id: \.self) { name in
                        Button {
                            onSelect(name)
                        } label: {
                            HStack(spacing: 12) {
                                AvatarView(
                                    initial: String(name.prefix(1)).uppercased(),
                                    color: Color.nostiaAccent,
                                    size: 40
                                )
                                Text(name).foregroundColor(.white).font(.body)
                            }
                            .padding(.vertical, 4)
                        }
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                    }
                    .listStyle(.plain)
                    .background(.clear)
                    .scrollContentBackground(.hidden)
                }
            }
            .background(.clear)
            .navigationTitle("Find via Contacts")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(Color.nostiaAccent)
                }
            }
        }
        .presentationBackground(.ultraThinMaterial)
        .task { await loadContacts() }
    }

    private func loadContacts() async {
        let store = CNContactStore()
        let status = CNContactStore.authorizationStatus(for: .contacts)
        guard status != .denied && status != .restricted else {
            isLoading = false
            denied = true
            return
        }
        do {
            if status == .notDetermined {
                let granted = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Bool, Error>) in
                    store.requestAccess(for: .contacts) { granted, error in
                        if let error { continuation.resume(throwing: error) }
                        else { continuation.resume(returning: granted) }
                    }
                }
                guard granted else {
                    isLoading = false
                    denied = true
                    return
                }
            }
            let keys = [CNContactGivenNameKey, CNContactFamilyNameKey] as [CNKeyDescriptor]
            let request = CNContactFetchRequest(keysToFetch: keys)
            var names: [String] = []
            try store.enumerateContacts(with: request) { contact, _ in
                let name = [contact.givenName, contact.familyName]
                    .filter { !$0.isEmpty }.joined(separator: " ")
                if !name.trimmingCharacters(in: .whitespaces).isEmpty {
                    names.append(name)
                }
            }
            contactNames = names.sorted()
        } catch {
            denied = true
        }
        isLoading = false
    }
}
