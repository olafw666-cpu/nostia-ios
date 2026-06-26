import SwiftUI
import MapKit
import PhotosUI

// Minimal view model — only the RSVP/delete/flyer actions needed by the map's ExperienceDetailSheet.
@MainActor
final class ExperienceActionsViewModel {
    func rsvpExperience(experienceId: Int, status: String) async throws -> Experience {
        try await ExperiencesAPI.shared.rsvp(experienceId: experienceId, status: status)
    }

    func deleteExperience(_ experienceId: Int) async throws {
        try await ExperiencesAPI.shared.deleteExperience(experienceId)
    }

    func updateExperienceFlyer(id: Int, flyerImage: String) async throws -> Experience {
        try await ExperiencesAPI.shared.updateExperience(id: id, flyerImage: flyerImage)
    }
}

// MARK: - Tag chips (D5)

/// Wrapping row of small capsule tag chips, muted accent tint. Shown on the card bubble
/// and the detail sheet only — never on the map pin.
struct ExperienceTagChips: View {
    let tags: [String]
    var body: some View {
        FlowLayout(spacing: 6) {
            ForEach(tags, id: \.self) { tag in
                Text(tag)
                    .font(.caption2.weight(.semibold))
                    .foregroundColor(Color.nostiaAccent)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(Color.nostiaAccent.opacity(0.15), in: Capsule())
            }
        }
    }
}

// MARK: - ExperienceDetailSheet

struct ExperienceDetailSheet: View {
    let event: Experience
    let vm: ExperienceActionsViewModel
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var responsive: ResponsiveLayoutManager
    @State private var currentEvent: Experience
    @State private var isRsvping = false
    @State private var showDeleteConfirm = false
    @State private var showCreatorProfile = false
    @State private var showFlyer = false
    @State private var showChat = false
    @State private var selectedFlyerItem: PhotosPickerItem?
    @State private var isFlyerUploading = false
    @State private var flyerError: String?

    private var currentUserId: Int? { AuthManager.shared.currentUserId }
    private var isCreator: Bool { currentEvent.createdBy != nil && currentEvent.createdBy == currentUserId }

    init(event: Experience, vm: ExperienceActionsViewModel) {
        self.event = event
        self.vm = vm
        self._currentEvent = State(initialValue: event)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if let imgData = currentEvent.flyerImage,
                       let data = Data(base64Encoded: imgData, options: .ignoreUnknownCharacters),
                       let uiImage = UIImage(data: data) {
                        Color.clear
                            .frame(maxWidth: .infinity)
                            .frame(height: responsive.spacing(200))
                            .overlay(
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .scaledToFill()
                            )
                            .clipped()
                            .cornerRadius(14)
                            .padding(.horizontal, responsive.spacing(20))
                            .padding(.top, responsive.spacing(16))
                    }

                    VStack(alignment: .leading, spacing: responsive.spacing(16)) {
                        if let tags = currentEvent.tags, !tags.isEmpty {
                            ExperienceTagChips(tags: tags)
                        }

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
                            Label("View Experience Page", systemImage: "doc.richtext")
                                .font(.footnote.bold()).foregroundColor(Color.nostiaAccent)
                                .frame(maxWidth: .infinity).padding(.vertical, 11)
                                .background(Color.nostiaAccent.opacity(0.12)).cornerRadius(12)
                        }

                        Button { Haptics.tap(); showChat = true } label: {
                            Label("Experience Chat", systemImage: "bubble.left.and.bubble.right")
                                .font(.footnote.bold()).foregroundColor(Color.nostiaAccent)
                                .frame(maxWidth: .infinity).padding(.vertical, 11)
                                .background(Color.nostiaAccent.opacity(0.12)).cornerRadius(12)
                        }

                        Divider().background(Color.white.opacity(0.2))

                        HStack(spacing: 12) {
                            Button { Task { await rsvp("going") } } label: {
                                HStack {
                                    Image(systemName: "checkmark.circle.fill")
                                    Text("Going")
                                }
                                .frame(maxWidth: .infinity).padding(.vertical, 12)
                                .background(currentEvent.myRsvp == "going" ? Color.nostiaSuccess : Color.nostiaInput)
                                .foregroundColor(.white).cornerRadius(12)
                            }
                            .disabled(isRsvping)

                            Button { Task { await rsvp("not_going") } } label: {
                                HStack {
                                    Image(systemName: "xmark.circle.fill")
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
                                    Text(currentEvent.flyerImage != nil ? "Change Flyer" : "Add Experience Flyer")
                                }
                                .frame(maxWidth: .infinity).padding(.vertical, 12)
                                .background(Color.nostiaInput)
                                .foregroundColor(Color.nostiaAccent).cornerRadius(12)
                            }
                            .disabled(isFlyerUploading)

                            if let err = flyerError {
                                Text(err).font(.footnote).foregroundColor(Color.nostriaDanger)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }

                            Button(role: .destructive) { showDeleteConfirm = true } label: {
                                Label("Delete Experience", systemImage: "trash")
                                    .frame(maxWidth: .infinity).padding(.vertical, 12)
                                    .background(Color.nostriaDanger.opacity(0.2))
                                    .foregroundColor(Color.nostriaDanger).cornerRadius(12)
                            }
                        }
                    }
                    .padding(responsive.spacing(20))
                    .frame(maxWidth: responsive.sheetMaxWidth)
                    .frame(maxWidth: .infinity)
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
            .confirmationDialog("Delete this experience?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
                Button("Delete", role: .destructive) {
                    Task { try? await vm.deleteExperience(currentEvent.id); dismiss() }
                }
                Button("Cancel", role: .cancel) {}
            }
            .sheet(isPresented: $showFlyer) {
                ExperienceFlyerView(event: currentEvent, vm: vm)
            }
            .sheet(isPresented: $showChat) {
                ExperienceChatSheet(experienceId: currentEvent.id)
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
        guard !isRsvping else { return }

        let previousRsvp = currentEvent.myRsvp
        let previousCount = currentEvent.goingCount ?? 0

        if status == "going" && currentEvent.myRsvp != "going" {
            currentEvent.myRsvp = "going"
            currentEvent.goingCount = previousCount + 1
        } else if status == "not_going" {
            if currentEvent.myRsvp == "going" {
                currentEvent.goingCount = max(0, previousCount - 1)
            }
            currentEvent.myRsvp = "not_going"
        }

        isRsvping = true
        do {
            let updated = try await vm.rsvpExperience(experienceId: currentEvent.id, status: status)
            currentEvent = updated
        } catch {
            currentEvent.myRsvp = previousRsvp
            currentEvent.goingCount = previousCount
        }
        isRsvping = false
    }

    private func uploadFlyer(_ item: PhotosPickerItem) async {
        isFlyerUploading = true
        flyerError = nil
        guard let data = try? await item.loadTransferable(type: Data.self),
              let uiImage = UIImage(data: data),
              let compressed = uiImage.resizedForUpload().jpegData(compressionQuality: 0.6) else {
            flyerError = "Failed to load image. Please try again."
            isFlyerUploading = false
            return
        }
        if compressed.count > 4 * 1024 * 1024 {
            flyerError = "Image is too large. Please choose a smaller file."
            isFlyerUploading = false
            return
        }
        do {
            currentEvent = try await vm.updateExperienceFlyer(id: currentEvent.id, flyerImage: compressed.base64EncodedString())
        } catch {
            flyerError = "Failed to upload flyer. Please try again."
        }
        isFlyerUploading = false
    }
}

// MARK: - ExperienceFlyerView

struct ExperienceFlyerView: View {
    let event: Experience
    let vm: ExperienceActionsViewModel
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var responsive: ResponsiveLayoutManager
    @State private var currentEvent: Experience
    @State private var isRsvping = false

    init(event: Experience, vm: ExperienceActionsViewModel) {
        self.event = event
        self.vm = vm
        self._currentEvent = State(initialValue: event)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    if let imgData = currentEvent.flyerImage,
                       let data = Data(base64Encoded: imgData, options: .ignoreUnknownCharacters),
                       let uiImage = UIImage(data: data) {
                        Color.clear
                            .frame(maxWidth: .infinity)
                            .frame(height: 340)
                            .overlay(
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .scaledToFill()
                            )
                            .clipped()
                    } else {
                        LinearGradient(
                            colors: [Color.nostiaAccent.opacity(0.7), Color.nostriaPurple.opacity(0.7)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                        .frame(maxWidth: .infinity).frame(height: 220)
                        .overlay {
                            VStack(spacing: 12) {
                                Image(systemName: "sparkles")
                                    .font(.system(size: 52)).foregroundColor(.white.opacity(0.5))
                                Text("No flyer yet").font(.caption).foregroundColor(.white.opacity(0.4))
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: responsive.spacing(16)) {
                        Text(currentEvent.title).font(.title.bold()).foregroundColor(.white)
                        if let tags = currentEvent.tags, !tags.isEmpty {
                            ExperienceTagChips(tags: tags)
                        }
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
                                .frame(maxWidth: .infinity).padding(.vertical, responsive.spacing(12))
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
                                .frame(maxWidth: .infinity).padding(.vertical, responsive.spacing(12))
                                .background(currentEvent.myRsvp == "not_going" ? Color.nostriaDanger : Color.nostiaInput)
                                .foregroundColor(.white).cornerRadius(12)
                            }
                            .disabled(isRsvping)
                        }
                    }
                    .padding(responsive.spacing(20))
                    .frame(maxWidth: responsive.sheetMaxWidth)
                    .frame(maxWidth: .infinity)
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
        if let updated = try? await vm.rsvpExperience(experienceId: currentEvent.id, status: status) {
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
                    .background(.ultraThinMaterial, in: Capsule())
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

// MARK: - ExperienceCard

struct ExperienceCard: View {
    let event: Experience
    var onCreatorTap: ((Int) -> Void)? = nil
    @EnvironmentObject var responsive: ResponsiveLayoutManager

    var body: some View {
        VStack(alignment: .leading, spacing: responsive.spacing(8)) {
            HStack {
                Text(event.title).font(.headline).foregroundColor(.white)
                Spacer()
                if let vis = event.visibility, vis != "public" {
                    // Two-state visibility (D2/D6): anything non-public is "Private" (followers).
                    Label("Private", systemImage: "person.2")
                        .font(.caption.bold()).foregroundColor(.white)
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(Color.nostriaPurple)
                        .cornerRadius(12)
                }
                if let dist = event.formattedDistance {
                    Text(dist).font(.caption.bold()).foregroundColor(.white)
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(Color.nostiaAccent).cornerRadius(12)
                }
            }
            if let tags = event.tags, !tags.isEmpty {
                ExperienceTagChips(tags: tags)
            }
            if let desc = event.description, !desc.isEmpty {
                Text(desc).font(.footnote).foregroundColor(Color.nostiaTextSecond).lineLimit(2)
            }
            if let loc = event.location {
                Label(loc, systemImage: "location").font(.footnote).foregroundColor(Color.nostiaTextSecond)
            }
            HStack {
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
        .padding(responsive.spacing(16))
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
