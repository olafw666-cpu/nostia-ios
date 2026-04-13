import SwiftUI

struct TripsView: View {
    @StateObject private var vm = TripsViewModel()
    @State private var showCreateSheet = false
    @State private var editingTrip: Trip?
    @State private var tripToVault: Trip?
    @State private var managingParticipantsTrip: Trip?

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            if vm.isLoading {
                LoadingView()
            } else {
                List {
                    ForEach(vm.trips) { trip in
                        TripCard(trip: trip,
                                 onVault: { tripToVault = trip },
                                 onEdit: { editingTrip = trip },
                                 onManagePeople: { managingParticipantsTrip = trip },
                                 onDelete: { Task { await vm.deleteTrip(trip.id) } })
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                    }
                }
                .listStyle(.plain)
                .background(.clear)
                .scrollContentBackground(.hidden)
                .refreshable { await vm.loadTrips() }
                .overlay {
                    if vm.trips.isEmpty {
                        EmptyStateView(icon: "airplane", text: "No trips yet", sub: "Create your first adventure!")
                    }
                }
            }

            // FAB
            Button { showCreateSheet = true } label: {
                LinearGradient(colors: [Color.nostiaAccent, Color.nostriaPurple],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
                    .frame(width: 60, height: 60).clipShape(Circle())
                    .overlay(Image(systemName: "plus").font(.title2.bold()).foregroundColor(.white))
                    .shadow(color: Color.nostiaAccent.opacity(0.5), radius: 12, y: 6)
            }
            .padding(20)
        }
        .background(.clear)
        .task { await vm.loadTrips() }
        .alert("Error", isPresented: Binding(get: { vm.errorMessage != nil }, set: { if !$0 { vm.errorMessage = nil } })) {
            Button("OK") { vm.errorMessage = nil }
        } message: { Text(vm.errorMessage ?? "") }
        .sheet(isPresented: $showCreateSheet) {
            CreateTripSheet { title, dest, desc, start, end in
                let ok = await vm.createTrip(title: title, destination: dest, description: desc, startDate: start, endDate: end)
                if ok { showCreateSheet = false }
            }
        }
        .sheet(item: $editingTrip) { trip in
            EditTripSheet(trip: trip) { title, dest, desc, start, end in
                let ok = await vm.updateTrip(trip.id, title: title, destination: dest, description: desc, startDate: start, endDate: end)
                if ok { editingTrip = nil }
            }
        }
        .sheet(item: $managingParticipantsTrip) { trip in
            ManageParticipantsSheet(initialTrip: trip, vm: vm)
        }
        .navigationDestination(item: $tripToVault) { trip in
            VaultView(tripId: trip.id, tripTitle: trip.title)
        }
    }
}

struct TripCard: View {
    let trip: Trip
    let onVault: () -> Void
    let onEdit: () -> Void
    let onManagePeople: () -> Void
    let onDelete: () -> Void

    @State private var showDeleteAlert = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(trip.title).font(.headline).foregroundColor(.white)
                    Text(trip.destination).font(.footnote).foregroundColor(Color.nostiaTextSecond)
                }
                Spacer()
                Text(trip.formattedDates)
                    .font(.caption.bold()).foregroundColor(Color(hex: "93C5FD"))
                    .padding(.horizontal, 12).padding(.vertical, 6)
                    .glassEffect(in: Capsule())
                    .overlay(Capsule().stroke(Color.nostiaAccent.opacity(0.5), lineWidth: 1))
            }
            if let desc = trip.description, !desc.isEmpty {
                Text(desc).font(.footnote).foregroundColor(Color(hex: "D1D5DB")).lineLimit(2)
            }
            Divider().background(Color.white.opacity(0.1))
            HStack {
                Label("\(trip.participantCount) people", systemImage: "person.2")
                    .font(.footnote).foregroundColor(Color(hex: "D1D5DB"))
                Spacer()
                HStack(spacing: 12) {
                    Button { onManagePeople() } label: {
                        Image(systemName: "person.2")
                            .padding(6)
                            .glassEffect(in: RoundedRectangle(cornerRadius: 8))
                            .foregroundColor(Color.nostiaTextSecond)
                    }
                    Button { onEdit() } label: {
                        Image(systemName: "pencil")
                            .padding(6)
                            .glassEffect(in: RoundedRectangle(cornerRadius: 8))
                            .foregroundColor(Color.nostiaTextSecond)
                    }
                    Button { onVault() } label: {
                        Label("Vault", systemImage: "creditcard")
                            .font(.footnote.bold()).foregroundColor(Color.nostiaSuccess)
                    }
                }
            }
        }
        .padding(16)
        .glassEffect(in: RoundedRectangle(cornerRadius: 18))
        .contextMenu {
            Button(role: .destructive) { showDeleteAlert = true } label: {
                Label("Delete Trip", systemImage: "trash")
            }
        }
        .alert("Delete Trip", isPresented: $showDeleteAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) { onDelete() }
        } message: {
            Text("Delete \"\(trip.title)\"? All data including expenses will be removed.")
        }
    }
}

struct EditTripSheet: View {
    let trip: Trip
    let onSave: (String, String, String?, String?, String?) async -> Void

    @State private var title: String
    @State private var destination: String
    @State private var description: String
    @State private var startDate: String
    @State private var endDate: String
    @State private var isSaving = false
    @State private var validationError: String?
    @Environment(\.dismiss) private var dismiss

    init(trip: Trip, onSave: @escaping (String, String, String?, String?, String?) async -> Void) {
        self.trip = trip
        self.onSave = onSave
        _title = State(initialValue: trip.title)
        _destination = State(initialValue: trip.destination)
        _description = State(initialValue: trip.description ?? "")
        _startDate = State(initialValue: trip.startDate.flatMap { String($0.prefix(10)) } ?? "")
        _endDate = State(initialValue: trip.endDate.flatMap { String($0.prefix(10)) } ?? "")
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    NostiaTextField(label: "Title *", placeholder: "Trip title", text: $title)
                    NostiaTextField(label: "Destination *", placeholder: "Destination", text: $destination)
                    NostiaTextField(label: "Start Date", placeholder: "YYYY-MM-DD", text: $startDate, keyboardType: .numberPad)
                        .onChange(of: startDate) { newValue in
                            let formatted = formatTripDate(newValue)
                            if formatted != newValue { startDate = formatted }
                        }
                    NostiaTextField(label: "End Date", placeholder: "YYYY-MM-DD", text: $endDate, keyboardType: .numberPad)
                        .onChange(of: endDate) { newValue in
                            let formatted = formatTripDate(newValue)
                            if formatted != newValue { endDate = formatted }
                        }
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Description")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white.opacity(0.7))
                        TextEditor(text: $description)
                            .frame(minHeight: 80).padding(12)
                            .glassEffect(in: RoundedRectangle(cornerRadius: 12))
                            .foregroundColor(.white).scrollContentBackground(.hidden)
                    }
                    if let err = validationError {
                        Text(err)
                            .font(.footnote)
                            .foregroundColor(Color.nostriaDanger)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(20)
            }
            .background(.clear)
            .navigationTitle("Edit Trip")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }.foregroundColor(Color.nostiaAccent)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        validationError = nil
                        if !startDate.isEmpty && !isValidTripDate(startDate) {
                            validationError = "Start date is not a valid date."; return
                        }
                        if !endDate.isEmpty && !isValidTripDate(endDate) {
                            validationError = "End date is not a valid date."; return
                        }
                        if !startDate.isEmpty && !endDate.isEmpty && endDate < startDate {
                            validationError = "End date must be on or after start date."; return
                        }
                        isSaving = true
                        Task {
                            await onSave(title, destination, description.isEmpty ? nil : description,
                                         startDate.isEmpty ? nil : startDate,
                                         endDate.isEmpty ? nil : endDate)
                            isSaving = false
                        }
                    } label: {
                        if isSaving { ProgressView().tint(Color.nostiaAccent) }
                        else { Text("Save").fontWeight(.semibold).foregroundColor(Color.nostiaAccent) }
                    }
                    .disabled(title.isEmpty || destination.isEmpty || isSaving)
                }
            }
        }
        .presentationBackground(.ultraThinMaterial)
    }
}

struct ManageParticipantsSheet: View {
    let initialTrip: Trip
    let vm: TripsViewModel

    @State private var currentTrip: Trip
    @State private var friends: [Friend] = []
    @State private var isLoadingFriends = false
    @State private var actionLoadingId: Int? = nil
    @State private var errorMessage: String?
    @Environment(\.dismiss) private var dismiss

    init(initialTrip: Trip, vm: TripsViewModel) {
        self.initialTrip = initialTrip
        self.vm = vm
        _currentTrip = State(initialValue: initialTrip)
    }

    var participants: [TripParticipant] { currentTrip.participants ?? [] }
    var participantUserIds: Set<Int> { Set(participants.map { $0.userId }) }
    var friendsToAdd: [Friend] { friends.filter { !participantUserIds.contains($0.id) } }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Text("CURRENT PARTICIPANTS")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(Color.nostiaTextSecond)
                        .padding(.horizontal, 20).padding(.top, 20).padding(.bottom, 10)

                    if participants.isEmpty {
                        Text("No participants yet")
                            .font(.footnote).foregroundColor(Color.nostiaTextSecond)
                            .padding(.horizontal, 20).padding(.bottom, 16)
                    } else {
                        ForEach(participants) { participant in
                            HStack(spacing: 12) {
                                AvatarView(
                                    initial: String((participant.name ?? "U").prefix(1)).uppercased(),
                                    color: Color.nostiaAccent, size: 36
                                )
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(participant.name ?? "Unknown")
                                        .font(.system(size: 14, weight: .semibold)).foregroundColor(.white)
                                    if let uname = participant.username {
                                        Text("@\(uname)").font(.system(size: 12)).foregroundColor(Color.nostiaTextSecond)
                                    }
                                }
                                Spacer()
                                if actionLoadingId == participant.userId {
                                    ProgressView().tint(Color.nostriaDanger)
                                } else {
                                    Button {
                                        Task { await handleRemove(userId: participant.userId) }
                                    } label: {
                                        Image(systemName: "minus.circle").font(.title3).foregroundColor(Color.nostriaDanger)
                                    }
                                }
                            }
                            .padding(14)
                            .glassEffect(in: RoundedRectangle(cornerRadius: 14))
                            .padding(.horizontal, 16).padding(.vertical, 4)
                        }
                    }

                    Text("ADD FRIENDS")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(Color.nostiaTextSecond)
                        .padding(.horizontal, 20).padding(.top, 24).padding(.bottom, 10)

                    if isLoadingFriends {
                        ProgressView().tint(Color.nostiaAccent).frame(maxWidth: .infinity).padding(.vertical, 16)
                    } else if friendsToAdd.isEmpty {
                        Text("All friends are already on this trip")
                            .font(.footnote).foregroundColor(Color.nostiaTextSecond)
                            .padding(.horizontal, 20).padding(.bottom, 16)
                    } else {
                        ForEach(friendsToAdd) { friend in
                            HStack(spacing: 12) {
                                AvatarView(initial: friend.initial, color: Color.nostiaSuccess, size: 36)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(friend.name).font(.system(size: 14, weight: .semibold)).foregroundColor(.white)
                                    Text("@\(friend.username)").font(.system(size: 12)).foregroundColor(Color.nostiaTextSecond)
                                }
                                Spacer()
                                if actionLoadingId == friend.id {
                                    ProgressView().tint(.white)
                                        .padding(.horizontal, 14).padding(.vertical, 8)
                                        .glassEffect(in: RoundedRectangle(cornerRadius: 8))
                                } else {
                                    Button {
                                        Task { await handleAdd(friendId: friend.id) }
                                    } label: {
                                        Text("Add")
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

                    Spacer(minLength: 32)
                }
            }
            .background(.clear)
            .navigationTitle("Manage People")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }.foregroundColor(Color.nostiaAccent)
                }
            }
        }
        .presentationBackground(.ultraThinMaterial)
        .task { await loadFriends() }
    }

    private func loadFriends() async {
        isLoadingFriends = true
        do { friends = try await FriendsAPI.shared.getAll() } catch {}
        isLoadingFriends = false
    }

    private func handleAdd(friendId: Int) async {
        actionLoadingId = friendId; errorMessage = nil
        let ok = await vm.addParticipant(tripId: currentTrip.id, userId: friendId)
        if ok, let updated = vm.trips.first(where: { $0.id == currentTrip.id }) { currentTrip = updated }
        else { errorMessage = vm.errorMessage }
        actionLoadingId = nil
    }

    private func handleRemove(userId: Int) async {
        actionLoadingId = userId; errorMessage = nil
        let ok = await vm.removeParticipant(tripId: currentTrip.id, userId: userId)
        if ok, let updated = vm.trips.first(where: { $0.id == currentTrip.id }) { currentTrip = updated }
        else { errorMessage = vm.errorMessage }
        actionLoadingId = nil
    }
}
