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

struct ExperiencesView: View {
    @StateObject private var vm = ExperiencesViewModel()
    @State private var actionsVM = ExperienceActionsViewModel()
    @State private var selectedTags: Set<String> = []
    @State private var searchText = ""
    @EnvironmentObject var responsive: ResponsiveLayoutManager
    @EnvironmentObject var router: DeepLinkRouter

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

    /// Copy a pending themed selection from Home into the filter, then clear the channel
    /// so a later manual visit to Explore isn't re-filtered.
    private func consumePendingTags() {
        guard !router.pendingExploreTags.isEmpty else { return }
        selectedTags = Set(router.pendingExploreTags)
        router.pendingExploreTags = []
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        NostiaScreenTitle(title: "Explore")
                        Text("\(filtered.count) experiences near you · from people you follow")
                            .font(.system(size: 14)).foregroundColor(Color.nostiaTextSecond)
                    }
                    .padding(.top, 4)

                    NostiaSearchField(placeholder: "Search experiences & places…", text: $searchText)

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

                    if vm.isLoading && vm.events.isEmpty {
                        ExperienceListSkeletonView()
                    } else if filtered.isEmpty {
                        EmptyStateView(icon: "sparkles",
                                       text: searchText.isEmpty && selectedTags.isEmpty ? "No experiences yet" : "No matches",
                                       sub: searchText.isEmpty && selectedTags.isEmpty ? "Tap + to create one!" : "Try a different filter")
                    } else {
                        ForEach(filtered) { event in
                            Button { vm.selectedEvent = event } label: {
                                AtlasExperienceCard(event: event)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.horizontal, responsive.spacing(16))
                .padding(.bottom, 120)
                .frame(maxWidth: responsive.contentMaxWidth)
                .frame(maxWidth: .infinity)
            }
            .background(.clear)
            .refreshable { await vm.loadAll() }

            Button { vm.showCreate = true } label: {
                Image(systemName: "plus")
                    .font(.system(size: responsive.fontSize(31), weight: .semibold)).foregroundColor(.white)
                    .frame(width: 60, height: 60)
                    .background(Color.nostiaAccent).clipShape(Circle())
                    .shadow(color: Color.nostiaAccent.opacity(0.6), radius: 18, y: 8)
            }
            .padding(.trailing, responsive.spacing(22))
            .padding(.bottom, 100)
        }
        .task { await vm.loadAll() }
        .onAppear { consumePendingTags() }
        .onChange(of: router.pendingExploreTags) { _, _ in consumePendingTags() }
        .sheet(isPresented: $vm.showCreate, onDismiss: { Task { await vm.loadAll() } }) {
            CreateExperienceFromDiscoverSheet { newEvent in
                vm.events.insert(newEvent, at: 0)
                Task { await CacheManager.shared.invalidate(CacheKey.experienceList) }
            }
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
                                        .font(.system(size: 32))
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
                                    .font(.system(size: 28)).foregroundColor(Color.nostiaAccent)
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
                                .font(.system(size: responsive.fontSize(14), weight: .semibold)).foregroundColor(Color.nostiaTextSecond)
                            HStack(spacing: 8) {
                                ForEach(visibilityOptions, id: \.self) { opt in
                                    FilterChip(title: opt == "public" ? "Public" : "Private",
                                               isActive: visibility == opt) { visibility = opt }
                                }
                            }
                            Text(visibility == "public" ? "Anyone can see this" : "Only your followers")
                                .font(.caption).foregroundColor(Color.nostiaTextMuted)
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            Text("Description")
                                .font(.system(size: responsive.fontSize(14), weight: .semibold)).foregroundColor(Color.nostiaTextSecond)
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
                                        tags: selectedTags
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
                                ? AnyShapeStyle(Color(hex: "C2CAD3"))
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
