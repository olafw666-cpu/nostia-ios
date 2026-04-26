import SwiftUI

struct VaultDetailView: View {
    let trip: Trip
    @ObservedObject var tripsVM: TripsViewModel

    @State private var selectedTab = 0
    @State private var showEditMenu = false
    @State private var showEditTitle = false
    @State private var showEditDescription = false
    @State private var showKickSheet = false
    @State private var showTransferSheet = false
    @State private var showDeleteAlert = false
    @State private var showQRInvite = false
    @State private var showAddExpense = false
    @State private var editTitle = ""
    @State private var editDescription = ""
    @State private var isSaving = false
    @Environment(\.dismiss) private var dismiss

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
            // Tab selector
            HStack(spacing: 8) {
                TabButton(title: "Vault", isActive: selectedTab == 0) { selectedTab = 0 }
                TabButton(title: "Chat", isActive: selectedTab == 1) { selectedTab = 1 }
            }
            .padding(.horizontal, 16).padding(.vertical, 10)

            if selectedTab == 0 {
                VaultContentView(tripId: currentTrip.id, isKicked: isKicked)
            } else {
                VaultChatView(tripId: currentTrip.id, isKicked: isKicked)
            }
        }
        .background(.clear)
        .ignoresSafeArea(.keyboard)
        .navigationTitle(currentTrip.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar {
            if isActiveMember {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showQRInvite = true } label: {
                        Image(systemName: "qrcode").foregroundColor(.white)
                    }
                }
            }
            if isLeader {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showEditMenu = true } label: {
                        Image(systemName: "ellipsis.circle").foregroundColor(.white)
                    }
                }
            }
        }
        .confirmationDialog("Vault Options", isPresented: $showEditMenu, titleVisibility: .visible) {
            Button("Edit Title") {
                editTitle = currentTrip.title
                showEditTitle = true
            }
            Button("Edit Description") {
                editDescription = currentTrip.description ?? ""
                showEditDescription = true
            }
            Button("Kick Member") { showKickSheet = true }
            Button("Transfer Leadership") { showTransferSheet = true }
            Button("Delete Vault", role: .destructive) { showDeleteAlert = true }
            Button("Cancel", role: .cancel) {}
        }
        .alert("Edit Title", isPresented: $showEditTitle) {
            TextField("Vault title", text: $editTitle)
            Button("Cancel", role: .cancel) {}
            Button("Save") {
                Task {
                    isSaving = true
                    _ = await tripsVM.updateTrip(currentTrip.id, title: editTitle, description: currentTrip.description)
                    isSaving = false
                }
            }
        }
        .alert("Edit Description", isPresented: $showEditDescription) {
            TextField("Description", text: $editDescription)
            Button("Cancel", role: .cancel) {}
            Button("Save") {
                Task {
                    isSaving = true
                    _ = await tripsVM.updateTrip(currentTrip.id, title: currentTrip.title, description: editDescription.isEmpty ? nil : editDescription)
                    isSaving = false
                }
            }
        }
        .alert("Delete Vault", isPresented: $showDeleteAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                Task {
                    _ = await tripsVM.deleteTrip(currentTrip.id)
                    dismiss()
                }
            }
        } message: {
            Text("Delete \"\(currentTrip.title)\"? All expenses and messages will be removed.")
        }
        .sheet(isPresented: $showKickSheet) {
            KickMemberSheet(trip: currentTrip, tripsVM: tripsVM)
        }
        .sheet(isPresented: $showTransferSheet) {
            TransferLeadershipSheet(trip: currentTrip, tripsVM: tripsVM)
        }
        .sheet(isPresented: $showQRInvite) {
            VaultQRView(trip: currentTrip)
        }
    }
}

// MARK: - Kick Member Sheet

struct KickMemberSheet: View {
    let trip: Trip
    @ObservedObject var tripsVM: TripsViewModel
    @State private var actionLoadingId: Int?
    @State private var errorMessage: String?
    @Environment(\.dismiss) private var dismiss

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
                                    color: Color.nostiaAccent, size: 38
                                )
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(participant.name ?? "Unknown").font(.system(size: 14, weight: .semibold)).foregroundColor(.white)
                                    if let uname = participant.username {
                                        Text("@\(uname)").font(.system(size: 12)).foregroundColor(Color.nostiaTextSecond)
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
                                            .font(.system(size: 13, weight: .semibold)).foregroundColor(.white)
                                            .padding(.horizontal, 14).padding(.vertical, 8)
                                            .background(Color.nostriaDanger).cornerRadius(8)
                                    }
                                }
                            }
                            .padding(14)
                            .glassEffect(in: RoundedRectangle(cornerRadius: 14))
                            .padding(.horizontal, 16).padding(.vertical, 4)
                        }
                    }
                    if let err = errorMessage {
                        Text(err).font(.footnote).foregroundColor(Color.nostriaDanger)
                            .padding(.horizontal, 20).padding(.top, 12)
                    }
                }
                .padding(.top, 8)
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
        .presentationBackground(.ultraThinMaterial)
    }
}

// MARK: - Transfer Leadership Sheet

struct TransferLeadershipSheet: View {
    let trip: Trip
    @ObservedObject var tripsVM: TripsViewModel
    @State private var actionLoadingId: Int?
    @State private var errorMessage: String?
    @Environment(\.dismiss) private var dismiss

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
                                    color: Color.nostiaAccent, size: 38
                                )
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(participant.name ?? "Unknown").font(.system(size: 14, weight: .semibold)).foregroundColor(.white)
                                    if let uname = participant.username {
                                        Text("@\(uname)").font(.system(size: 12)).foregroundColor(Color.nostiaTextSecond)
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
                                            .font(.system(size: 13, weight: .semibold)).foregroundColor(.white)
                                            .padding(.horizontal, 14).padding(.vertical, 8)
                                            .background(Color.nostiaAccent).cornerRadius(8)
                                    }
                                }
                            }
                            .padding(14)
                            .glassEffect(in: RoundedRectangle(cornerRadius: 14))
                            .padding(.horizontal, 16).padding(.vertical, 4)
                        }
                    }
                    if let err = errorMessage {
                        Text(err).font(.footnote).foregroundColor(Color.nostriaDanger)
                            .padding(.horizontal, 20).padding(.top, 12)
                    }
                }
                .padding(.top, 8)
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
        .presentationBackground(.ultraThinMaterial)
    }
}
