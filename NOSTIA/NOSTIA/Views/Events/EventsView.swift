import SwiftUI
import MapKit
import Combine
import PhotosUI

@MainActor
final class ExperiencesViewModel: ObservableObject {
    @Published var events: [Experience] = []
    @Published var goingEvents: [Experience] = []
    @Published var isLoading = false
    @Published var selectedEvent: Experience?
    @Published var showCreate = false
    @Published var selectedCreatorId: Int?

    func loadAll() async {
        if let cached: [Experience] = await CacheManager.shared.get(CacheKey.experienceList) {
            events = cached
        } else {
            isLoading = true
        }
        async let allTask = ExperiencesAPI.shared.getAllExperiences()
        async let goingTask = ExperiencesAPI.shared.getMyGoingExperiences()
        let fresh = (try? await allTask) ?? []
        let freshGoing = (try? await goingTask) ?? []
        if !fresh.isEmpty {
            events = fresh
            await CacheManager.shared.set(CacheKey.experienceList, value: fresh)
        }
        goingEvents = freshGoing
        isLoading = false
    }
}

/// Experience search, presented as a sheet. Home is the discovery surface (the former
/// Explore tab's role); this sheet is where its search bar and every "See all" lands.
/// `initialTags` pre-checks the tag filter (themed Home rows pass their tags here).
struct ExperienceSearchSheet: View {
    var initialTags: [String] = []

    @StateObject private var vm = ExperiencesViewModel()
    @State private var actionsVM = ExperienceActionsViewModel()
    @State private var selectedTags: Set<String> = []
    @State private var searchText = ""
    @FocusState private var searchFocused: Bool
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var responsive: ResponsiveLayoutManager

    // Going experiences first, then everything else (de-duplicated).
    private var allEvents: [Experience] {
        let goingIds = Set(vm.goingEvents.map { $0.id })
        return vm.goingEvents + vm.events.filter { !goingIds.contains($0.id) }
    }

    private var filtered: [Experience] {
        allEvents.filter { event in
            // ANY-match: no tags selected → show all; otherwise keep experiences whose
            // tags intersect the selected set.
            let tagOK = selectedTags.isEmpty
                || !Set(event.tags ?? []).isDisjoint(with: selectedTags)
            let q = searchText.trimmingCharacters(in: .whitespaces).lowercased()
            let searchOK = q.isEmpty
                || event.title.lowercased().contains(q)
                || (event.location?.lowercased().contains(q) ?? false)
            return tagOK && searchOK
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 16) {
                    NostiaSearchField(placeholder: "Search experiences & places…", text: $searchText)
                        .focused($searchFocused)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            NostiaChip(label: "All", isActive: selectedTags.isEmpty) {
                                Haptics.select(); selectedTags.removeAll()
                            }
                            ForEach(experienceTags, id: \.self) { tag in
                                NostiaChip(label: tag.capitalized,
                                           isActive: selectedTags.contains(tag)) {
                                    Haptics.select()
                                    if selectedTags.contains(tag) { selectedTags.remove(tag) }
                                    else { selectedTags.insert(tag) }
                                }
                            }
                        }
                        .padding(.vertical, 2)
                    }

                    Text("\(filtered.count) experiences · near you & from people you follow")
                        .font(.nostiaBody(13)).foregroundColor(Color.nostiaTextSecond)

                    if vm.isLoading && vm.events.isEmpty {
                        ExperienceListSkeletonView()
                    } else if filtered.isEmpty {
                        EmptyStateView(icon: "sparkles",
                                       text: searchText.isEmpty && selectedTags.isEmpty ? "No experiences yet" : "No matches",
                                       sub: searchText.isEmpty && selectedTags.isEmpty ? "Create one from Home!" : "Try a different search or filter")
                    } else {
                        ForEach(filtered) { event in
                            Button { vm.selectedEvent = event } label: {
                                AtlasExperienceCard(event: event)
                            }
                            .buttonStyle(.nostiaTap)
                        }
                    }
                }
                .padding(.horizontal, responsive.spacing(16))
                .padding(.top, 8)
                .padding(.bottom, 40)
                .frame(maxWidth: responsive.contentMaxWidth)
                .frame(maxWidth: .infinity)
            }
            .background(Color.nostiaBackground.ignoresSafeArea())
            .scrollDismissesKeyboard(.immediately)
            .refreshable { await vm.loadAll() }
            .navigationTitle("Search")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }.foregroundColor(Color.nostiaAccent)
                }
            }
        }
        .presentationBackground(Color.nostiaBackground)
        .task {
            selectedTags = Set(initialTags)
            // Focus the field only for a blank search — a themed "See all" is a browse.
            if initialTags.isEmpty { searchFocused = true }
            await vm.loadAll()
        }
        .sheet(item: $vm.selectedEvent, onDismiss: { Task { await vm.loadAll() } }) { event in
            ExperienceDetailSheet(event: event, vm: actionsVM)
        }
        .sheet(item: Binding(
            get: { vm.selectedCreatorId.map { ProfileNavTarget(id: $0) } },
            set: { vm.selectedCreatorId = $0?.id }
        )) { target in
            NavigationStack { PublicProfileView(userId: target.id) }
                .presentationBackground(Color.nostiaBackground)
        }
    }
}

/// Plain titled list of experiences in a sheet (e.g. Home's "Experiences you're
/// visiting" → See all). Taps open the standard detail sheet.
struct ExperienceListSheet: View {
    let title: String
    let events: [Experience]

    @State private var actionsVM = ExperienceActionsViewModel()
    @State private var selectedEvent: Experience?
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var responsive: ResponsiveLayoutManager

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 16) {
                    if events.isEmpty {
                        EmptyStateView(icon: "sparkles", text: "Nothing here yet",
                                       sub: "Experiences you join will show up here")
                    } else {
                        ForEach(events) { event in
                            Button { selectedEvent = event } label: {
                                AtlasExperienceCard(event: event)
                            }
                            .buttonStyle(.nostiaTap)
                        }
                    }
                }
                .padding(.horizontal, responsive.spacing(16))
                .padding(.top, 8)
                .padding(.bottom, 40)
                .frame(maxWidth: responsive.contentMaxWidth)
                .frame(maxWidth: .infinity)
            }
            .background(Color.nostiaBackground.ignoresSafeArea())
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }.foregroundColor(Color.nostiaAccent)
                }
            }
        }
        .presentationBackground(Color.nostiaBackground)
        .sheet(item: $selectedEvent) { event in
            ExperienceDetailSheet(event: event, vm: actionsVM)
        }
    }
}

private struct ProfileNavTarget: Identifiable { let id: Int }

// MARK: - Create Experience Sheet (2-step: map pick → form)

struct CreateExperienceFromDiscoverSheet: View {
    let onCreated: (Experience) -> Void
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var locationManager: LocationManager
    @EnvironmentObject var responsive: ResponsiveLayoutManager

    @State private var step = 0
    @State private var selectedCoord: CLLocationCoordinate2D?
    @State private var mapCameraPosition = MapCameraPosition.automatic
    @State private var title = ""
    @State private var locationName = ""
    @State private var description = ""
    @State private var visibility = "public"
    @State private var selectedTags: [String] = []
    @State private var hasSchedule = false
    @State private var scheduledDate = Date().addingTimeInterval(3600)
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var coverImageData: String?
    @State private var selectedCoverPhoto: PhotosPickerItem?
    @State private var isCoverPhotoLoading = false

    // Public = wire "public"; Private = wire "followers" (D2). Only-me retired.
    let visibilityOptions = ["public", "followers"]

    var body: some View {
        NavigationStack {
            if step == 0 {
                ZStack {
                    MapReader { proxy in
                        Map(position: $mapCameraPosition) {
                            if let c = selectedCoord {
                                Annotation("", coordinate: c) {
                                    Image(systemName: "mappin.circle.fill")
                                        .font(.nostiaBody(32))
                                        .foregroundColor(Color.nostiaAccent)
                                        .shadow(color: Color.nostiaAccent.opacity(0.5), radius: 8)
                                }
                            }
                        }
                        .ignoresSafeArea(edges: .bottom)
                        .onTapGesture { location in
                            if let coord = proxy.convert(location, from: .local) {
                                selectedCoord = coord
                            }
                        }
                    }

                    VStack(spacing: 8) {
                        AddressSearchField(locationName: $locationName) { coord, name in
                            selectedCoord = coord
                            locationName = name
                            mapCameraPosition = .region(MKCoordinateRegion(
                                center: coord,
                                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                            ))
                        }
                        .padding(.horizontal, responsive.spacing(16))
                        .padding(.top, responsive.spacing(12))

                        Text(selectedCoord == nil ? "Search or tap to place pin" : "Tap to move pin")
                            .font(.caption).foregroundColor(Color.nostiaTextSecond)
                            .padding(.horizontal, 14).padding(.vertical, 8)
                            .nostiaCard(in: Capsule())

                        Spacer()
                    }
                }
                .navigationTitle("Pick Location")
                .navigationBarTitleDisplayMode(.inline)
                .toolbarBackground(.hidden, for: .navigationBar)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Cancel") { dismiss() }.foregroundColor(Color.nostiaTextSecond)
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Next") { step = 1 }
                            .foregroundColor(selectedCoord == nil ? Color.nostiaTextMuted : Color.nostiaAccent)
                            .fontWeight(.semibold)
                            .disabled(selectedCoord == nil)
                    }
                }
                .task {
                    if let loc = locationManager.location {
                        mapCameraPosition = .region(MKCoordinateRegion(
                            center: loc.coordinate,
                            span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
                        ))
                    }
                }
            } else if let coord = selectedCoord {
                ScrollView {
                    VStack(spacing: responsive.spacing(16)) {
                        Map(initialPosition: .region(MKCoordinateRegion(
                            center: coord,
                            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                        ))) {
                            Annotation("", coordinate: coord) {
                                Image(systemName: "mappin.circle.fill")
                                    .font(.nostiaBody(28)).foregroundColor(Color.nostiaAccent)
                                    .shadow(color: Color.nostiaAccent.opacity(0.5), radius: 6)
                            }
                        }
                        .frame(height: 120).cornerRadius(14)
                        .allowsHitTesting(false)

                        if let imgData = coverImageData,
                           let data = Data(base64Encoded: imgData),
                           let uiImage = UIImage(data: data) {
                            Image(uiImage: uiImage)
                                .resizable().scaledToFill()
                                .frame(maxWidth: .infinity).frame(height: 160)
                                .clipped().cornerRadius(14)
                        }

                        PhotosPicker(selection: $selectedCoverPhoto, matching: .images) {
                            HStack {
                                if isCoverPhotoLoading {
                                    ProgressView().tint(Color.nostiaAccent).scaleEffect(0.8)
                                } else {
                                    Image(systemName: "photo.badge.plus")
                                }
                                Text(coverImageData == nil ? "Add Cover Photo" : "Change Cover Photo")
                                    .font(.subheadline.bold())
                            }
                            .foregroundColor(Color.nostiaAccent)
                            .frame(maxWidth: .infinity).padding(.vertical, 12)
                            .background(Color.nostiaAccent.opacity(0.12)).cornerRadius(12)
                        }
                        .disabled(isCoverPhotoLoading)

                        NostiaTextField(label: "Experience Title *", placeholder: "What's happening?", text: $title)
                        NostiaTextField(label: "Location Name", placeholder: "e.g. Central Park…", text: $locationName)

                        ExperienceTagPicker(selectedTags: $selectedTags)

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Visibility")
                                .font(.nostiaBody(responsive.fontSize(14), weight: .semibold)).foregroundColor(Color.nostiaTextSecond)
                            HStack(spacing: 8) {
                                ForEach(visibilityOptions, id: \.self) { opt in
                                    FilterChip(title: opt == "public" ? "Public" : "Private",
                                               isActive: visibility == opt) { visibility = opt }
                                }
                            }
                            Text(visibility == "public" ? "Anyone can see this" : "Only your followers")
                                .font(.caption).foregroundColor(Color.nostiaTextMuted)
                        }

                        ExperienceScheduleField(hasSchedule: $hasSchedule, scheduledDate: $scheduledDate)

                        VStack(alignment: .leading, spacing: 6) {
                            Text("Description")
                                .font(.nostiaBody(responsive.fontSize(14), weight: .semibold)).foregroundColor(Color.nostiaTextSecond)
                            LinkInsertBar(text: $description)
                            TextEditor(text: $description)
                                .frame(minHeight: responsive.spacing(72)).padding(8)
                                .nostiaCard(in: RoundedRectangle(cornerRadius: 12))
                                .foregroundColor(Color.nostiaTextPrimary).scrollContentBackground(.hidden)
                        }

                        if let err = errorMessage {
                            Text(err).font(.caption).foregroundColor(Color.nostriaDanger)
                        }

                        Button {
                            guard !title.trimmingCharacters(in: .whitespaces).isEmpty else {
                                errorMessage = "Title is required"; return
                            }
                            isLoading = true; errorMessage = nil
                            Task {
                                do {
                                    let event = try await ExperiencesAPI.shared.createExperience(
                                        title: title.trimmingCharacters(in: .whitespaces),
                                        description: description.isEmpty ? nil : description,
                                        location: locationName.isEmpty ? nil : locationName,
                                        lat: coord.latitude,
                                        lng: coord.longitude,
                                        visibility: visibility,
                                        flyerImage: coverImageData,
                                        tags: selectedTags,
                                        eventDate: hasSchedule ? Experience.wireDate(from: scheduledDate) : nil
                                    )
                                    onCreated(event)
                                    dismiss()
                                } catch {
                                    errorMessage = error.localizedDescription
                                }
                                isLoading = false
                            }
                        } label: {
                            HStack {
                                if isLoading { ProgressView().tint(.white) }
                                else { Text("Create Experience").fontWeight(.bold) }
                            }
                            .frame(maxWidth: .infinity).padding(responsive.spacing(16))
                            .background(title.isEmpty
                                ? AnyShapeStyle(Color.nostiaDisabled)
                                : AnyShapeStyle(LinearGradient(colors: [Color.nostiaAccent, Color.nostriaPurple],
                                                               startPoint: .leading, endPoint: .trailing)))
                            .foregroundColor(.white).cornerRadius(14)
                        }
                        .disabled(isLoading || title.isEmpty || isCoverPhotoLoading)
                    }
                    .padding(responsive.spacing(20))
                    .frame(maxWidth: responsive.sheetMaxWidth)
                    .frame(maxWidth: .infinity)
                }
                .background(.clear)
                .navigationTitle("New Experience")
                .navigationBarTitleDisplayMode(.inline)
                .toolbarBackground(.hidden, for: .navigationBar)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Back") { step = 0 }.foregroundColor(Color.nostiaTextSecond)
                    }
                }
            }
        }
        .presentationBackground(Color.nostiaBackground)
        .onChange(of: selectedCoverPhoto) { _, item in
            guard let item else { return }
            isCoverPhotoLoading = true
            errorMessage = nil
            Task {
                defer { isCoverPhotoLoading = false }
                guard let data = try? await item.loadTransferable(type: Data.self),
                      let img = UIImage(data: data),
                      let compressed = img.resizedForUpload().jpegData(compressionQuality: 0.6) else {
                    coverImageData = nil
                    errorMessage = "Failed to load photo. Please try again."
                    return
                }
                if compressed.count > 4 * 1024 * 1024 {
                    coverImageData = nil
                    errorMessage = "Image is too large. Please choose a smaller file."
                    return
                }
                coverImageData = compressed.base64EncodedString()
            }
        }
    }
}
