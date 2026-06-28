import SwiftUI
import MapKit
import PhotosUI

// Minimal view model — only the status/rating/delete/flyer actions needed by the map's ExperienceDetailSheet.
@MainActor
final class ExperienceActionsViewModel {
    func setStatus(experienceId: Int, status: String) async throws -> Experience {
        try await ExperiencesAPI.shared.setStatus(experienceId: experienceId, status: status)
    }

    func rateExperience(experienceId: Int, rating: Double) async throws -> Experience {
        try await ExperiencesAPI.shared.rateExperience(experienceId: experienceId, rating: rating)
    }

    func deleteExperience(_ experienceId: Int) async throws {
        try await ExperiencesAPI.shared.deleteExperience(experienceId)
    }

    func updateExperienceFlyer(id: Int, flyerImage: String) async throws -> Experience {
        try await ExperiencesAPI.shared.updateExperience(id: id, flyerImage: flyerImage)
    }
}

// MARK: - Status / Rating shared building blocks (D1–D4)

/// The two-state Visited / Visiting control shared by ExperienceDetailSheet and
/// ExperienceFlyerView (D1). Neither state is selected by default; tapping a state
/// selects it, tapping the selected state again clears it (status → "none").
struct StatusButtons: View {
    let myStatus: String?
    let isBusy: Bool
    let onSelect: (String) -> Void   // "visited" | "visiting" — caller toggles/clears

    var body: some View {
        HStack(spacing: 12) {
            statusButton(
                value: "visited",
                title: "Visited",
                icon: "checkmark.seal.fill",
                selectedColor: Color.nostiaSuccess
            )
            statusButton(
                value: "visiting",
                title: "Visiting",
                icon: "figure.walk",
                selectedColor: Color.nostiaAccent
            )
        }
    }

    @ViewBuilder
    private func statusButton(value: String, title: String, icon: String, selectedColor: Color) -> some View {
        let isSelected = myStatus == value
        Button { onSelect(value) } label: {
            HStack(spacing: 6) {
                if isBusy { ProgressView().tint(isSelected ? .white : selectedColor).scaleEffect(0.8) }
                else { Image(systemName: icon).foregroundColor(isSelected ? .white : selectedColor) }
                Text(title).fontWeight(.bold)
            }
            .font(.system(size: 15))
            .frame(maxWidth: .infinity).padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(isSelected ? selectedColor : Color.white)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(isSelected ? selectedColor : Color.nostriaBorder, lineWidth: 1)
            )
            .foregroundColor(isSelected ? .white : Color(hex: "4B5563"))
        }
        .disabled(isBusy)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}

/// The interactive rating row revealed once the user has a status (D2). Shows their own
/// star picker; submitting calls `onRate`.
struct MyRatingRow: View {
    let myRating: Double?
    let isBusy: Bool
    let onRate: (Double) -> Void

    var body: some View {
        HStack {
            Text("Your rating")
                .font(.subheadline).foregroundColor(Color.nostiaTextSecond)
            Spacer()
            if isBusy {
                ProgressView().tint(Color.nostiaWarning).scaleEffect(0.8)
            } else {
                StarRatingView(rating: myRating ?? 0, size: 24, spacing: 4, isInteractive: true, onRate: onRate)
            }
        }
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
    @State private var isStatusUpdating = false
    @State private var isRating = false
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
                                Text(attributed).font(.body).foregroundColor(Color.nostiaTextPrimary).tint(Color.nostiaAccent)
                            } else {
                                Text(desc).font(.body).foregroundColor(Color.nostiaTextPrimary)
                            }
                        }

                        HStack(spacing: responsive.spacing(14)) {
                            // D5: visited count replaces the old going count.
                            Label("\(currentEvent.visitedCount ?? 0) visited", systemImage: "checkmark.seal")
                                .font(.subheadline).foregroundColor(Color.nostiaSuccess)
                            // D4: server-computed average rating.
                            AverageRatingBadge(avgRating: currentEvent.avgRating,
                                               ratingCount: currentEvent.ratingCount, starSize: 14)
                        }

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

                        Divider().background(Color.nostiaDivider)

                        // D1: two-state Visited / Visiting control.
                        StatusButtons(myStatus: currentEvent.myStatus, isBusy: isStatusUpdating) { value in
                            Task { await toggleStatus(value) }
                        }

                        // D2: rating unlocks once Visited or Visiting is selected.
                        if currentEvent.myStatus == "visited" || currentEvent.myStatus == "visiting" {
                            MyRatingRow(myRating: currentEvent.myRating, isBusy: isRating) { value in
                                Task { await rate(value) }
                            }
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
                        .presentationBackground(Color.nostiaBackground)
                }
            }
            .onChange(of: selectedFlyerItem) { _, item in
                guard let item else { return }
                Task { await uploadFlyer(item) }
            }
        }
        .presentationBackground(Color.nostiaBackground)
    }

    // D1: tap a state to select it; tap the selected state again to clear it ("none").
    private func toggleStatus(_ tapped: String) async {
        guard !isStatusUpdating else { return }

        let previousStatus = currentEvent.myStatus
        let previousVisited = currentEvent.visitedCount ?? 0
        let previousRating = currentEvent.myRating

        let newStatus = (previousStatus == tapped) ? "none" : tapped

        // Optimistic update of myStatus + visitedCount.
        let wasVisited = previousStatus == "visited"
        let willBeVisited = newStatus == "visited"
        currentEvent.myStatus = (newStatus == "none") ? nil : newStatus
        currentEvent.visitedCount = max(0, previousVisited + (willBeVisited ? 1 : 0) - (wasVisited ? 1 : 0))
        // Q-D: clearing status withdraws the rating.
        if newStatus == "none" { currentEvent.myRating = nil }

        isStatusUpdating = true
        do {
            let updated = try await vm.setStatus(experienceId: currentEvent.id, status: newStatus)
            currentEvent = updated
        } catch {
            currentEvent.myStatus = previousStatus
            currentEvent.visitedCount = previousVisited
            currentEvent.myRating = previousRating
        }
        isStatusUpdating = false
    }

    // D3: submit a 0…5 (half-step) rating for the current user.
    private func rate(_ value: Double) async {
        guard !isRating else { return }
        let previousRating = currentEvent.myRating
        currentEvent.myRating = value
        isRating = true
        do {
            let updated = try await vm.rateExperience(experienceId: currentEvent.id, rating: value)
            currentEvent = updated
        } catch {
            currentEvent.myRating = previousRating
        }
        isRating = false
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
    @State private var isStatusUpdating = false
    @State private var isRating = false

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
                        Text(currentEvent.title).font(.nostiaDisplay(26)).foregroundColor(Color.nostiaTextPrimary)
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
                        HStack(spacing: responsive.spacing(14)) {
                            Label("\(currentEvent.visitedCount ?? 0) visited", systemImage: "checkmark.seal")
                                .font(.subheadline).foregroundColor(Color.nostiaSuccess)
                            AverageRatingBadge(avgRating: currentEvent.avgRating,
                                               ratingCount: currentEvent.ratingCount, starSize: 14)
                        }
                        if let desc = currentEvent.description, !desc.isEmpty {
                            Divider().background(Color.nostiaDivider)
                            if let attributed = try? AttributedString(
                                markdown: desc,
                                options: AttributedString.MarkdownParsingOptions(
                                    interpretedSyntax: .inlineOnlyPreservingWhitespace
                                )
                            ) {
                                Text(attributed).font(.body).foregroundColor(Color.nostiaTextPrimary).tint(Color.nostiaAccent)
                            } else {
                                Text(desc).font(.body).foregroundColor(Color.nostiaTextPrimary)
                            }
                        }
                        Divider().background(Color.nostiaDivider)
                        // D1: two-state Visited / Visiting control (kept in sync with the detail sheet).
                        StatusButtons(myStatus: currentEvent.myStatus, isBusy: isStatusUpdating) { value in
                            Task { await toggleStatus(value) }
                        }
                        // D2: rating unlocks once Visited or Visiting is selected.
                        if currentEvent.myStatus == "visited" || currentEvent.myStatus == "visiting" {
                            MyRatingRow(myRating: currentEvent.myRating, isBusy: isRating) { value in
                                Task { await rate(value) }
                            }
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
        .presentationBackground(Color.nostiaBackground)
    }

    // D1: tap a state to select it; tap the selected state again to clear it ("none").
    private func toggleStatus(_ tapped: String) async {
        guard !isStatusUpdating else { return }
        let previousStatus = currentEvent.myStatus
        let previousVisited = currentEvent.visitedCount ?? 0
        let previousRating = currentEvent.myRating

        let newStatus = (previousStatus == tapped) ? "none" : tapped
        let wasVisited = previousStatus == "visited"
        let willBeVisited = newStatus == "visited"
        currentEvent.myStatus = (newStatus == "none") ? nil : newStatus
        currentEvent.visitedCount = max(0, previousVisited + (willBeVisited ? 1 : 0) - (wasVisited ? 1 : 0))
        if newStatus == "none" { currentEvent.myRating = nil }   // Q-D: rating withdrawn on clear

        isStatusUpdating = true
        if let updated = try? await vm.setStatus(experienceId: currentEvent.id, status: newStatus) {
            currentEvent = updated
        } else {
            currentEvent.myStatus = previousStatus
            currentEvent.visitedCount = previousVisited
            currentEvent.myRating = previousRating
        }
        isStatusUpdating = false
    }

    // D3: submit a 0…5 (half-step) rating for the current user.
    private func rate(_ value: Double) async {
        guard !isRating else { return }
        let previousRating = currentEvent.myRating
        currentEvent.myRating = value
        isRating = true
        if let updated = try? await vm.rateExperience(experienceId: currentEvent.id, rating: value) {
            currentEvent = updated
        } else {
            currentEvent.myRating = previousRating
        }
        isRating = false
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
                .presentationBackground(Color.nostiaBackground)
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
                Text(event.title).font(.nostiaDisplay(17, weight: .bold)).foregroundColor(Color.nostiaTextPrimary)
                Spacer()
                // D4/Q-A: average rating star sits top-right of the card.
                AverageRatingBadge(avgRating: event.avgRating, ratingCount: event.ratingCount)
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
                // D5: visited count replaces the old going count.
                if let visited = event.visitedCount, visited > 0 {
                    Label("\(visited) visited", systemImage: "checkmark.seal")
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
        .nostiaCard(in: RoundedRectangle(cornerRadius: 16))
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
                        .font(.system(size: 14, weight: .semibold)).foregroundColor(Color.nostiaTextSecond)
                    TextField("https://...", text: $url)
                        .foregroundColor(Color.nostiaTextPrimary).autocorrectionDisabled()
                        .textInputAutocapitalization(.never).keyboardType(.URL)
                        .padding(12).nostiaCard(in: RoundedRectangle(cornerRadius: 12))
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
