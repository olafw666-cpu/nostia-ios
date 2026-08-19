import SwiftUI

struct VaultDetailView: View {
    let trip: Trip
    @ObservedObject var tripsVM: TripsViewModel

    @State private var selectedTab = 0
    @State private var showEditMenu = false
    // ONE sheet slot and ONE alert slot for the whole screen. Stacked
    // .sheet(isPresented:)/.alert(isPresented:) modifiers on the same view shadow each
    // other, and every one of these is raised from inside the "Vault Options"
    // confirmation dialog — so the dialog's own dismissal raced the presentation and
    // "Add Member"/"Kick Member"/"Transfer Leadership" frequently opened nothing at all.
    @State private var activeSheet: VaultDetailSheet?
    @State private var activeAlert: VaultDetailAlert?
    @State private var editTitle = ""
    @State private var editDescription = ""
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var responsive: ResponsiveLayoutManager

    // Use the latest trip data from the VM if available
    private var currentTrip: Trip {
        tripsVM.trips.first(where: { $0.id == trip.id }) ?? trip
    }

    private var isLeader: Bool {
        guard let me = AuthManager.shared.currentUserId else { return false }
        return currentTrip.vaultLeaderId == me
    }

    private var myParticipant: TripParticipant? {
        guard let me = AuthManager.shared.currentUserId else { return nil }
        return currentTrip.participants?.first(where: { $0.id == me })
    }

    private var isKicked: Bool { myParticipant?.isKicked ?? false }
    private var isActiveMember: Bool { myParticipant != nil && !isKicked }

    var body: some View {
        VStack(spacing: 0) {
            // Tab selector — Plan sits between the money and the talk (mission: plan
            // the trip, fund it together).
            AtlasSegmented(segments: ["Vault", "Plan", "Chat"], selection: $selectedTab)
                .padding(.horizontal, responsive.spacing(16)).padding(.vertical, responsive.spacing(10))

            if selectedTab == 0 {
                VaultContentView(tripId: currentTrip.id, isKicked: isKicked, participants: currentTrip.activeParticipants)
            } else if selectedTab == 1 {
                VaultPlanView(tripId: currentTrip.id, isKicked: isKicked)
            } else {
                VaultChatView(tripId: currentTrip.id, isKicked: isKicked)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        // Pushed destinations don't inherit the tab root's themed canvas — without this
        // the vault detail sits on the system background (black in dark mode).
        .background(Color.nostiaBackground.ignoresSafeArea())
        .ignoresSafeArea(.keyboard)
        // NOTE: deliberately no .hidesAppTabBar() here. This screen is only ever reached
        // inside a sheet (MainTabView's vault sheet, or Profile -> Your Vaults), and a
        // sheet already covers the floating AtlasTabBar — so hiding it bought nothing but
        // a global counter that leaked when the sheet tore the whole stack down without
        // firing onDisappear, leaving the app with no tab bar for the rest of the session.
        .navigationTitle(currentTrip.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar {
            if isActiveMember {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { activeSheet = .qrInvite } label: {
                        Image(systemName: "qrcode").foregroundColor(Color.nostiaTextPrimary)
                    }
                }
            }
            if isLeader {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showEditMenu = true } label: {
                        Image(systemName: "ellipsis.circle").foregroundColor(Color.nostiaTextPrimary)
                    }
                }
            }
        }
        .confirmationDialog("Vault Options", isPresented: $showEditMenu, titleVisibility: .visible) {
            Button("Edit Title") {
                editTitle = currentTrip.title
                activeAlert = .editTitle
            }
            Button("Edit Description") {
                editDescription = currentTrip.description ?? ""
                activeAlert = .editDescription
            }
            Button("Add Member") { activeSheet = .addMember }
            Button("Kick Member") { activeSheet = .kickMember }
            Button("Transfer Leadership") { activeSheet = .transferLeadership }
            Button("Delete Vault", role: .destructive) { activeAlert = .confirmDelete }
            Button("Cancel", role: .cancel) {}
        }
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .addMember:          AddMemberSheet(trip: currentTrip, tripsVM: tripsVM)
            case .kickMember:         KickMemberSheet(trip: currentTrip, tripsVM: tripsVM)
            case .transferLeadership: TransferLeadershipSheet(trip: currentTrip, tripsVM: tripsVM)
            case .qrInvite:           VaultQRView(trip: currentTrip)
            }
        }
        .alert(
            activeAlert?.title ?? "",
            isPresented: Binding(get: { activeAlert != nil }, set: { if !$0 { activeAlert = nil } }),
            presenting: activeAlert
        ) { alert in
            alertActions(for: alert)
        } message: { alert in
            if let message = alert.message { Text(message) }
        }
        // The vault list's error alert lives on TripsView, which is off-screen while this
        // screen is pushed — so a failed rename/kick/transfer surfaced nowhere and the
        // buttons simply appeared to do nothing. Bridge the VM's one-shot error here.
        .onChange(of: tripsVM.errorMessage) { msg in
            if let msg, !msg.isEmpty {
                activeAlert = .error(msg)
                tripsVM.errorMessage = nil
            }
        }
    }

    @ViewBuilder
    private func alertActions(for alert: VaultDetailAlert) -> some View {
        switch alert {
        case .editTitle:
            TextField("Vault title", text: $editTitle)
            Button("Cancel", role: .cancel) {}
            Button("Save") {
                let newTitle = editTitle.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !newTitle.isEmpty else { return }
                Task { _ = await tripsVM.updateTrip(currentTrip.id, title: newTitle, description: currentTrip.description) }
            }
        case .editDescription:
            TextField("Description", text: $editDescription)
            Button("Cancel", role: .cancel) {}
            Button("Save") {
                let newDescription = editDescription.trimmingCharacters(in: .whitespacesAndNewlines)
                Task { _ = await tripsVM.updateTrip(currentTrip.id, title: currentTrip.title, description: newDescription.isEmpty ? nil : newDescription) }
            }
        case .confirmDelete:
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                Task {
                    // Only leave the screen if the vault actually went away. This used to
                    // dismiss unconditionally, so a rejected delete looked like it worked
                    // until the list reappeared with the vault still in it.
                    if await tripsVM.deleteTrip(currentTrip.id) { dismiss() }
                }
            }
        case .error:
            Button("OK", role: .cancel) {}
        }
    }
}

// MARK: - Single sheet / alert slots

enum VaultDetailSheet: Identifiable {
    case addMember, kickMember, transferLeadership, qrInvite
    var id: Int {
        switch self {
        case .addMember: return 0
        case .kickMember: return 1
        case .transferLeadership: return 2
        case .qrInvite: return 3
        }
    }
}

enum VaultDetailAlert: Identifiable {
    case editTitle
    case editDescription
    case confirmDelete
    case error(String)

    var id: String {
        switch self {
        case .editTitle: return "editTitle"
        case .editDescription: return "editDescription"
        case .confirmDelete: return "confirmDelete"
        case .error(let msg): return "error:\(msg)"
        }
    }

    var title: String {
        switch self {
        case .editTitle: return "Edit Title"
        case .editDescription: return "Edit Description"
        case .confirmDelete: return "Delete Vault"
        case .error: return "Something Went Wrong"
        }
    }

    var message: String? {
        switch self {
        case .confirmDelete: return "All expenses and messages will be removed. This cannot be undone."
        case .error(let msg): return msg
        case .editTitle, .editDescription: return nil
        }
    }
}

// MARK: - Add Member Sheet

struct AddMemberSheet: View {
    let trip: Trip
    @ObservedObject var tripsVM: TripsViewModel
    @State private var followers: [FollowUser] = []
    @State private var selectedIds: Set<Int> = []
    @State private var searchText = ""
    @State private var isLoading = true
    @State private var isAdding = false
    @State private var errorMessage: String?
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var responsive: ResponsiveLayoutManager

    private var existingMemberIds: Set<Int> {
        Set((trip.participants ?? []).filter { !$0.isKicked }.map { $0.id })
    }

    private var eligibleFollowers: [FollowUser] {
        let members = existingMemberIds
        let base = followers.filter { !members.contains($0.id) }
        guard !searchText.isEmpty else { return base }
        let q = searchText.lowercased()
        return base.filter { $0.username.lowercased().contains(q) || $0.name.lowercased().contains(q) }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass").foregroundColor(Color.nostiaTextMuted)
                    TextField("Search followers", text: $searchText)
                        .foregroundColor(Color.nostiaTextPrimary)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                }
                .padding(12)
                .nostiaCard(in: RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal, responsive.spacing(16))
                .padding(.vertical, 8)

                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        if isLoading {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                                .padding(.top, 40)
                        } else if eligibleFollowers.isEmpty {
                            EmptyStateView(icon: "person.badge.plus", text: "No eligible users to add", sub: "")
                                .padding(.top, 40)
                        } else {
                            ForEach(eligibleFollowers) { follower in
                                let isSelected = selectedIds.contains(follower.id)
                                HStack(spacing: 12) {
                                    AvatarView(
                                        initial: follower.initial,
                                        color: Color.nostiaAccent,
                                        size: responsive.spacing(38)
                                    )
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(follower.name)
                                            .font(.nostiaBody(responsive.fontSize(14), weight: .semibold))
                                            .foregroundColor(Color.nostiaTextPrimary)
                                        Text("@\(follower.username)")
                                            .font(.nostiaBody(responsive.fontSize(12)))
                                            .foregroundColor(Color.nostiaTextSecond)
                                    }
                                    Spacer()
                                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                                        .foregroundColor(isSelected ? Color.nostiaAccent : Color.nostiaTextSecond)
                                        .font(.nostiaBody(22))
                                }
                                .padding(responsive.spacing(14))
                                .nostiaCard(in: RoundedRectangle(cornerRadius: 14))
                                .padding(.horizontal, responsive.spacing(16))
                                .padding(.vertical, 4)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    if selectedIds.contains(follower.id) {
                                        selectedIds.remove(follower.id)
                                    } else {
                                        selectedIds.insert(follower.id)
                                    }
                                }
                            }
                        }
                        if let err = errorMessage {
                            Text(err)
                                .font(.footnote)
                                .foregroundColor(Color.nostriaDanger)
                                .padding(.horizontal, responsive.spacing(20))
                                .padding(.top, 12)
                        }
                    }
                    .padding(.top, 8)
                    .frame(maxWidth: responsive.sheetMaxWidth)
                    .frame(maxWidth: .infinity)
                }

                Button {
                    Task {
                        isAdding = true
                        let ok = await tripsVM.addVaultMembers(tripId: trip.id, userIds: Array(selectedIds))
                        if !ok { errorMessage = tripsVM.errorMessage }
                        isAdding = false
                        if ok { dismiss() }
                    }
                } label: {
                    HStack {
                        if isAdding { ProgressView().tint(.white).padding(.trailing, 4) }
                        Text(selectedIds.count > 1 ? "Add \(selectedIds.count) Members" : "Add Member")
                            .font(.nostiaBody(responsive.fontSize(15), weight: .semibold))
                            .foregroundColor(.white)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, responsive.spacing(14))
                    .background(selectedIds.isEmpty ? Color.nostiaAccent.opacity(0.4) : Color.nostiaAccent)
                    .cornerRadius(12)
                }
                .disabled(selectedIds.isEmpty || isAdding)
                .padding(.horizontal, responsive.spacing(16))
                .padding(.vertical, 12)
            }
            .background(.clear)
            .navigationTitle("Add Member")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cancel") { dismiss() }.foregroundColor(Color.nostiaAccent)
                }
            }
            .task {
                do {
                    followers = try await FriendsAPI.shared.getFollowers()
                } catch {
                    errorMessage = "Failed to load followers."
                }
                isLoading = false
            }
        }
        .presentationBackground(Color.nostiaBackground)
    }
}

// MARK: - Kick Member Sheet

struct KickMemberSheet: View {
    let trip: Trip
    @ObservedObject var tripsVM: TripsViewModel
    @State private var actionLoadingId: Int?
    @State private var errorMessage: String?
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var responsive: ResponsiveLayoutManager

    private var kickableParticipants: [TripParticipant] {
        guard let me = AuthManager.shared.currentUserId else { return [] }
        return (trip.participants ?? []).filter { $0.id != me && !$0.isKicked }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if kickableParticipants.isEmpty {
                        EmptyStateView(icon: "person.2", text: "No members to kick", sub: "")
                            .padding(.top, 40)
                    } else {
                        ForEach(kickableParticipants) { participant in
                            HStack(spacing: 12) {
                                AvatarView(
                                    initial: String((participant.name ?? "U").prefix(1)).uppercased(),
                                    color: Color.nostiaAccent, size: responsive.spacing(38)
                                )
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(participant.name ?? "Unknown").font(.nostiaBody(responsive.fontSize(14), weight: .semibold)).foregroundColor(Color.nostiaTextPrimary)
                                    if let uname = participant.username {
                                        Text("@\(uname)").font(.nostiaBody(responsive.fontSize(12))).foregroundColor(Color.nostiaTextSecond)
                                    }
                                }
                                Spacer()
                                if actionLoadingId == participant.id {
                                    ProgressView().tint(Color.nostriaDanger)
                                } else {
                                    Button {
                                        Task {
                                            actionLoadingId = participant.id
                                            let ok = await tripsVM.kickParticipant(tripId: trip.id, userId: participant.id)
                                            if !ok { errorMessage = tripsVM.errorMessage }
                                            actionLoadingId = nil
                                            if ok { dismiss() }
                                        }
                                    } label: {
                                        Text("Kick")
                                            .font(.nostiaBody(responsive.fontSize(13), weight: .semibold)).foregroundColor(.white)
                                            .padding(.horizontal, responsive.spacing(14)).padding(.vertical, responsive.spacing(8))
                                            .background(Color.nostriaDanger).cornerRadius(8)
                                    }
                                }
                            }
                            .padding(responsive.spacing(14))
                            .nostiaCard(in: RoundedRectangle(cornerRadius: 14))
                            .padding(.horizontal, responsive.spacing(16)).padding(.vertical, 4)
                        }
                    }
                    if let err = errorMessage {
                        Text(err).font(.footnote).foregroundColor(Color.nostriaDanger)
                            .padding(.horizontal, responsive.spacing(20)).padding(.top, 12)
                    }
                }
                .padding(.top, 8)
                .frame(maxWidth: responsive.sheetMaxWidth)
                .frame(maxWidth: .infinity)
            }
            .background(.clear)
            .navigationTitle("Kick Member")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }.foregroundColor(Color.nostiaAccent)
                }
            }
        }
        .presentationBackground(Color.nostiaBackground)
    }
}

// MARK: - Transfer Leadership Sheet

struct TransferLeadershipSheet: View {
    let trip: Trip
    @ObservedObject var tripsVM: TripsViewModel
    @State private var actionLoadingId: Int?
    @State private var errorMessage: String?
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var responsive: ResponsiveLayoutManager

    private var eligibleParticipants: [TripParticipant] {
        guard let me = AuthManager.shared.currentUserId else { return [] }
        return (trip.participants ?? []).filter { $0.id != me && !$0.isKicked }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if eligibleParticipants.isEmpty {
                        EmptyStateView(icon: "person.badge.key", text: "No eligible members", sub: "Add friends to transfer leadership")
                            .padding(.top, 40)
                    } else {
                        ForEach(eligibleParticipants) { participant in
                            HStack(spacing: 12) {
                                AvatarView(
                                    initial: String((participant.name ?? "U").prefix(1)).uppercased(),
                                    color: Color.nostiaAccent, size: responsive.spacing(38)
                                )
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(participant.name ?? "Unknown").font(.nostiaBody(responsive.fontSize(14), weight: .semibold)).foregroundColor(Color.nostiaTextPrimary)
                                    if let uname = participant.username {
                                        Text("@\(uname)").font(.nostiaBody(responsive.fontSize(12))).foregroundColor(Color.nostiaTextSecond)
                                    }
                                }
                                Spacer()
                                if actionLoadingId == participant.id {
                                    ProgressView().tint(Color.nostiaAccent)
                                } else {
                                    Button {
                                        Task {
                                            actionLoadingId = participant.id
                                            let ok = await tripsVM.transferLeadership(tripId: trip.id, newLeaderId: participant.id)
                                            if !ok { errorMessage = tripsVM.errorMessage }
                                            actionLoadingId = nil
                                            if ok { dismiss() }
                                        }
                                    } label: {
                                        Text("Make Leader")
                                            .font(.nostiaBody(responsive.fontSize(13), weight: .semibold)).foregroundColor(.white)
                                            .padding(.horizontal, responsive.spacing(14)).padding(.vertical, responsive.spacing(8))
                                            .background(Color.nostiaAccent).cornerRadius(8)
                                    }
                                }
                            }
                            .padding(responsive.spacing(14))
                            .nostiaCard(in: RoundedRectangle(cornerRadius: 14))
                            .padding(.horizontal, responsive.spacing(16)).padding(.vertical, 4)
                        }
                    }
                    if let err = errorMessage {
                        Text(err).font(.footnote).foregroundColor(Color.nostriaDanger)
                            .padding(.horizontal, responsive.spacing(20)).padding(.top, 12)
                    }
                }
                .padding(.top, 8)
                .frame(maxWidth: responsive.sheetMaxWidth)
                .frame(maxWidth: .infinity)
            }
            .background(.clear)
            .navigationTitle("Transfer Leadership")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }.foregroundColor(Color.nostiaAccent)
                }
            }
        }
        .presentationBackground(Color.nostiaBackground)
    }
}
