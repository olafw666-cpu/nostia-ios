import SwiftUI
import MapKit

struct FriendsMapView: View {
    @EnvironmentObject private var locationManager: LocationManager
    @State private var friendLocations: [FollowLocation] = []
    @State private var events: [Event] = []
    @State private var isLoading = false
    @State private var cameraPosition = MapCameraPosition.userLocation(
        followsHeading: false,
        fallback: .region(MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
            span: MKCoordinateSpan(latitudeDelta: 0.6, longitudeDelta: 0.6)
        ))
    )
    @State private var pendingCoordinate: CLLocationCoordinate2D?
    @State private var showCreateEvent = false
    @State private var selectedEvent: Event?
    @State private var adventuresVM = EventActionsViewModel()
    @State private var viewportTask: Task<Void, Never>?

    // Heatmap (far-out zoom). Filter toggles are session-only @State → reset on app restart.
    @State private var viewportRadiusMiles: Double = 0
    @State private var heatmapCells: [HeatmapCell] = []
    @State private var heatmapCache: [String: [HeatmapCell]] = [:]   // per-filter session cache
    @State private var filterPublic = true
    @State private var filterFollowers = false
    @State private var filterPrivate = false
    @State private var currentUser: User?
    @State private var didCreateEventThisSession = false   // local mirror of has_created_event

    // Heatmap replaces pins once the viewport zooms out past the 20-mile public-event radius.
    private var isHeatmapMode: Bool { viewportRadiusMiles > 20 }
    private var filterKey: String { "\(filterPublic)|\(filterFollowers)|\(filterPrivate)" }
    // Densest cell currently loaded — used to normalize blob brightness so the gradient
    // spans the full blue→purple range while preserving relative density.
    private var heatmapMaxIntensity: Double { heatmapCells.map(\.intensity).max() ?? 1 }

    var body: some View {
        ZStack(alignment: .bottom) {
            MapReader { proxy in
                Map(position: $cameraPosition) {
                    UserAnnotation()

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

                    // Event pins — hidden at far-out (heatmap) zoom. The two views are
                    // mutually exclusive at any given zoom level (spec §2).
                    if !isHeatmapMode {
                        ForEach(events) { event in
                            if let lat = event.latitude, let lng = event.longitude {
                                Annotation(event.title, coordinate: CLLocationCoordinate2D(
                                    latitude: lat, longitude: lng
                                ), anchor: .bottom) {
                                    Button { selectedEvent = event } label: {
                                        VStack(spacing: 4) {
                                            EventMapPin(event: event)
                                            Text(event.title)
                                                .font(.caption.bold()).foregroundColor(.white)
                                                .lineLimit(1)
                                                .padding(.horizontal, 6).padding(.vertical, 2)
                                                .glassEffect(in: Capsule())
                                        }
                                    }
                                    .buttonStyle(.plain)
                                    .transition(.opacity)
                                }
                            }
                        }
                    }

                    // Heatmap density blobs — shown only at far-out zoom.
                    if isHeatmapMode {
                        ForEach(heatmapCells) { cell in
                            Annotation("", coordinate: CLLocationCoordinate2D(
                                latitude: cell.lat, longitude: cell.lng
                            )) {
                                HeatBlob(intensity: heatmapMaxIntensity > 0 ? cell.intensity / heatmapMaxIntensity : 0)
                                    .transition(.opacity)
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
                .onMapCameraChange(frequency: .onEnd) { context in
                    let region = context.region
                    let radius = region.span.latitudeDelta / 2 * 69.0
                    // Crossfade between pin and heatmap views as the 20-mile boundary is crossed.
                    withAnimation(.easeInOut(duration: 0.25)) { viewportRadiusMiles = radius }
                    viewportTask?.cancel()
                    viewportTask = Task {
                        if radius > 20 {
                            await loadHeatmap()
                        } else {
                            await loadEventsForRegion(region)
                        }
                    }
                }
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

            // Empty state — permanently suppressed once the user has ever created an event
            // (spec §6), and never shown over the heatmap at far-out zoom.
            if !isLoading && !isHeatmapMode && currentUser?.hasCreatedEvent != true
                && !didCreateEventThisSession
                && friendLocations.isEmpty && events.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "map").font(.system(size: 48)).foregroundColor(Color.nostiaAccent.opacity(0.8))
                    Text("Nothing on the map yet").font(.headline).foregroundColor(.white)
                    Text("People you follow who share location appear here")
                        .font(.footnote).foregroundColor(Color.nostiaTextSecond)
                        .multilineTextAlignment(.center)
                }
                .padding(24)
                .glassEffect(in: RoundedRectangle(cornerRadius: 20))
                .padding()
                .padding(.bottom, 60)
            }

            // Map editor — heatmap filter pills (spec §5). Fixed at the top, always visible.
            // Controls which event types feed the heatmap; does NOT affect pin visibility.
            HStack(spacing: 8) {
                FilterChip(title: "Public", isActive: filterPublic) {
                    filterPublic.toggle(); onFiltersChanged()
                }
                FilterChip(title: "Followers", isActive: filterFollowers) {
                    filterFollowers.toggle(); onFiltersChanged()
                }
                FilterChip(title: "Private", isActive: filterPrivate) {
                    filterPrivate.toggle(); onFiltersChanged()
                }
            }
            .padding(.horizontal, 10).padding(.vertical, 8)
            .glassEffect(in: Capsule())
            .padding(.top, 8)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

            // Hint label
            Text("Hold map to create an event")
                .font(.caption)
                .foregroundColor(.white.opacity(0.55))
                .padding(.horizontal, 12).padding(.vertical, 6)
                .glassEffect(in: Capsule())
                .padding(.bottom, 12)

            // Location-denied notice
            if locationManager.permissionDenied {
                VStack(spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: "location.slash.fill").foregroundColor(Color.nostiaWarning)
                        Text("Location is off").font(.subheadline.bold()).foregroundColor(.white)
                    }
                    Text("Enable location in Settings to see nearby events and share your location.")
                        .font(.caption).foregroundColor(Color.nostiaTextSecond)
                        .multilineTextAlignment(.center)
                    Button {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    } label: {
                        Text("Open Settings")
                            .font(.subheadline.bold()).foregroundColor(.white)
                            .padding(.horizontal, 16).padding(.vertical, 8)
                            .background(
                                LinearGradient(colors: [Color.nostiaAccent, Color.nostriaPurple],
                                               startPoint: .leading, endPoint: .trailing)
                            )
                            .cornerRadius(12)
                    }
                }
                .padding(16)
                .glassEffect(in: RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal)
                .padding(.top, 56)   // sit below the heatmap filter pills
                .frame(maxHeight: .infinity, alignment: .top)
            }
        }
        .task {
            await loadAll()
            currentUser = try? await AuthAPI.shared.getMe()
            if let loc = locationManager.location {
                cameraPosition = .region(MKCoordinateRegion(
                    center: loc.coordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.2, longitudeDelta: 0.2)
                ))
            }
        }
        .sheet(isPresented: $showCreateEvent, onDismiss: {
            if !showCreateEvent { pendingCoordinate = nil }
        }) {
            if let coord = pendingCoordinate {
                CreateEventSheet(coordinate: coord) { newEvent in
                    events.append(newEvent)
                    didCreateEventThisSession = true   // suppress empty state for the rest of the session
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
        friendLocations = (try? await FriendsAPI.shared.getLocations()) ?? []
        isLoading = false
    }

    func loadEventsForRegion(_ region: MKCoordinateRegion) async {
        let half = region.span
        let minLat = region.center.latitude - half.latitudeDelta / 2
        let maxLat = region.center.latitude + half.latitudeDelta / 2
        let minLng = region.center.longitude - half.longitudeDelta / 2
        let maxLng = region.center.longitude + half.longitudeDelta / 2
        let radiusMiles = half.latitudeDelta / 2 * 69.0
        events = (try? await AdventuresAPI.shared.getMapEvents(
            minLat: minLat, maxLat: maxLat, minLng: minLng, maxLng: maxLng,
            viewportRadiusMiles: radiusMiles
        )) ?? []
    }

    // Fetch the heatmap grid for the active filters. The grid is platform-wide and
    // normalized, so it isn't viewport-bound — one fetch per filter combo per session.
    func loadHeatmap() async {
        let key = filterKey
        if let cached = heatmapCache[key] {
            withAnimation(.easeInOut(duration: 0.25)) { heatmapCells = cached }
            return
        }
        let cells = (try? await AdventuresAPI.shared.getHeatmap(
            includePublic: filterPublic,
            includeFollowers: filterFollowers,
            includePrivate: filterPrivate
        )) ?? []
        heatmapCache[key] = cells
        withAnimation(.easeInOut(duration: 0.25)) { heatmapCells = cells }
    }

    // A heatmap filter was toggled: drop the session cache and refresh if showing heatmap.
    func onFiltersChanged() {
        heatmapCache.removeAll()
        if isHeatmapMode {
            viewportTask?.cancel()
            viewportTask = Task { await loadHeatmap() }
        }
    }
}

// MARK: - Heatmap Blob

/// A single soft heatmap hotspot: a blurred radial blue→purple gradient whose color and
/// size scale with the (display-normalized) intensity. Continuous gradient — no bands.
struct HeatBlob: View {
    let intensity: Double   // 0...1, normalized to the densest cell currently on screen

    var body: some View {
        let color = HeatBlob.heatColor(intensity)
        let size = 60.0 + 80.0 * intensity
        Circle()
            .fill(RadialGradient(
                colors: [color.opacity(0.85), color.opacity(0.0)],
                center: .center, startRadius: 0, endRadius: size / 2))
            .frame(width: size, height: size)
            .blur(radius: 18)
            .allowsHitTesting(false)
    }

    // Blue → purple ramp tuned to Nostia's dark palette (spec §4 reference hexes).
    static func heatColor(_ t: Double) -> Color {
        let stops: [(Double, UIColor)] = [
            (0.0,  UIColor(red: 0.04, green: 0.04, blue: 0.18, alpha: 1)),  // #0A0A2E navy
            (0.4,  UIColor(red: 0.12, green: 0.23, blue: 0.54, alpha: 1)),  // #1E3A8A blue
            (0.7,  UIColor(red: 0.43, green: 0.16, blue: 0.85, alpha: 1)),  // #6D28D9 violet
            (1.0,  UIColor(red: 0.66, green: 0.33, blue: 0.92, alpha: 1)),  // #A855F7 purple
        ]
        let clamped = min(max(t, 0), 1)
        var lo = stops[0], hi = stops[stops.count - 1]
        for i in 0..<(stops.count - 1) where clamped >= stops[i].0 && clamped <= stops[i + 1].0 {
            lo = stops[i]; hi = stops[i + 1]; break
        }
        let span = hi.0 - lo.0
        let f = CGFloat(span > 0 ? (clamped - lo.0) / span : 0)
        var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
        var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0
        lo.1.getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
        hi.1.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
        return Color(
            red: Double(r1 + (r2 - r1) * f),
            green: Double(g1 + (g2 - g1) * f),
            blue: Double(b1 + (b2 - b1) * f))
    }
}

// MARK: - Event Map Pin

struct EventMapPin: View {
    let event: Event

    private var typeColor: Color {
        switch event.visibility {
        case "private": return Color.nostriaDanger
        case "friends", "followers": return Color.nostriaPurple
        default: return Color.nostiaAccent
        }
    }

    var body: some View {
        ZStack {
            if let flyerString = event.flyerImage, !flyerString.isEmpty {
                flyerPinView(flyerString: flyerString)
            } else {
                defaultPin
            }
        }
    }

    private func decodeFlyer(_ str: String) -> UIImage? {
        if str.hasPrefix("data:image"),
           let base64 = str.components(separatedBy: "base64,").last,
           let data = Data(base64Encoded: base64, options: .ignoreUnknownCharacters) {
            return UIImage(data: data)
        }
        if let data = Data(base64Encoded: str, options: .ignoreUnknownCharacters) {
            return UIImage(data: data)
        }
        return nil
    }

    @ViewBuilder
    private func flyerPinView(flyerString: String) -> some View {
        if let uiImg = decodeFlyer(flyerString) {
            Image(uiImage: uiImg)
                .resizable().scaledToFill()
                .frame(width: 40, height: 40)
                .clipShape(Circle())
                .overlay(Circle().stroke(typeColor, lineWidth: 2.5))
                .shadow(color: .black.opacity(0.4), radius: 4)
        } else if flyerString.hasPrefix("http"), let url = URL(string: flyerString) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let img):
                    img.resizable().scaledToFill()
                        .frame(width: 40, height: 40)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(typeColor, lineWidth: 2.5))
                        .shadow(color: .black.opacity(0.4), radius: 4)
                default:
                    defaultPin
                }
            }
            .frame(width: 40, height: 40)
        } else {
            defaultPin
        }
    }

    private var defaultPin: some View {
        ZStack {
            Circle()
                .fill(event.myRsvp == "going" ? Color.nostiaSuccess : Color.nostiaWarning)
                .frame(width: 40, height: 40)
                .shadow(color: .black.opacity(0.4), radius: 4)
            Image(systemName: event.myRsvp == "going" ? "checkmark.calendar" : "calendar")
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(.white)
        }
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
    @State private var adjustedCoord: CLLocationCoordinate2D?
    @State private var previewPosition: MapCameraPosition
    @Environment(\.dismiss) private var dismiss

    private var activeCoord: CLLocationCoordinate2D { adjustedCoord ?? coordinate }

    init(coordinate: CLLocationCoordinate2D, onSave: @escaping (Event) -> Void) {
        self.coordinate = coordinate
        self.onSave = onSave
        self._previewPosition = State(initialValue: .region(MKCoordinateRegion(
            center: coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
        )))
    }

    let visibilityOptions = ["public", "followers", "private"]

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
                    Map(position: $previewPosition) {
                        Annotation("", coordinate: activeCoord) {
                            Image(systemName: "mappin.circle.fill")
                                .font(.system(size: 32))
                                .foregroundColor(Color.nostiaAccent)
                                .shadow(color: Color.nostiaAccent.opacity(0.5), radius: 8)
                        }
                    }
                    .frame(height: 140)
                    .cornerRadius(14)
                    .allowsHitTesting(false)
                    .onChange(of: adjustedCoord?.latitude) { _, _ in
                        guard let coord = adjustedCoord else { return }
                        previewPosition = .region(MKCoordinateRegion(
                            center: coord,
                            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                        ))
                    }

                    NostiaTextField(label: "Event Title *", placeholder: "What's happening?", text: $title)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Location Name")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white.opacity(0.7))
                        AddressSearchField(locationName: $locationName) { coord, _ in
                            adjustedCoord = coord
                        }
                    }

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
                             visibility == "followers" ? "Only your followers" : "Only you")
                            .font(.caption).foregroundColor(Color.nostiaTextMuted)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Description")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white.opacity(0.7))
                        LinkInsertBar(text: $description)
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
                                    lat: activeCoord.latitude,
                                    lng: activeCoord.longitude,
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
