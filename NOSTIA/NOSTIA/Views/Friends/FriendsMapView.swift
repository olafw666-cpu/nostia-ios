import SwiftUI
import MapKit

struct FriendsMapView: View {
    @State private var friendLocations: [FriendLocation] = []
    @State private var events: [Event] = []
    @State private var isLoading = false
    @State private var cameraPosition = MapCameraPosition.automatic
    @State private var pendingCoordinate: CLLocationCoordinate2D?
    @State private var showCreateEvent = false
    @State private var selectedEvent: Event?
    @StateObject private var adventuresVM = AdventuresViewModel()

    var body: some View {
        ZStack(alignment: .bottom) {
            MapReader { proxy in
                Map(position: $cameraPosition) {
                    // Friend location pins
                    ForEach(friendLocations) { friend in
                        Annotation(friend.name, coordinate: CLLocationCoordinate2D(
                            latitude: friend.latitude,
                            longitude: friend.longitude
                        )) {
                            VStack(spacing: 4) {
                                AvatarView(initial: String(friend.name.prefix(1)).uppercased(),
                                           color: Color.nostiaAccent, size: 36)
                                    .overlay(Circle().stroke(.white.opacity(0.5), lineWidth: 2))
                                    .shadow(color: Color.nostiaAccent.opacity(0.5), radius: 8)
                                Text(friend.name.components(separatedBy: " ").first ?? friend.name)
                                    .font(.caption.bold()).foregroundColor(.white)
                                    .padding(.horizontal, 6).padding(.vertical, 2)
                                    .glassEffect(in: Capsule())
                            }
                        }
                    }

                    // Event pins
                    ForEach(events) { event in
                        if let lat = event.latitude, let lng = event.longitude {
                            Annotation(event.title, coordinate: CLLocationCoordinate2D(
                                latitude: lat, longitude: lng
                            )) {
                                let pinColor: Color = event.visibility == "friends" ? .blue : Color.nostiaWarning
                                VStack(spacing: 4) {
                                    ZStack {
                                        Circle()
                                            .fill(pinColor.opacity(0.2))
                                            .frame(width: 44, height: 44)
                                            .overlay(Circle().stroke(pinColor.opacity(0.6), lineWidth: 1.5))
                                        Image(systemName: "calendar")
                                            .font(.system(size: 18, weight: .semibold))
                                            .foregroundColor(pinColor)
                                    }
                                    .shadow(color: pinColor.opacity(0.4), radius: 8)
                                    Text(event.title)
                                        .font(.caption.bold()).foregroundColor(.white)
                                        .lineLimit(1)
                                        .padding(.horizontal, 6).padding(.vertical, 2)
                                        .glassEffect(in: Capsule())
                                }
                                .onTapGesture { selectedEvent = event }
                            }
                        }
                    }

                    // Pending pin for new event (shown while sheet is open)
                    if let coord = pendingCoordinate {
                        Annotation("New Event", coordinate: coord) {
                            ZStack {
                                Circle()
                                    .fill(Color.nostiaAccent.opacity(0.25))
                                    .frame(width: 44, height: 44)
                                    .overlay(Circle().stroke(Color.nostiaAccent, lineWidth: 2))
                                Image(systemName: "plus")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(Color.nostiaAccent)
                            }
                            .shadow(color: Color.nostiaAccent.opacity(0.5), radius: 10)
                        }
                    }
                }
                .ignoresSafeArea(edges: .bottom)
                .gesture(
                    LongPressGesture(minimumDuration: 0.5)
                        .sequenced(before: DragGesture(minimumDistance: 0, coordinateSpace: .local))
                        .onEnded { value in
                            if case .second(true, let drag) = value,
                               let location = drag?.location,
                               let coord = proxy.convert(location, from: .local) {
                                pendingCoordinate = coord
                                showCreateEvent = true
                            }
                        }
                )
            }

            if isLoading {
                ProgressView().tint(Color.nostiaAccent)
                    .padding(16)
                    .glassEffect(in: RoundedRectangle(cornerRadius: 12))
                    .padding(.bottom, 100)
            }

            if !isLoading && friendLocations.isEmpty && events.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "map").font(.system(size: 48)).foregroundColor(Color.nostiaAccent.opacity(0.8))
                    Text("Nothing on the map yet").font(.headline).foregroundColor(.white)
                    Text("Friends who share location and nearby events appear here")
                        .font(.footnote).foregroundColor(Color.nostiaTextSecond)
                        .multilineTextAlignment(.center)
                }
                .padding(24)
                .glassEffect(in: RoundedRectangle(cornerRadius: 20))
                .padding()
                .padding(.bottom, 60)
            }

            // Hint label
            Text("Hold map to create an event")
                .font(.caption)
                .foregroundColor(.white.opacity(0.55))
                .padding(.horizontal, 12).padding(.vertical, 6)
                .glassEffect(in: Capsule())
                .padding(.bottom, 12)
        }
        .task { await loadAll() }
        .sheet(isPresented: $showCreateEvent, onDismiss: {
            if !showCreateEvent { pendingCoordinate = nil }
        }) {
            if let coord = pendingCoordinate {
                CreateEventSheet(coordinate: coord) { newEvent in
                    events.append(newEvent)
                    pendingCoordinate = nil
                }
            }
        }
        .sheet(item: $selectedEvent, onDismiss: { Task { await loadAll() } }) { event in
            EventDetailSheet(event: event, vm: adventuresVM)
        }
    }

    func loadAll() async {
        isLoading = true
        async let locations = FriendsAPI.shared.getLocations()
        async let allEvents = AdventuresAPI.shared.getAllEvents()
        friendLocations = (try? await locations) ?? []
        events = (try? await allEvents) ?? []
        isLoading = false
    }
}

// MARK: - Create Event Sheet

struct CreateEventSheet: View {
    let coordinate: CLLocationCoordinate2D
    let onSave: (Event) -> Void

    @State private var title = ""
    @State private var locationName = ""
    @State private var description = ""
    @State private var eventDate = Date().addingTimeInterval(3600)
    @State private var visibility = "public"
    @State private var isSaving = false
    @State private var errorMessage: String?
    @Environment(\.dismiss) private var dismiss

    let visibilityOptions = ["public", "friends", "private"]

    private var isoFormatter: ISO8601DateFormatter {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // Map preview showing pin location
                    Map(initialPosition: .region(MKCoordinateRegion(
                        center: coordinate,
                        span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                    ))) {
                        Annotation("", coordinate: coordinate) {
                            Image(systemName: "mappin.circle.fill")
                                .font(.system(size: 32))
                                .foregroundColor(Color.nostiaAccent)
                                .shadow(color: Color.nostiaAccent.opacity(0.5), radius: 8)
                        }
                    }
                    .frame(height: 140)
                    .cornerRadius(14)
                    .allowsHitTesting(false)

                    NostiaTextField(label: "Event Title *", placeholder: "What's happening?", text: $title)

                    NostiaTextField(label: "Location Name", placeholder: "e.g. Central Park, Coffee Shop…", text: $locationName)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Date & Time *")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white.opacity(0.7))
                        DatePicker("", selection: $eventDate, displayedComponents: [.date, .hourAndMinute])
                            .datePickerStyle(.compact)
                            .labelsHidden()
                            .padding(12)
                            .glassEffect(in: RoundedRectangle(cornerRadius: 12))
                            .colorScheme(.dark)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Visibility")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white.opacity(0.7))
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
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white.opacity(0.7))
                        TextEditor(text: $description)
                            .frame(minHeight: 72).padding(12)
                            .glassEffect(in: RoundedRectangle(cornerRadius: 12))
                            .foregroundColor(.white).scrollContentBackground(.hidden)
                    }

                    if let err = errorMessage {
                        Text(err).font(.footnote).foregroundColor(Color.nostriaDanger)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(12)
                            .glassEffect(in: RoundedRectangle(cornerRadius: 8))
                    }
                }
                .padding(20)
            }
            .background(.clear)
            .navigationTitle("Create Event")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }.foregroundColor(Color.nostiaTextSecond)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        guard !title.trimmingCharacters(in: .whitespaces).isEmpty else {
                            errorMessage = "Title is required"; return
                        }
                        isSaving = true
                        Task {
                            do {
                                let event = try await AdventuresAPI.shared.createEvent(
                                    title: title.trimmingCharacters(in: .whitespaces),
                                    description: description.isEmpty ? nil : description,
                                    location: locationName.isEmpty ? nil : locationName,
                                    eventDate: isoFormatter.string(from: eventDate),
                                    lat: coordinate.latitude,
                                    lng: coordinate.longitude,
                                    visibility: visibility
                                )
                                onSave(event)
                                dismiss()
                            } catch {
                                errorMessage = error.localizedDescription
                                isSaving = false
                            }
                        }
                    } label: {
                        if isSaving { ProgressView().tint(Color.nostiaAccent) }
                        else { Text("Create").fontWeight(.semibold).foregroundColor(Color.nostiaAccent) }
                    }
                    .disabled(isSaving)
                }
            }
        }
        .presentationBackground(.ultraThinMaterial)
    }
}
