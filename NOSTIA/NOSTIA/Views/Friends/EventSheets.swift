import SwiftUI
import MapKit
import PhotosUI

// Minimal view model — only the RSVP/delete/flyer actions needed by the map's EventDetailSheet.
// Full AdventuresViewModel (search, list) lives in _disabled_features/adventures-ios.
@MainActor
final class EventActionsViewModel {
    func rsvpEvent(eventId: Int, status: String) async throws -> Event {
        try await AdventuresAPI.shared.rsvp(eventId: eventId, status: status)
    }

    func deleteEvent(_ eventId: Int) async throws {
        try await AdventuresAPI.shared.deleteEvent(eventId)
    }

    func updateEventFlyer(id: Int, flyerImage: String) async throws -> Event {
        try await AdventuresAPI.shared.updateEvent(id: id, flyerImage: flyerImage)
    }
}

// MARK: - EventDetailSheet

struct EventDetailSheet: View {
    let event: Event
    let vm: EventActionsViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var currentEvent: Event
    @State private var isRsvping = false
    @State private var showDeleteConfirm = false
    @State private var showCreatorProfile = false
    @State private var showFlyer = false
    @State private var selectedFlyerItem: PhotosPickerItem?
    @State private var isFlyerUploading = false

    private var currentUserId: Int? { AuthManager.shared.currentUserId }
    private var isCreator: Bool { currentEvent.createdBy != nil && currentEvent.createdBy == currentUserId }

    init(event: Event, vm: EventActionsViewModel) {
        self.event = event
        self.vm = vm
        self._currentEvent = State(initialValue: event)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if let imgData = currentEvent.flyerImage,
                       let data = Data(base64Encoded: imgData),
                       let uiImage = UIImage(data: data) {
                        Image(uiImage: uiImage)
                            .resizable().scaledToFill()
                            .frame(maxWidth: .infinity).frame(height: 200)
                            .clipped().cornerRadius(14)
                            .padding(.horizontal, 20).padding(.top, 16)
                    }

                    VStack(alignment: .leading, spacing: 16) {
                        Label(currentEvent.formattedDate, systemImage: "calendar")
                            .font(.subheadline.bold()).foregroundColor(Color.nostiaWarning)

                        if let loc = currentEvent.location {
                            Label(loc, systemImage: "location")
                                .font(.subheadline).foregroundColor(Color.nostiaTextSecond)
                        }

                        if let name = currentEvent.creatorName {
                            Button { showCreatorProfile = true } label: {
                                Label("by \(name)", systemImage: "person")
                                    .font(.subheadline).foregroundColor(Color.nostiaAccent.opacity(0.85))
                            }
                            .buttonStyle(.plain)
                        }

                        if let desc = currentEvent.description, !desc.isEmpty {
                            if let attributed = try? AttributedString(
                                markdown: desc,
                                options: AttributedString.MarkdownParsingOptions(
                                    interpretedSyntax: .inlineOnlyPreservingWhitespace
                                )
                            ) {
                                Text(attributed).font(.body).foregroundColor(.white).tint(Color.nostiaAccent)
                            } else {
                                Text(desc).font(.body).foregroundColor(.white)
                            }
                        }

                        Label("\(currentEvent.goingCount ?? 0) going", systemImage: "checkmark.circle")
                            .font(.subheadline).foregroundColor(Color.nostiaSuccess)

                        Button { showFlyer = true } label: {
                            Label("View Event Page", systemImage: "doc.richtext")
                                .font(.footnote.bold()).foregroundColor(Color.nostiaAccent)
                                .frame(maxWidth: .infinity).padding(.vertical, 11)
                                .background(Color.nostiaAccent.opacity(0.12)).cornerRadius(12)
                        }

                        Divider().background(Color.white.opacity(0.2))

                        HStack(spacing: 12) {
                            Button { Task { await rsvp("going") } } label: {
                                HStack {
                                    if isRsvping { ProgressView().tint(.white).scaleEffect(0.8) }
                                    else { Image(systemName: "checkmark.circle.fill") }
                                    Text("Going")
                                }
                                .frame(maxWidth: .infinity).padding(.vertical, 12)
                                .background(currentEvent.myRsvp == "going" ? Color.nostiaSuccess : Color.nostiaInput)
                                .foregroundColor(.white).cornerRadius(12)
                            }
                            .disabled(isRsvping)

                            Button { Task { await rsvp("not_going") } } label: {
                                HStack {
                                    if isRsvping { ProgressView().tint(.white).scaleEffect(0.8) }
                                    else { Image(systemName: "xmark.circle.fill") }
                                    Text("Not Going")
                                }
                                .frame(maxWidth: .infinity).padding(.vertical, 12)
                                .background(currentEvent.myRsvp == "not_going" ? Color.nostriaDanger : Color.nostiaInput)
                                .foregroundColor(.white).cornerRadius(12)
                            }
                            .disabled(isRsvping)
                        }

                        if isCreator {
                            PhotosPicker(selection: $selectedFlyerItem, matching: .images) {
                                HStack {
                                    if isFlyerUploading {
                                        ProgressView().tint(Color.nostiaAccent).scaleEffect(0.8)
                                    } else {
                                        Image(systemName: "photo.badge.plus")
                                    }
                                    Text(currentEvent.flyerImage != nil ? "Change Flyer" : "Add Event Flyer")
                                }
                                .frame(maxWidth: .infinity).padding(.vertical, 12)
                                .background(Color.nostiaInput)
                                .foregroundColor(Color.nostiaAccent).cornerRadius(12)
                            }
                            .disabled(isFlyerUploading)

                            Button(role: .destructive) { showDeleteConfirm = true } label: {
                                Label("Delete Event", systemImage: "trash")
                                    .frame(maxWidth: .infinity).padding(.vertical, 12)
                                    .background(Color.nostriaDanger.opacity(0.2))
                                    .foregroundColor(Color.nostriaDanger).cornerRadius(12)
                            }
                        }
                    }
                    .padding(20)
                }
            }
            .background(.clear)
            .navigationTitle(currentEvent.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }.foregroundColor(Color.nostiaAccent)
                }
            }
            .confirmationDialog("Delete this event?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
                Button("Delete", role: .destructive) {
                    Task { try? await vm.deleteEvent(currentEvent.id); dismiss() }
                }
                Button("Cancel", role: .cancel) {}
            }
            .sheet(isPresented: $showFlyer) {
                EventFlyerView(event: currentEvent, vm: vm)
            }
            .sheet(isPresented: $showCreatorProfile) {
                if let creatorId = currentEvent.createdBy {
                    NavigationStack { PublicProfileView(userId: creatorId) }
                        .presentationBackground(.ultraThinMaterial)
                }
            }
            .onChange(of: selectedFlyerItem) { _, item in
                guard let item else { return }
                Task { await uploadFlyer(item) }
            }
        }
        .presentationBackground(.ultraThinMaterial)
    }

    private func rsvp(_ status: String) async {
        isRsvping = true
        if let updated = try? await vm.rsvpEvent(eventId: currentEvent.id, status: status) {
            currentEvent = updated
        }
        isRsvping = false
    }

    private func uploadFlyer(_ item: PhotosPickerItem) async {
        isFlyerUploading = true
        guard let data = try? await item.loadTransferable(type: Data.self),
              let uiImage = UIImage(data: data),
              let compressed = uiImage.resizedForUpload().jpegData(compressionQuality: 0.6) else {
            isFlyerUploading = false
            return
        }
        if let updated = try? await vm.updateEventFlyer(id: currentEvent.id, flyerImage: compressed.base64EncodedString()) {
            currentEvent = updated
        }
        isFlyerUploading = false
    }
}

// MARK: - EventFlyerView

struct EventFlyerView: View {
    let event: Event
    let vm: EventActionsViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var currentEvent: Event
    @State private var isRsvping = false

    init(event: Event, vm: EventActionsViewModel) {
        self.event = event
        self.vm = vm
        self._currentEvent = State(initialValue: event)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    if let imgData = currentEvent.flyerImage,
                       let data = Data(base64Encoded: imgData),
                       let uiImage = UIImage(data: data) {
                        Image(uiImage: uiImage)
                            .resizable().scaledToFill()
                            .frame(maxWidth: .infinity).frame(height: 340).clipped()
                    } else {
                        LinearGradient(
                            colors: [Color.nostiaAccent.opacity(0.7), Color.nostriaPurple.opacity(0.7)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                        .frame(maxWidth: .infinity).frame(height: 220)
                        .overlay {
                            VStack(spacing: 12) {
                                Image(systemName: "calendar.badge.clock")
                                    .font(.system(size: 52)).foregroundColor(.white.opacity(0.5))
                                Text("No flyer yet").font(.caption).foregroundColor(.white.opacity(0.4))
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 16) {
                        Text(currentEvent.title).font(.title.bold()).foregroundColor(.white)
                        Label(currentEvent.formattedDate, systemImage: "calendar")
                            .font(.subheadline.bold()).foregroundColor(Color.nostiaWarning)
                        if let loc = currentEvent.location {
                            Label(loc, systemImage: "location")
                                .font(.subheadline).foregroundColor(Color.nostiaTextSecond)
                        }
                        if let name = currentEvent.creatorName {
                            Label("Hosted by \(name)", systemImage: "person")
                                .font(.subheadline).foregroundColor(Color.nostiaTextSecond)
                        }
                        Label("\(currentEvent.goingCount ?? 0) going", systemImage: "checkmark.circle")
                            .font(.subheadline).foregroundColor(Color.nostiaSuccess)
                        if let desc = currentEvent.description, !desc.isEmpty {
                            Divider().background(Color.white.opacity(0.2))
                            if let attributed = try? AttributedString(
                                markdown: desc,
                                options: AttributedString.MarkdownParsingOptions(
                                    interpretedSyntax: .inlineOnlyPreservingWhitespace
                                )
                            ) {
                                Text(attributed).font(.body).foregroundColor(.white).tint(Color.nostiaAccent)
                            } else {
                                Text(desc).font(.body).foregroundColor(.white)
                            }
                        }
                        Divider().background(Color.white.opacity(0.2))
                        HStack(spacing: 12) {
                            Button { Task { await rsvp("going") } } label: {
                                HStack {
                                    if isRsvping { ProgressView().tint(.white).scaleEffect(0.8) }
                                    else { Image(systemName: "checkmark.circle.fill") }
                                    Text("Going")
                                }
                                .frame(maxWidth: .infinity).padding(.vertical, 12)
                                .background(currentEvent.myRsvp == "going" ? Color.nostiaSuccess : Color.nostiaInput)
                                .foregroundColor(.white).cornerRadius(12)
                            }
                            .disabled(isRsvping)
                            Button { Task { await rsvp("not_going") } } label: {
                                HStack {
                                    if isRsvping { ProgressView().tint(.white).scaleEffect(0.8) }
                                    else { Image(systemName: "xmark.circle.fill") }
                                    Text("Not Going")
                                }
                                .frame(maxWidth: .infinity).padding(.vertical, 12)
                                .background(currentEvent.myRsvp == "not_going" ? Color.nostriaDanger : Color.nostiaInput)
                                .foregroundColor(.white).cornerRadius(12)
                            }
                            .disabled(isRsvping)
                        }
                    }
                    .padding(20)
                }
            }
            .ignoresSafeArea(edges: .top)
            .background(.clear)
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(Color.nostiaAccent)
                        .padding(.horizontal, 12).padding(.vertical, 6)
                        .background(.ultraThinMaterial, in: Capsule())
                }
            }
        }
        .presentationBackground(.ultraThinMaterial)
    }

    private func rsvp(_ status: String) async {
        isRsvping = true
        if let updated = try? await vm.rsvpEvent(eventId: currentEvent.id, status: status) {
            currentEvent = updated
        }
        isRsvping = false
    }
}

// MARK: - LinkInsertBar / LinkInsertSheet

struct LinkInsertBar: View {
    @Binding var text: String
    @State private var showSheet = false

    var body: some View {
        HStack {
            Button { showSheet = true } label: {
                Label("Add Link", systemImage: "link")
                    .font(.caption.bold()).foregroundColor(Color.nostiaAccent)
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .glassEffect(in: Capsule())
            }
            Spacer()
        }
        .sheet(isPresented: $showSheet) {
            LinkInsertSheet { markdown in text += (text.isEmpty ? "" : " ") + markdown }
                .presentationDetents([.height(260)])
                .presentationBackground(.ultraThinMaterial)
        }
    }
}

// MARK: - EventCard

struct EventCard: View {
    let event: Event
    var onCreatorTap: ((Int) -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(event.title).font(.headline).foregroundColor(.white)
                Spacer()
                if let vis = event.visibility, vis != "public" {
                    Label(vis == "friends" ? "Friends" : "Private",
                          systemImage: vis == "friends" ? "person.2" : "lock")
                        .font(.caption.bold()).foregroundColor(.white)
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(vis == "friends" ? Color.blue.opacity(0.7) : Color.nostriaDanger)
                        .cornerRadius(12)
                }
                if let dist = event.formattedDistance {
                    Text(dist).font(.caption.bold()).foregroundColor(.white)
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(Color.nostiaAccent).cornerRadius(12)
                }
            }
            if let desc = event.description, !desc.isEmpty {
                Text(desc).font(.footnote).foregroundColor(Color.nostiaTextSecond).lineLimit(2)
            }
            if let loc = event.location {
                Label(loc, systemImage: "location").font(.footnote).foregroundColor(Color.nostiaTextSecond)
            }
            HStack {
                Label(event.formattedDate, systemImage: "calendar")
                    .font(.footnote.bold()).foregroundColor(Color.nostiaWarning)
                if let going = event.goingCount, going > 0 {
                    Label("\(going) going", systemImage: "checkmark.circle")
                        .font(.caption).foregroundColor(Color.nostiaSuccess)
                }
                Spacer()
                if let name = event.creatorName {
                    if let userId = event.createdBy, let onCreatorTap {
                        Button { onCreatorTap(userId) } label: {
                            Text("by \(name)").font(.caption).foregroundColor(Color.nostiaAccent.opacity(0.8))
                        }
                        .buttonStyle(.plain)
                    } else {
                        Text("by \(name)").font(.caption).foregroundColor(Color.nostiaTextMuted)
                    }
                }
            }
        }
        .padding(16)
        .glassEffect(in: RoundedRectangle(cornerRadius: 16))
    }
}

struct LinkInsertSheet: View {
    let onInsert: (String) -> Void
    @State private var displayText = ""
    @State private var url = ""
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                NostiaTextField(label: "Display Text", placeholder: "e.g. Click here", text: $displayText)
                VStack(alignment: .leading, spacing: 6) {
                    Text("URL *")
                        .font(.system(size: 14, weight: .semibold)).foregroundColor(.white.opacity(0.7))
                    TextField("https://...", text: $url)
                        .foregroundColor(.white).autocorrectionDisabled()
                        .textInputAutocapitalization(.never).keyboardType(.URL)
                        .padding(12).glassEffect(in: RoundedRectangle(cornerRadius: 12))
                }
            }
            .padding(20)
            .navigationTitle("Add Link")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }.foregroundColor(Color.nostiaTextSecond)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Insert") {
                        onInsert(displayText.isEmpty ? url : "[\(displayText)](\(url))")
                        dismiss()
                    }
                    .foregroundColor(url.isEmpty ? Color.nostiaTextMuted : Color.nostiaAccent)
                    .fontWeight(.semibold).disabled(url.isEmpty)
                }
            }
        }
    }
}
