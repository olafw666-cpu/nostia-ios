import SwiftUI

/// Crash pads — "find a place to crash". Mutual followers offer a couch/room;
/// friends request to stay; hosts accept or decline. Pads carry an approximate
/// area only — exact addresses are exchanged over DM after a host accepts.
struct CrashPadsView: View {
    @State private var segment = 0                 // 0 = Stay, 1 = Host
    @State private var friendPads: [FriendCrashPad] = []
    @State private var myPad: MyCrashPad?
    @State private var incoming: [CrashPadRequest] = []
    @State private var outgoing: [CrashPadRequest] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var requestTarget: FriendCrashPad?

    // Host editor fields
    @State private var editTitle = ""
    @State private var editArea = ""
    @State private var editDescription = ""
    @State private var editCapacity = 1
    @State private var editActive = true
    @State private var isSaving = false
    @State private var showRemoveConfirm = false

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var responsive: ResponsiveLayoutManager

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: responsive.spacing(16)) {
                    AtlasSegmented(segments: ["Stay", "Host"], selection: $segment)

                    if isLoading && friendPads.isEmpty && myPad == nil {
                        ProgressView().tint(Color.nostiaAccent)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 40)
                    } else if segment == 0 {
                        staySection
                    } else {
                        hostSection
                    }

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.nostiaBody(13))
                            .foregroundColor(Color.nostriaDanger)
                    }
                }
                .padding(.horizontal, responsive.spacing(16))
                .padding(.top, 8)
                .padding(.bottom, 40)
                .frame(maxWidth: responsive.contentMaxWidth)
                .frame(maxWidth: .infinity)
            }
            .background(Color.nostiaBackground.ignoresSafeArea())
            .scrollDismissesKeyboard(.interactively)
            .refreshable { await load() }
            .navigationTitle("Crash Pads")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }.foregroundColor(Color.nostiaAccent)
                }
            }
        }
        .presentationBackground(Color.nostiaBackground)
        .task { await load() }
        .sheet(item: $requestTarget) { pad in
            CrashRequestSheet(pad: pad) {
                Task { await load() }
            }
        }
        .confirmationDialog("Remove your listing?", isPresented: $showRemoveConfirm, titleVisibility: .visible) {
            Button("Remove Listing", role: .destructive) { Task { await removePad() } }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Friends will no longer see your pad. Pending requests are kept until you respond.")
        }
    }

    // MARK: - Stay (friends' pads + my requests)

    @ViewBuilder
    private var staySection: some View {
        Text("Places offered by people who follow you back. Ask to stay — details get sorted over DM once they say yes.")
            .font(.nostiaBody(13)).foregroundColor(Color.nostiaTextSecond)

        if friendPads.isEmpty {
            EmptyStateView(icon: "sofa", text: "No pads from friends yet",
                           sub: "When mutual followers offer a place, it shows up here")
        } else {
            ForEach(friendPads) { pad in
                friendPadCard(pad)
            }
        }

        if !outgoing.isEmpty {
            NostiaRowHeader(title: "My requests", actionTitle: nil)
            VStack(spacing: 0) {
                ForEach(outgoing) { request in
                    outgoingRow(request)
                    if request.id != outgoing.last?.id {
                        Rectangle().fill(Color.nostiaDivider).frame(height: 1).padding(.leading, 14)
                    }
                }
            }
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.nostiaCard))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.nostiaCardStroke, lineWidth: 0.75))
        }
    }

    private func friendPadCard(_ pad: FriendCrashPad) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                UserAvatarView(
                    imageData: pad.hostProfilePictureUrl,
                    initial: String((pad.hostName ?? pad.hostUsername ?? "?").prefix(1)).uppercased(),
                    color: Color.nostiaAccent,
                    size: 40
                )
                VStack(alignment: .leading, spacing: 2) {
                    Text(pad.title)
                        .font(.nostiaBody(16, weight: .bold))
                        .foregroundColor(Color.nostiaTextPrimary)
                    Text(pad.hostName ?? pad.hostUsername ?? "")
                        .font(.nostiaBody(12))
                        .foregroundColor(Color.nostiaTextSecond)
                }
                Spacer()
            }

            HStack(spacing: 8) {
                if let area = pad.area, !area.isEmpty {
                    Label(area, systemImage: "mappin.and.ellipse")
                }
                Label("sleeps \(pad.capacity)", systemImage: "bed.double")
            }
            .font(.nostiaBody(12, weight: .semibold))
            .foregroundColor(Color.nostiaTextSecond)
            .labelStyle(AtlasLeadingIconLabel(tint: Color.nostiaAccent, spacing: 4))

            if let desc = pad.description, !desc.isEmpty {
                Text(desc)
                    .font(.nostiaBody(13))
                    .foregroundColor(Color.nostiaTextSecond)
                    .lineLimit(3)
            }

            switch pad.myRequestStatus {
            case "pending":
                Text("Request sent — waiting on \(pad.hostName ?? "your host")")
                    .font(.nostiaBody(13, weight: .semibold))
                    .foregroundColor(Color.nostiaTextMuted)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.nostiaButton))
            case "accepted":
                Label("Confirmed — message them to sort out details", systemImage: "checkmark.circle.fill")
                    .font(.nostiaBody(13, weight: .semibold))
                    .foregroundColor(Color.nostiaSuccess)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.nostiaCard))
            default:
                Button {
                    Haptics.tap()
                    requestTarget = pad
                } label: {
                    Text("Ask to Stay")
                        .font(.nostiaBody(14, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.nostiaAccent))
                }
                .buttonStyle(.nostiaTap)
            }
        }
        .padding(16)
        .nostiaWarmCard(cornerRadius: 20)
    }

    private func outgoingRow(_ request: CrashPadRequest) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(request.padTitle ?? "Crash pad")
                    .font(.nostiaBody(14, weight: .semibold))
                    .foregroundColor(Color.nostiaTextPrimary)
                Text([request.hostName, request.dateRangeText].compactMap { $0 }.joined(separator: " · "))
                    .font(.nostiaBody(12))
                    .foregroundColor(Color.nostiaTextSecond)
            }
            Spacer()
            switch request.status {
            case "pending":
                Button {
                    Haptics.tap()
                    Task { await cancelRequest(request) }
                } label: {
                    Text("Cancel")
                        .font(.nostiaBody(12, weight: .bold))
                        .foregroundColor(Color.nostriaDanger)
                }
                .buttonStyle(.nostiaTap)
            case "accepted":
                Text("Accepted").font(.nostiaBody(12, weight: .bold)).foregroundColor(Color.nostiaSuccess)
            default:
                Text("Declined").font(.nostiaBody(12, weight: .bold)).foregroundColor(Color.nostiaTextMuted)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    // MARK: - Host (my pad + incoming requests)

    @ViewBuilder
    private var hostSection: some View {
        Text("Offer your place to mutual followers. Only a rough area is shown — share the address privately once you accept someone.")
            .font(.nostiaBody(13)).foregroundColor(Color.nostiaTextSecond)

        VStack(alignment: .leading, spacing: 12) {
            NostiaRowHeader(title: myPad == nil ? "Offer your place" : "Your listing", actionTitle: nil)

            VStack(alignment: .leading, spacing: 6) {
                Text("Title").font(.nostiaBody(13, weight: .semibold)).foregroundColor(Color.nostiaTextSecond)
                TextField("e.g. Couch in my living room", text: $editTitle)
                    .font(.nostiaBody(15)).foregroundColor(Color.nostiaTextPrimary)
                    .padding(.horizontal, 14).frame(height: 46)
                    .nostiaCard(cornerRadius: 14, elevation: .flat)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Area (city / neighborhood — never your address)")
                    .font(.nostiaBody(13, weight: .semibold)).foregroundColor(Color.nostiaTextSecond)
                TextField("e.g. Williamsburg, Brooklyn", text: $editArea)
                    .font(.nostiaBody(15)).foregroundColor(Color.nostiaTextPrimary)
                    .padding(.horizontal, 14).frame(height: 46)
                    .nostiaCard(cornerRadius: 14, elevation: .flat)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Details").font(.nostiaBody(13, weight: .semibold)).foregroundColor(Color.nostiaTextSecond)
                TextEditor(text: $editDescription)
                    .font(.nostiaBody(15)).foregroundColor(Color.nostiaTextPrimary)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 80)
                    .padding(8)
                    .nostiaCard(cornerRadius: 14, elevation: .flat)
                    .toolbar {
                        ToolbarItemGroup(placement: .keyboard) {
                            Spacer()
                            Button("Done") { hideKeyboard() }
                        }
                    }
            }

            Stepper(value: $editCapacity, in: 1...20) {
                Label("Sleeps \(editCapacity)", systemImage: "bed.double")
                    .font(.nostiaBody(14, weight: .semibold))
                    .foregroundColor(Color.nostiaTextPrimary)
                    .labelStyle(AtlasLeadingIconLabel(tint: Color.nostiaAccent))
            }

            if myPad != nil {
                Toggle(isOn: $editActive) {
                    Text("Visible to friends")
                        .font(.nostiaBody(14, weight: .semibold))
                        .foregroundColor(Color.nostiaTextPrimary)
                }
                .tint(Color.nostiaAccent)
            }

            NostiaPrimaryButton(title: isSaving ? "Saving…" : (myPad == nil ? "Offer My Place" : "Save Changes"),
                                systemImage: "sofa") {
                Haptics.tap()
                hideKeyboard()
                Task { await savePad() }
            }
            .disabled(isSaving || editTitle.trimmingCharacters(in: .whitespaces).isEmpty)
            .opacity(editTitle.trimmingCharacters(in: .whitespaces).isEmpty ? 0.5 : 1)

            if myPad != nil {
                Button {
                    showRemoveConfirm = true
                } label: {
                    Text("Remove listing")
                        .font(.nostiaBody(13, weight: .semibold))
                        .foregroundColor(Color.nostriaDanger)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.nostiaTap)
            }
        }
        .padding(16)
        .nostiaWarmCard(cornerRadius: 20)

        if !incoming.isEmpty {
            NostiaRowHeader(title: "Requests to stay", actionTitle: nil)
            ForEach(incoming) { request in
                incomingCard(request)
            }
        }
    }

    private func incomingCard(_ request: CrashPadRequest) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                UserAvatarView(
                    imageData: request.requesterProfilePictureUrl,
                    initial: String((request.requesterName ?? "?").prefix(1)).uppercased(),
                    color: Color.nostiaAccent,
                    size: 38
                )
                VStack(alignment: .leading, spacing: 2) {
                    Text(request.requesterName ?? request.requesterUsername ?? "Someone")
                        .font(.nostiaBody(15, weight: .bold))
                        .foregroundColor(Color.nostiaTextPrimary)
                    if let range = request.dateRangeText {
                        Text(range).font(.nostiaBody(12)).foregroundColor(Color.nostiaTextSecond)
                    }
                }
                Spacer()
            }
            if let message = request.message, !message.isEmpty {
                Text("“\(message)”")
                    .font(.nostiaBody(13))
                    .foregroundColor(Color.nostiaTextSecond)
            }
            HStack(spacing: 10) {
                Button {
                    Haptics.tap()
                    Task { await respond(request, accept: true) }
                } label: {
                    Text("Accept")
                        .font(.nostiaBody(14, weight: .bold)).foregroundColor(.white)
                        .frame(maxWidth: .infinity).padding(.vertical, 11)
                        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.nostiaAccent))
                }
                .buttonStyle(.nostiaTap)
                Button {
                    Haptics.tap()
                    Task { await respond(request, accept: false) }
                } label: {
                    Text("Decline")
                        .font(.nostiaBody(14, weight: .bold)).foregroundColor(Color.nostiaTextSecond)
                        .frame(maxWidth: .infinity).padding(.vertical, 11)
                        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.nostiaButton))
                        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Color.nostiaCardStroke, lineWidth: 0.75))
                }
                .buttonStyle(.nostiaTap)
            }
        }
        .padding(16)
        .nostiaCard(cornerRadius: 18)
    }

    // MARK: - Actions

    private func load() async {
        do {
            async let padsTask = CrashPadsAPI.shared.getFriendPads()
            async let mineTask = CrashPadsAPI.shared.getMine()
            friendPads = try await padsTask
            let mine = try await mineTask
            myPad = mine.pad
            incoming = mine.incoming
            outgoing = mine.outgoing
            if let pad = mine.pad {
                editTitle = pad.title
                editArea = pad.area ?? ""
                editDescription = pad.description ?? ""
                editCapacity = pad.capacity
                editActive = pad.isActive
            }
            errorMessage = nil
        } catch {
            errorMessage = "Couldn't load crash pads — pull to retry."
        }
        isLoading = false
    }

    private func savePad() async {
        isSaving = true
        defer { isSaving = false }
        do {
            myPad = try await CrashPadsAPI.shared.upsertMine(
                title: editTitle.trimmingCharacters(in: .whitespaces),
                description: editDescription.trimmingCharacters(in: .whitespacesAndNewlines),
                area: editArea.trimmingCharacters(in: .whitespaces),
                capacity: editCapacity,
                isActive: editActive
            )
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func removePad() async {
        do {
            try await CrashPadsAPI.shared.deleteMine()
            myPad = nil
            editTitle = ""; editArea = ""; editDescription = ""; editCapacity = 1; editActive = true
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func respond(_ request: CrashPadRequest, accept: Bool) async {
        do {
            _ = try await CrashPadsAPI.shared.respond(requestId: request.id, accept: accept)
            incoming.removeAll { $0.id == request.id }
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func cancelRequest(_ request: CrashPadRequest) async {
        do {
            try await CrashPadsAPI.shared.cancel(requestId: request.id)
            outgoing.removeAll { $0.id == request.id }
            await load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - Ask-to-stay sheet

private struct CrashRequestSheet: View {
    let pad: FriendCrashPad
    var onSent: () -> Void

    @State private var includeDates = false
    @State private var startDate = Date().addingTimeInterval(86_400)
    @State private var endDate = Date().addingTimeInterval(3 * 86_400)
    @State private var message = ""
    @State private var isSending = false
    @State private var errorMessage: String?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Ask \(pad.hostName ?? "your friend") to crash at “\(pad.title)”. They'll get a notification and can accept or decline.")
                        .font(.nostiaBody(13))
                        .foregroundColor(Color.nostiaTextSecond)

                    Toggle(isOn: $includeDates.animation()) {
                        Text("Add dates")
                            .font(.nostiaBody(14, weight: .semibold))
                            .foregroundColor(Color.nostiaTextPrimary)
                    }
                    .tint(Color.nostiaAccent)

                    if includeDates {
                        DatePicker("Arrive", selection: $startDate, in: Date()..., displayedComponents: .date)
                            .font(.nostiaBody(14, weight: .semibold))
                            .tint(Color.nostiaAccent)
                        DatePicker("Leave", selection: $endDate, in: startDate..., displayedComponents: .date)
                            .font(.nostiaBody(14, weight: .semibold))
                            .tint(Color.nostiaAccent)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Message (optional)")
                            .font(.nostiaBody(13, weight: .semibold)).foregroundColor(Color.nostiaTextSecond)
                        TextField("e.g. In town for the weekend!", text: $message, axis: .vertical)
                            .font(.nostiaBody(15)).foregroundColor(Color.nostiaTextPrimary)
                            .lineLimit(2...4)
                            .padding(12)
                            .nostiaCard(cornerRadius: 14, elevation: .flat)
                            .toolbar {
                                ToolbarItemGroup(placement: .keyboard) {
                                    Spacer()
                                    Button("Done") { hideKeyboard() }
                                }
                            }
                    }

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.nostiaBody(13))
                            .foregroundColor(Color.nostriaDanger)
                    }

                    NostiaPrimaryButton(title: isSending ? "Sending…" : "Send Request", systemImage: "paperplane.fill") {
                        Haptics.tap()
                        hideKeyboard()
                        Task { await send() }
                    }
                    .disabled(isSending)
                }
                .padding(18)
            }
            .background(Color.nostiaBackground.ignoresSafeArea())
            .navigationTitle("Ask to Stay")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }.foregroundColor(Color.nostiaTextSecond)
                }
            }
        }
        .presentationBackground(Color.nostiaBackground)
        .presentationDetents([.medium, .large])
    }

    private func send() async {
        isSending = true
        defer { isSending = false }
        let wire = DateFormatter()
        wire.dateFormat = "yyyy-MM-dd"
        wire.locale = Locale(identifier: "en_US_POSIX")
        do {
            _ = try await CrashPadsAPI.shared.request(
                padId: pad.id,
                startDate: includeDates ? wire.string(from: startDate) : nil,
                endDate: includeDates ? wire.string(from: endDate) : nil,
                message: message.trimmingCharacters(in: .whitespacesAndNewlines)
            )
            onSent()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
