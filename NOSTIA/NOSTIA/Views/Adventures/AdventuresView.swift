import SwiftUI
import MapKit
import PhotosUI

struct AdventuresView: View {
    @StateObject private var vm = AdventuresViewModel()
    @State private var showCreateAdventure = false
    @State private var showCreateEvent = false
    @State private var selectedEvent: Event?
    @State private var selectedCreatorId: Int?

    var body: some View {
        VStack(spacing: 0) {
            // Search bar
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass").foregroundColor(Color.nostiaTextSecond)
                TextField("Search adventures...", text: $vm.searchQuery)
                    .foregroundColor(.white).submitLabel(.search)
                    .onSubmit { Task { await vm.search() } }
                    .autocorrectionDisabled()
            }
            .padding(12)
            .glassEffect(in: RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal, 16).padding(.vertical, 8)

            // Tab selector
            HStack(spacing: 8) {
                TabButton(title: "Events", isActive: vm.selectedTab == .events) { vm.selectedTab = .events }
                TabButton(title: "Adventures", isActive: vm.selectedTab == .adventures) { vm.selectedTab = .adventures }
            }
            .padding(.horizontal, 16).padding(.bottom, 8)

            if vm.isLoading {
                LoadingView()
            } else if vm.selectedTab == .events {
                ZStack(alignment: .bottomTrailing) {
                    List(vm.events) { event in
                        Button(action: { selectedEvent = event }) {
                            EventCard(event: event, onCreatorTap: { id in selectedCreatorId = id })
                        }
                        .buttonStyle(.plain)
                        .listRowBackground(Color.clear).listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                    }
                    .listStyle(.plain).background(.clear).scrollContentBackground(.hidden)
                    .refreshable { await vm.loadAll() }
                    .overlay {
                        if vm.events.isEmpty { EmptyStateView(icon: "calendar", text: "No events", sub: "Tap + to create one!") }
                    }

                    Button(action: { showCreateEvent = true }) {
                        Image(systemName: "plus")
                            .font(.system(size: 22, weight: .bold)).foregroundColor(.white)
                            .frame(width: 56, height: 56)
                            .background(Color.nostiaAccent).clipShape(Circle())
                            .shadow(color: Color.nostiaAccent.opacity(0.5), radius: 12, y: 6)
                    }
                    .padding(20)
                }
            } else {
                // Category filters
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(vm.categories, id: \.self) { cat in
                            FilterChip(
                                title: cat,
                                isActive: cat == "All" ? vm.selectedCategory == nil : vm.selectedCategory == cat,
                                action: {
                                    vm.selectedCategory = cat == "All" ? nil : cat
                                    Task { await vm.search() }
                                }
                            )
                        }
                    }
                    .padding(.horizontal, 16)
                }
                .padding(.bottom, 8)

                ZStack(alignment: .bottomTrailing) {
                    List(vm.adventures) { adventure in
                        AdventureCard(adventure: adventure)
                            .listRowBackground(Color.clear).listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                    }
                    .listStyle(.plain).background(.clear).scrollContentBackground(.hidden)
                    .refreshable { await vm.loadAll() }
                    .overlay {
                        if vm.adventures.isEmpty {
                            EmptyStateView(icon: "safari", text: "No adventures", sub: "Be the first to add one!")
                        }
                    }

                    Button(action: { showCreateAdventure = true }) {
                        Image(systemName: "plus")
                            .font(.system(size: 22, weight: .bold)).foregroundColor(.white)
                            .frame(width: 56, height: 56)
                            .background(Color.nostiaAccent).clipShape(Circle())
                            .shadow(color: Color.nostiaAccent.opacity(0.5), radius: 12, y: 6)
                    }
                    .padding(20)
                }
            }
        }
        .background(.clear)
        .task { await vm.loadAll() }
        .sheet(isPresented: $showCreateAdventure) {
            CreateAdventureSheet(vm: vm, isPresented: $showCreateAdventure)
        }
        .sheet(isPresented: $showCreateEvent) {
            CreateEventFromDiscoverSheet(vm: vm, isPresented: $showCreateEvent)
        }
        .sheet(item: $selectedEvent) { event in
            EventDetailSheet(event: event, vm: vm)
        }
        .sheet(item: Binding(
            get: { selectedCreatorId.map { ProfileNavTarget(id: $0) } },
            set: { selectedCreatorId = $0?.id }
        )) { target in
            NavigationStack { PublicProfileView(userId: target.id) }
            .presentationBackground(.ultraThinMaterial)
        }
    }
}

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

// MARK: - Create Event from Discover tab (2-step: map pick → form)

struct CreateEventFromDiscoverSheet: View {
    @ObservedObject var vm: AdventuresViewModel
    @Binding var isPresented: Bool

    @State private var step = 0
    @State private var selectedCoord: CLLocationCoordinate2D?
    @State private var mapCameraPosition = MapCameraPosition.automatic
    @State private var title = ""
    @State private var locationName = ""
    @State private var description = ""
    @State private var eventDate = Date().addingTimeInterval(3600)
    @State private var visibility = "public"
    @State private var isLoading = false
    @State private var errorMessage: String?

    let visibilityOptions = ["public", "friends", "private"]

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
                        AddressSearchField(locationName: $locationName) { coord, _ in
                            selectedCoord = coord
                            mapCameraPosition = .region(MKCoordinateRegion(
                                center: coord,
                                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                            ))
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 12)

                        Text(selectedCoord == nil ? "Search or tap to place pin" : "Tap to move pin")
                            .font(.caption).foregroundColor(.white.opacity(0.8))
                            .padding(.horizontal, 14).padding(.vertical, 8)
                            .glassEffect(in: Capsule())

                        Spacer()
                    }
                }
                .navigationTitle("Pick Location")
                .navigationBarTitleDisplayMode(.inline)
                .toolbarBackground(.hidden, for: .navigationBar)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Cancel") { isPresented = false }.foregroundColor(Color.nostiaTextSecond)
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Next") { step = 1 }
                            .foregroundColor(selectedCoord == nil ? Color.nostiaTextMuted : Color.nostiaAccent)
                            .fontWeight(.semibold)
                            .disabled(selectedCoord == nil)
                    }
                }
            } else if let coord = selectedCoord {
                ScrollView {
                    VStack(spacing: 16) {
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

                        NostiaTextField(label: "Event Title *", placeholder: "What's happening?", text: $title)
                        NostiaTextField(label: "Location Name", placeholder: "e.g. Central Park…", text: $locationName)

                        VStack(alignment: .leading, spacing: 6) {
                            Text("Date & Time *")
                                .font(.system(size: 14, weight: .semibold)).foregroundColor(.white.opacity(0.7))
                            DatePicker("", selection: $eventDate, displayedComponents: [.date, .hourAndMinute])
                                .datePickerStyle(.compact).labelsHidden()
                                .padding(12).glassEffect(in: RoundedRectangle(cornerRadius: 12))
                                .colorScheme(.dark)
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Visibility")
                                .font(.system(size: 14, weight: .semibold)).foregroundColor(.white.opacity(0.7))
                            HStack(spacing: 8) {
                                ForEach(visibilityOptions, id: \.self) { opt in
                                    FilterChip(title: opt.capitalized, isActive: visibility == opt) { visibility = opt }
                                }
                            }
                            Text(visibility == "public" ? "Anyone can see this" :
                                 visibility == "friends" ? "Only your friends" : "Only you")
                                .font(.caption).foregroundColor(Color.nostiaTextMuted)
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            Text("Description")
                                .font(.system(size: 14, weight: .semibold)).foregroundColor(.white.opacity(0.7))
                            LinkInsertBar(text: $description)
                            TextEditor(text: $description)
                                .frame(minHeight: 72).padding(8)
                                .glassEffect(in: RoundedRectangle(cornerRadius: 12))
                                .foregroundColor(.white).scrollContentBackground(.hidden)
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
                                    try await vm.createEvent(
                                        title: title.trimmingCharacters(in: .whitespaces),
                                        description: description.isEmpty ? nil : description,
                                        location: locationName.isEmpty ? nil : locationName,
                                        eventDate: eventDate,
                                        visibility: visibility,
                                        latitude: coord.latitude,
                                        longitude: coord.longitude
                                    )
                                    isPresented = false
                                } catch { errorMessage = error.localizedDescription }
                                isLoading = false
                            }
                        } label: {
                            HStack {
                                if isLoading { ProgressView().tint(.white) }
                                else { Text("Create Event").fontWeight(.bold) }
                            }
                            .frame(maxWidth: .infinity).padding()
                            .background(title.isEmpty
                                ? AnyShapeStyle(Color.nostiaInput)
                                : AnyShapeStyle(LinearGradient(colors: [Color.nostiaAccent, Color.nostriaPurple],
                                                               startPoint: .leading, endPoint: .trailing)))
                            .foregroundColor(.white).cornerRadius(14)
                        }
                        .disabled(isLoading || title.isEmpty)
                    }
                    .padding(20)
                }
                .background(.clear)
                .navigationTitle("New Event")
                .navigationBarTitleDisplayMode(.inline)
                .toolbarBackground(.hidden, for: .navigationBar)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Back") { step = 0 }.foregroundColor(Color.nostiaTextSecond)
                    }
                }
            }
        }
        .presentationBackground(.ultraThinMaterial)
    }
}

// MARK: - Event Detail Sheet

struct EventDetailSheet: View {
    let event: Event
    @ObservedObject var vm: AdventuresViewModel
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

    init(event: Event, vm: AdventuresViewModel) {
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
                            .clipped()
                            .cornerRadius(14)
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
                                .background(Color.nostiaAccent.opacity(0.12))
                                .cornerRadius(12)
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
        let b64 = compressed.base64EncodedString()
        if let updated = try? await AdventuresAPI.shared.updateEvent(id: currentEvent.id, flyerImage: b64) {
            currentEvent = updated
        }
        isFlyerUploading = false
    }
}

// MARK: - Event Flyer View

struct EventFlyerView: View {
    let event: Event
    @ObservedObject var vm: AdventuresViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var currentEvent: Event
    @State private var isRsvping = false

    init(event: Event, vm: AdventuresViewModel) {
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
                            .frame(maxWidth: .infinity).frame(height: 340)
                            .clipped()
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
                                Text("No flyer yet")
                                    .font(.caption).foregroundColor(.white.opacity(0.4))
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 16) {
                        Text(currentEvent.title)
                            .font(.title.bold()).foregroundColor(.white)

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

// MARK: - Link Insert

struct LinkInsertBar: View {
    @Binding var text: String
    @State private var showSheet = false

    var body: some View {
        HStack {
            Button { showSheet = true } label: {
                Label("Add Link", systemImage: "link")
                    .font(.caption.bold())
                    .foregroundColor(Color.nostiaAccent)
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
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white.opacity(0.7))
                    TextField("https://...", text: $url)
                        .foregroundColor(.white)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)
                        .padding(12)
                        .glassEffect(in: RoundedRectangle(cornerRadius: 12))
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
                        let md = displayText.isEmpty ? url : "[\(displayText)](\(url))"
                        onInsert(md)
                        dismiss()
                    }
                    .foregroundColor(url.isEmpty ? Color.nostiaTextMuted : Color.nostiaAccent)
                    .fontWeight(.semibold)
                    .disabled(url.isEmpty)
                }
            }
        }
    }
}

// MARK: - Supporting views

struct AdventureCard: View {
    let adventure: Adventure
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(adventure.title).font(.headline).foregroundColor(.white)
                Spacer()
                if let diff = adventure.difficulty {
                    DifficultyBadge(difficulty: diff)
                }
            }
            if let desc = adventure.description, !desc.isEmpty {
                Text(desc).font(.footnote).foregroundColor(Color.nostiaTextSecond).lineLimit(2)
            }
            HStack(spacing: 16) {
                if let loc = adventure.location {
                    Label(loc, systemImage: "location").font(.caption).foregroundColor(Color.nostiaTextSecond)
                }
                if let dur = adventure.duration {
                    Label(dur, systemImage: "clock").font(.caption).foregroundColor(Color.nostiaTextSecond)
                }
                if let price = adventure.price {
                    Label(String(format: "$%.0f", price), systemImage: "dollarsign.circle")
                        .font(.caption).foregroundColor(Color.nostiaSuccess)
                }
            }
        }
        .padding(16)
        .glassEffect(in: RoundedRectangle(cornerRadius: 16))
    }
}

struct CreateAdventureSheet: View {
    @ObservedObject var vm: AdventuresViewModel
    @Binding var isPresented: Bool

    @State private var title = ""
    @State private var location = ""
    @State private var description = ""
    @State private var selectedCategory: String? = nil
    @State private var selectedDifficulty: String? = nil
    @State private var isLoading = false
    @State private var errorMessage: String? = nil

    let categories = ["hiking", "climbing", "water-sports", "camping", "cycling", "other"]
    let difficulties = ["easy", "moderate", "hard", "expert"]

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Group {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Title *").font(.caption.bold()).foregroundColor(.white.opacity(0.7))
                            TextField("e.g., Eagle Peak Trail", text: $title)
                                .padding(12)
                                .glassEffect(in: RoundedRectangle(cornerRadius: 10))
                                .foregroundColor(.white)
                        }
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Location *").font(.caption.bold()).foregroundColor(.white.opacity(0.7))
                            TextField("e.g., Rocky Mountain National Park", text: $location)
                                .padding(12)
                                .glassEffect(in: RoundedRectangle(cornerRadius: 10))
                                .foregroundColor(.white)
                        }
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Description").font(.caption.bold()).foregroundColor(.white.opacity(0.7))
                            TextEditor(text: $description)
                                .frame(minHeight: 80)
                                .padding(8)
                                .glassEffect(in: RoundedRectangle(cornerRadius: 10))
                                .foregroundColor(.white)
                                .scrollContentBackground(.hidden)
                        }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Category").font(.caption.bold()).foregroundColor(.white.opacity(0.7))
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(categories, id: \.self) { cat in
                                    FilterChip(
                                        title: cat.capitalized,
                                        isActive: selectedCategory == cat,
                                        action: { selectedCategory = selectedCategory == cat ? nil : cat }
                                    )
                                }
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Difficulty").font(.caption.bold()).foregroundColor(.white.opacity(0.7))
                        HStack(spacing: 8) {
                            ForEach(difficulties, id: \.self) { diff in
                                FilterChip(
                                    title: diff.capitalized,
                                    isActive: selectedDifficulty == diff,
                                    action: { selectedDifficulty = selectedDifficulty == diff ? nil : diff }
                                )
                            }
                        }
                    }

                    if let err = errorMessage {
                        Text(err).font(.caption).foregroundColor(Color.nostriaDanger)
                    }

                    Button(action: {
                        guard !title.trimmingCharacters(in: .whitespaces).isEmpty,
                              !location.trimmingCharacters(in: .whitespaces).isEmpty else {
                            errorMessage = "Title and location are required"
                            return
                        }
                        isLoading = true; errorMessage = nil
                        Task {
                            do {
                                try await vm.createAdventure(
                                    title: title.trimmingCharacters(in: .whitespaces),
                                    location: location.trimmingCharacters(in: .whitespaces),
                                    description: description.trimmingCharacters(in: .whitespaces),
                                    category: selectedCategory,
                                    difficulty: selectedDifficulty
                                )
                                isPresented = false
                            } catch {
                                errorMessage = error.localizedDescription
                            }
                            isLoading = false
                        }
                    }) {
                        HStack {
                            if isLoading { ProgressView().tint(.white) }
                            else { Text("Create Adventure").fontWeight(.bold) }
                        }
                        .frame(maxWidth: .infinity).padding()
                        .background(
                            title.isEmpty || location.isEmpty
                                ? AnyShapeStyle(Color.nostiaInput)
                                : AnyShapeStyle(LinearGradient(colors: [Color.nostiaAccent, Color.nostriaPurple],
                                                               startPoint: .leading, endPoint: .trailing))
                        )
                        .foregroundColor(.white).cornerRadius(14)
                        .shadow(color: Color.nostiaAccent.opacity(title.isEmpty ? 0 : 0.4), radius: 10, y: 5)
                    }
                    .disabled(isLoading || title.isEmpty || location.isEmpty)
                }
                .padding(20)
            }
            .background(.clear)
            .navigationTitle("New Adventure")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { isPresented = false }.foregroundColor(Color.nostiaTextSecond)
                }
            }
        }
        .presentationBackground(.ultraThinMaterial)
    }
}

private struct ProfileNavTarget: Identifiable { let id: Int }

struct DifficultyBadge: View {
    let difficulty: String
    var color: Color {
        switch difficulty.lowercased() {
        case "easy": return Color.nostiaSuccess
        case "moderate": return Color.nostiaWarning
        case "hard": return Color.nostriaDanger
        case "expert": return Color.nostriaPurple
        default: return Color.nostiaTextSecond
        }
    }
    var body: some View {
        Text(difficulty).font(.caption.bold()).foregroundColor(.white)
            .padding(.horizontal, 8).padding(.vertical, 4)
            .background(color).cornerRadius(12)
    }
}
