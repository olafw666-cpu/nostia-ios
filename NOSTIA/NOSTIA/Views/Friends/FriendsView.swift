import SwiftUI
import Contacts

struct FriendsView: View {
    @StateObject private var vm = FriendsViewModel()
    @State private var chatDestination: ChatDestination?
    @State private var profileDestination: ProfileDestination?
    @State private var showContactsPicker = false
    @State private var userToUnfollow: FollowUser?
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var responsive: ResponsiveLayoutManager

    var body: some View {
        VStack(spacing: 0) {
            NostiaScreenTitle(title: "Following")
                .padding(.horizontal, responsive.spacing(16))
                .padding(.top, 6)

            // Search bar
            HStack(spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass").foregroundColor(Color.nostiaTextSecond)
                    TextField("Search users...", text: $vm.searchQuery)
                        .foregroundColor(Color.nostiaTextPrimary)
                        .submitLabel(.search)
                        .onSubmit { Task { await vm.search() } }
                        .autocorrectionDisabled().textInputAutocapitalization(.never)
                    if !vm.searchQuery.isEmpty {
                        Button { vm.clearSearch() } label: {
                            Image(systemName: "xmark.circle.fill").foregroundColor(Color.nostiaTextMuted)
                        }
                    }
                }
                .padding(responsive.spacing(12))
                .nostiaWarmCard(in: RoundedRectangle(cornerRadius: 12))

                Button("Search") {
                    hideKeyboard()
                    Task { await vm.search() }
                }
                    .font(.subheadline.bold()).foregroundColor(.white)
                    .padding(.horizontal, responsive.spacing(16)).padding(.vertical, responsive.spacing(12))
                    .background(Color.nostiaAccent).cornerRadius(12)
            }
            .padding(.horizontal, responsive.spacing(16)).padding(.vertical, responsive.spacing(12))

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
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
            }
            .padding(.horizontal, responsive.spacing(16))
            .padding(.bottom, 8)

            if vm.isSearching {
                SearchSkeletonView()
            } else if vm.searchPerformed {
                if vm.searchResults.isEmpty {
                    EmptyStateView(icon: "person", text: "No users found", sub: "Try a different name or username")
                } else {
                    List(vm.searchResults) { user in
                        UserSearchRow(user: user, onFollow: { Task { await vm.follow(userId: user.id) } })
                            .listRowBackground(Color.clear).listRowSeparator(.hidden)
                            .contextMenu {
                                if authManager.isDev {
                                    Button(role: .destructive) {
                                        Task { await vm.adminDeleteUser(id: user.id) }
                                    } label: {
                                        Label("Delete User", systemImage: "person.crop.circle.badge.minus")
                                    }
                                }
                            }
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
                .padding(.horizontal, responsive.spacing(16)).padding(.bottom, 8)

                if vm.isLoading && vm.followers.isEmpty && vm.following.isEmpty { FollowSkeletonView() }
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
                        .contextMenu {
                            if authManager.isDev {
                                Button(role: .destructive) {
                                    Task { await vm.adminDeleteUser(id: user.id) }
                                } label: {
                                    Label("Delete User", systemImage: "person.crop.circle.badge.minus")
                                }
                            }
                        }
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
                                AnyView(unfollowButton(for: user))
                            }
                        )
                        .listRowBackground(Color.clear).listRowSeparator(.hidden)
                        .contextMenu {
                            if authManager.isDev {
                                Button(role: .destructive) {
                                    Task { await vm.adminDeleteUser(id: user.id) }
                                } label: {
                                    Label("Delete User", systemImage: "person.crop.circle.badge.minus")
                                }
                            }
                        }
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
        .safeAreaInset(edge: .bottom) { Color.clear.frame(height: 84) }
        .scrollDismissesKeyboard(.immediately)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { hideKeyboard() }
                    .foregroundColor(Color.nostiaAccent)
            }
        }
        .task { await vm.loadAll() }
        .alert("Error", isPresented: Binding(get: { vm.errorMessage != nil }, set: { if !$0 { vm.errorMessage = nil } })) {
            Button("OK") { vm.errorMessage = nil }
        } message: { Text(vm.errorMessage ?? "") }
        .alert("Unfollow \(userToUnfollow?.name ?? "")?", isPresented: Binding(
            get: { userToUnfollow != nil },
            set: { if !$0 { userToUnfollow = nil } }
        )) {
            Button("Unfollow", role: .destructive) {
                guard let u = userToUnfollow else { return }
                userToUnfollow = nil
                Task { await vm.unfollow(userId: u.id) }
            }
            Button("Cancel", role: .cancel) { userToUnfollow = nil }
        }
        .navigationDestination(item: $profileDestination) { dest in
            PublicProfileView(userId: dest.id)
        }
        .navigationDestination(item: $chatDestination) { dest in
            ChatView(conversationId: dest.id, friendName: dest.name, friendId: dest.friendId)
        }
        .sheet(isPresented: $showContactsPicker) {
            ContactsPickerView()
                .environmentObject(responsive)
                .onDisappear { Task { await vm.loadAll() } }
        }
    }

    @ViewBuilder
    private func messageButton(for user: FollowUser) -> some View {
        Button {
            Task {
                if let conv = try? await MessagesAPI.shared.getOrCreateConversation(withUserId: user.id) {
                    chatDestination = ChatDestination(id: conv.id, name: user.name, friendId: user.id)
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
            userToUnfollow = user
        } label: {
            Image(systemName: "person.badge.minus")
                .foregroundColor(Color.nostiaTextSecond).padding(8)
                .background(Color.nostiaButton).clipShape(Circle())
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
    @EnvironmentObject var responsive: ResponsiveLayoutManager

    var body: some View {
        HStack(spacing: 12) {
            Button {
                onProfileTap?()
            } label: {
                HStack(spacing: 12) {
                    AvatarView(initial: user.initial, color: Color.nostiaAccent, size: responsive.spacing(50))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(user.name).font(.headline).foregroundColor(Color.nostiaTextPrimary)
                        Text("@\(user.username)").font(.footnote).foregroundColor(Color.nostiaTextSecond)
                    }
                }
            }
            .buttonStyle(.plain)
            Spacer()
            trailingContent()
        }
        .padding(responsive.spacing(16))
        .nostiaCard(in: RoundedRectangle(cornerRadius: 16))
        .padding(.vertical, 4)
    }
}

struct UserSearchRow: View {
    let user: UserSearchResult
    let onFollow: () -> Void
    @EnvironmentObject var responsive: ResponsiveLayoutManager

    var body: some View {
        HStack(spacing: 12) {
            AvatarView(initial: String(user.name.prefix(1)).uppercased(), color: Color.nostiaAccent, size: responsive.spacing(50))
            VStack(alignment: .leading, spacing: 2) {
                Text(user.name).font(.headline).foregroundColor(Color.nostiaTextPrimary)
                Text("@\(user.username)").font(.footnote).foregroundColor(Color.nostiaTextSecond)
            }
            Spacer()
            Button { onFollow() } label: {
                Image(systemName: "person.badge.plus").foregroundColor(.white).padding(8)
                    .background(Color.nostiaAccent).clipShape(Circle())
                    .shadow(color: Color.nostiaAccent.opacity(0.4), radius: 6)
            }
        }
        .padding(responsive.spacing(16))
        .nostiaCard(in: RoundedRectangle(cornerRadius: 16))
        .padding(.vertical, 4)
    }
}

struct TabButton: View {
    let title: String; let isActive: Bool; let action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.bold())
                .foregroundColor(isActive ? .white : Color(hex: "4B5563"))
                .frame(maxWidth: .infinity).padding(.vertical, 11)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(isActive ? Color.nostiaAccent : Color.white)
                )
                .overlay(isActive ? nil : RoundedRectangle(cornerRadius: 12).stroke(Color.nostriaBorder, lineWidth: 1))
                .shadow(color: Color.nostiaShadow.opacity(isActive ? 0.0 : 0.05), radius: 8, y: 2)
        }
    }
}

struct ContactsPickerView: View {
    @EnvironmentObject var responsive: ResponsiveLayoutManager
    @Environment(\.dismiss) private var dismiss

    @State private var onNostia: [ContactMatch] = []
    @State private var toInvite: [InviteContact] = []
    @State private var isLoading = true
    @State private var denied = false
    @State private var followedIds: Set<Int> = []

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    LoadingView()
                } else if denied {
                    VStack(spacing: 16) {
                        EmptyStateView(
                            icon: "person.crop.circle.badge.xmark",
                            text: "Contacts Access Denied",
                            sub: "Enable contacts access in Settings to find friends on Nostia"
                        )
                        Button("Open Settings") {
                            if let url = URL(string: UIApplication.openSettingsURLString) {
                                UIApplication.shared.open(url)
                            }
                        }
                        .font(.subheadline.bold()).foregroundColor(.white)
                        .padding(.horizontal, 24).padding(.vertical, 12)
                        .background(Color.nostiaAccent).cornerRadius(12)
                    }
                } else if onNostia.isEmpty && toInvite.isEmpty {
                    EmptyStateView(icon: "person.2", text: "No Contacts Found", sub: "Add contacts to your device to find friends")
                } else {
                    List {
                        if !onNostia.isEmpty {
                            Section {
                                ForEach(onNostia) { match in
                                    ContactOnNostiaRow(
                                        match: match,
                                        isFollowed: followedIds.contains(match.nostiaUser.id),
                                        onFollow: {
                                            let uid = match.nostiaUser.id
                                            followedIds.insert(uid)
                                            Task {
                                                try? await FriendsAPI.shared.follow(userId: uid)
                                            }
                                        }
                                    )
                                    .listRowBackground(Color.clear)
                                    .listRowSeparator(.hidden)
                                }
                            } header: {
                                Text("On Nostia")
                                    .font(.caption.bold())
                                    .foregroundColor(Color.nostiaTextSecond)
                                    .textCase(nil)
                            }
                        }
                        if !toInvite.isEmpty {
                            Section {
                                ForEach(toInvite) { contact in
                                    ContactInviteRow(contact: contact)
                                        .listRowBackground(Color.clear)
                                        .listRowSeparator(.hidden)
                                }
                            } header: {
                                Text("Invite to Nostia")
                                    .font(.caption.bold())
                                    .foregroundColor(Color.nostiaTextSecond)
                                    .textCase(nil)
                            }
                        }
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
                    Button("Done") { dismiss() }
                        .foregroundColor(Color.nostiaAccent)
                }
            }
        }
        .presentationBackground(Color.nostiaBackground)
        .task { await loadContacts() }
    }

    private func loadContacts() async {
        let store = CNContactStore()
        let status = CNContactStore.authorizationStatus(for: .contacts)
        guard status != .denied && status != .restricted else {
            isLoading = false; denied = true; return
        }
        do {
            if status == .notDetermined {
                let granted = try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Bool, Error>) in
                    store.requestAccess(for: .contacts) { ok, err in
                        if let err { cont.resume(throwing: err) } else { cont.resume(returning: ok) }
                    }
                }
                guard granted else { isLoading = false; denied = true; return }
            }

            let keys = [
                CNContactGivenNameKey, CNContactFamilyNameKey,
                CNContactEmailAddressesKey, CNContactPhoneNumbersKey
            ] as [CNKeyDescriptor]
            let request = CNContactFetchRequest(keysToFetch: keys)
            var rawContacts: [(name: String, email: String?, phone: String?)] = []
            try store.enumerateContacts(with: request) { contact, _ in
                let name = [contact.givenName, contact.familyName]
                    .filter { !$0.isEmpty }.joined(separator: " ")
                guard !name.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                let email = contact.emailAddresses.first.map { String($0.value) }
                let phone = contact.phoneNumbers.first.map { $0.value.stringValue }
                rawContacts.append((name: name, email: email, phone: phone))
            }

            let allEmails = rawContacts.compactMap(\.email)
            let emailToUser: [String: UserSearchResult]
            if allEmails.isEmpty {
                emailToUser = [:]
            } else {
                emailToUser = (try? await FriendsAPI.shared.lookupContacts(emails: allEmails)) ?? [:]
            }

            var matches: [ContactMatch] = []
            var invites: [InviteContact] = []
            for c in rawContacts {
                if let email = c.email?.lowercased(), let user = emailToUser[email] {
                    matches.append(ContactMatch(name: c.name, email: email, phone: c.phone, nostiaUser: user))
                } else {
                    invites.append(InviteContact(name: c.name, phone: c.phone, email: c.email))
                }
            }

            // Attach pending invite state to each invite contact
            let inviteRecords = (try? await FriendsAPI.shared.getContactInvites()) ?? []
            let isoFormatter = ISO8601DateFormatter()
            var inviteByEmail: [String: InviteInfo] = [:]
            var inviteByPhone: [String: InviteInfo] = [:]
            for rec in inviteRecords where rec.status == "pending" {
                if let e = rec.contactEmail, let d = isoFormatter.date(from: rec.expiresAt) {
                    inviteByEmail[e.lowercased()] = InviteInfo(token: rec.token, expiresAt: d)
                }
                if let p = rec.contactPhone, let d = isoFormatter.date(from: rec.expiresAt) {
                    inviteByPhone[p] = InviteInfo(token: rec.token, expiresAt: d)
                }
            }
            invites = invites.map { c in
                var c = c
                if let e = c.email, let info = inviteByEmail[e.lowercased()] {
                    c.pendingInvite = info
                } else if let p = c.phone, let info = inviteByPhone[p] {
                    c.pendingInvite = info
                }
                return c
            }

            onNostia = matches.sorted { $0.name < $1.name }
            toInvite = invites.sorted { $0.name < $1.name }
        } catch {
            denied = true
        }
        isLoading = false
    }
}

private struct ContactOnNostiaRow: View {
    let match: ContactMatch
    let isFollowed: Bool
    let onFollow: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            AvatarView(initial: String(match.name.prefix(1)).uppercased(), color: Color.nostiaAccent, size: 44)
            VStack(alignment: .leading, spacing: 2) {
                Text(match.name).font(.headline).foregroundColor(Color.nostiaTextPrimary)
                Text("@\(match.nostiaUser.username)").font(.footnote).foregroundColor(Color.nostiaTextSecond)
            }
            Spacer()
            if isFollowed {
                Text("Following")
                    .font(.caption.bold()).foregroundColor(Color.nostiaTextSecond)
                    .padding(.horizontal, 12).padding(.vertical, 6)
                    .background(Color.nostiaButton).cornerRadius(8)
            } else {
                Button(action: onFollow) {
                    Text("Follow")
                        .font(.caption.bold()).foregroundColor(.white)
                        .padding(.horizontal, 12).padding(.vertical, 6)
                        .background(Color.nostiaAccent).cornerRadius(8)
                }
            }
        }
        .padding(16)
        .nostiaCard(in: RoundedRectangle(cornerRadius: 16))
        .padding(.vertical, 4)
    }
}

private enum InviteRowState: Equatable {
    case idle
    case creating
    case pending(expiresAt: Date)
    case shareReady(url: URL, message: String)
}

private struct ContactInviteRow: View {
    let contact: InviteContact

    @State private var inviteState: InviteRowState
    @State private var showShareSheet = false
    @State private var pendingExpiresAt: Date = Date()

    init(contact: InviteContact) {
        self.contact = contact
        if let info = contact.pendingInvite, info.expiresAt > Date() {
            _inviteState = State(initialValue: .pending(expiresAt: info.expiresAt))
        } else {
            _inviteState = State(initialValue: .idle)
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            AvatarView(initial: String(contact.name.prefix(1)).uppercased(), color: Color.nostiaTextSecond.opacity(0.6), size: 44)
            VStack(alignment: .leading, spacing: 2) {
                Text(contact.name).font(.headline).foregroundColor(Color.nostiaTextPrimary)
                if let phone = contact.phone {
                    Text(phone).font(.footnote).foregroundColor(Color.nostiaTextSecond)
                } else if let email = contact.email {
                    Text(email).font(.footnote).foregroundColor(Color.nostiaTextSecond)
                }
            }
            Spacer()
            trailingButton
        }
        .padding(16)
        .nostiaCard(in: RoundedRectangle(cornerRadius: 16))
        .padding(.vertical, 4)
        .onChange(of: inviteState) { _, new in
            if case .shareReady = new { showShareSheet = true }
        }
        .sheet(isPresented: $showShareSheet, onDismiss: {
            if case .shareReady = inviteState {
                inviteState = .pending(expiresAt: pendingExpiresAt)
            }
        }) {
            if case .shareReady(let url, let message) = inviteState {
                ActivityView(activityItems: [message, url])
            }
        }
    }

    @ViewBuilder
    private var trailingButton: some View {
        switch inviteState {
        case .idle:
            Button("Invite") { Task { await sendInvite() } }
                .font(.caption.bold()).foregroundColor(Color.nostiaAccent)
                .padding(.horizontal, 12).padding(.vertical, 6)
                .background(Color.nostiaAccent.opacity(0.15)).cornerRadius(8)
        case .creating:
            ProgressView().tint(Color.nostiaAccent).frame(width: 60)
        case .pending:
            HStack(spacing: 4) {
                Image(systemName: "clock")
                Text("Pending")
            }
            .font(.caption.bold()).foregroundColor(Color.nostiaTextSecond)
            .padding(.horizontal, 12).padding(.vertical, 6)
            .background(Color.nostiaButton).cornerRadius(8)
        case .shareReady:
            EmptyView()
        }
    }

    private func sendInvite() async {
        inviteState = .creating
        do {
            let record = try await FriendsAPI.shared.createContactInvite(
                email: contact.email, phone: contact.phone
            )
            guard record.status != "already_joined" else { inviteState = .idle; return }
            let isoFormatter = ISO8601DateFormatter()
            pendingExpiresAt = isoFormatter.date(from: record.expiresAt) ?? Date().addingTimeInterval(7 * 24 * 3600)
            let link = "https://nostia.io/join/\(record.token)"
            let firstName = contact.name.components(separatedBy: " ").first ?? contact.name
            let msg = "Hey \(firstName)! I'm on Nostia, an app for sharing travel moments with friends. Join me here: \(link)"
            if let url = URL(string: link) {
                inviteState = .shareReady(url: url, message: msg)
            } else {
                inviteState = .idle
            }
        } catch {
            inviteState = .idle
        }
    }
}

private struct ActivityView: UIViewControllerRepresentable {
    let activityItems: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }
    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}
