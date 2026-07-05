import SwiftUI
import MapKit

struct FriendsMapView: View {
    @EnvironmentObject private var locationManager: LocationManager
    @State private var friendLocations: [FollowLocation] = []
    @State private var events: [Experience] = []
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
    @State private var selectedEvent: Experience?
    @State private var showEventsList = false   // accessible list alternative (Section 1.4)
    @State private var adventuresVM = ExperienceActionsViewModel()
    @State private var viewportTask: Task<Void, Never>?
    @State private var lastRegion: MKCoordinateRegion?

    // Heatmap (far-out zoom). Filter toggles are session-only @State → reset on app restart.
    @State private var viewportRadiusMiles: Double = 0
    @State private var heatmapCells: [HeatmapCell] = []
    @State private var heatmapCache: [String: [HeatmapCell]] = [:]   // per-filter session cache
    @State private var filterPublic = true
    @State private var filterPrivate = true
    @State private var filterOrgs = true   // org experiences (members-only) shown on the map
    @State private var selectedMapTags: [String] = []   // server-side tag filter (§7)
    @State private var currentUser: User?
    @State private var didCreateExperienceThisSession = false   // local mirror of has_created_experience

    // Place search: type a place/address to recenter the map there.
    @State private var placeCompleter = AddressCompleter()
    @State private var showPlaceResults = false
    @FocusState private var placeSearchFocused: Bool

    // One-time intro: explains the map the first time this device opens it (new users).
    @AppStorage("hasSeenMapIntro") private var hasSeenMapIntro = false

    // Heatmap replaces pins once the viewport zooms out past the 20-mile public-experience radius.
    private var isHeatmapMode: Bool { viewportRadiusMiles > 20 }
    private var filterKey: String { "\(filterPublic)|\(filterPrivate)" }
    // Densest cell currently loaded — used to normalize blob brightness so the gradient
    // spans the full blue→purple range while preserving relative density.
    private var heatmapMaxIntensity: Double { heatmapCells.map(\.intensity).max() ?? 1 }

    // Visibility-pill display filter (D4): Orgs pill shows org experiences (members-only);
    // Public pill shows "public"; Private pill shows "followers" (incl. legacy
    // "friends"/"private"). The org check takes precedence so an org experience is never
    // double-counted by the Public/Private pills. All off → nothing.
    private var visibleExperiences: [Experience] {
        events.filter { exp in
            // Defensive: the server already drops expired experiences, but hide any that
            // lapse while the map is open (or arrive via a stale cache).
            if exp.isExpired { return false }
            if exp.isOrgExperience { return filterOrgs }
            if (exp.visibility ?? "public") == "public" { return filterPublic }
            return filterPrivate
        }
    }

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
                                    .font(.caption.bold())
                                    .foregroundStyle(.nostiaUsername(isDev: friend.isDev == true, fallback: Color.nostiaTextPrimary))
                                    .padding(.horizontal, 8).padding(.vertical, 3)
                                    .nostiaCard(in: Capsule())
                            }
                        }
                    }

                    // Experience pins — hidden at far-out (heatmap) zoom. The two views are
                    // mutually exclusive at any given zoom level (spec §2). Pins are
                    // additionally filtered by the visibility pills (D4).
                    if !isHeatmapMode {
                        ForEach(visibleExperiences) { event in
                            if let lat = event.latitude, let lng = event.longitude {
                                Annotation(event.title, coordinate: CLLocationCoordinate2D(
                                    latitude: lat, longitude: lng
                                ), anchor: .bottom) {
                                    Button { selectedEvent = event } label: {
                                        VStack(spacing: 4) {
                                            ExperienceMapPin(event: event)
                                            Text(event.title)
                                                .font(.caption.bold()).foregroundColor(.white)
                                                .lineLimit(1)
                                                .padding(.horizontal, 10).padding(.vertical, 4)
                                                .background(Capsule().fill(event.isOrgExperience ? Color.nostiaWarning : Color.nostiaAccent))
                                                .shadow(color: (event.isOrgExperience ? Color.nostiaWarning : Color.nostiaAccent).opacity(0.5), radius: 8, y: 3)
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
                                    .accessibilityHidden(true) // decorative (Section 1.4)
                            }
                        }
                    }

                    // Pending pin for new experience (shown while sheet is open)
                    if let coord = pendingCoordinate {
                        Annotation("New Experience", coordinate: coord) {
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
                    lastRegion = region
                    let radius = region.span.latitudeDelta / 2 * 69.0
                    // Crossfade between pin and heatmap views as the 20-mile boundary is crossed.
                    withAnimation(.easeInOut(duration: 0.25)) { viewportRadiusMiles = radius }
                    viewportTask?.cancel()
                    viewportTask = Task {
                        if radius > 20 {
                            await loadHeatmap()
                        } else {
                            await loadExperiencesForRegion(region)
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
                    .nostiaCard(in: RoundedRectangle(cornerRadius: 12))
                    .padding(.bottom, 100)
            }

            // Empty state — permanently suppressed once the user has ever created an experience
            // (spec §6), and never shown over the heatmap at far-out zoom.
            if !isLoading && !isHeatmapMode && currentUser?.hasCreatedExperience != true
                && !didCreateExperienceThisSession
                && friendLocations.isEmpty && events.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "map").font(.system(size: 48)).foregroundColor(Color.nostiaAccent.opacity(0.8))
                    Text("Nothing on the map yet").font(.headline).foregroundColor(Color.nostiaTextPrimary)
                    Text("People you follow who share location appear here")
                        .font(.footnote).foregroundColor(Color.nostiaTextSecond)
                        .multilineTextAlignment(.center)
                }
                .padding(24)
                .nostiaCard(in: RoundedRectangle(cornerRadius: 20))
                .padding()
                .padding(.bottom, 60)
            }

            // Map editor — place search + visibility pills (D2/D4) + tag search (§7). Fixed
            // at the top. Pills filter which pins are visible AND which types feed the heatmap.
            VStack(spacing: 8) {
                placeSearchBar

                HStack(spacing: 8) {
                    FilterChip(title: "Public", isActive: filterPublic) {
                        filterPublic.toggle(); onFiltersChanged()
                    }
                    FilterChip(title: "Private", isActive: filterPrivate) {
                        filterPrivate.toggle(); onFiltersChanged()
                    }
                    // Org experiences aren't part of the heatmap, so toggling this only
                    // shows/hides their pins — no heatmap refresh needed.
                    FilterChip(title: "Orgs", isActive: filterOrgs) {
                        filterOrgs.toggle()
                    }
                }
                .padding(.horizontal, 10).padding(.vertical, 8)
                .nostiaCard(in: Capsule())

                // Tag search bar — narrows the experiences shown on the map (server-side).
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(experienceTags, id: \.self) { tag in
                            FilterChip(title: tag.capitalized, isActive: selectedMapTags.contains(tag)) {
                                toggleMapTag(tag)
                            }
                        }
                    }
                    .padding(.horizontal, 12)
                }
            }
            .padding(.top, 8)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

            // Hint label
            Text("Hold map to create an experience")
                .font(.caption)
                .foregroundColor(Color.nostiaTextSecond)
                .padding(.horizontal, 12).padding(.vertical, 6)
                .nostiaCard(in: Capsule())
                .padding(.bottom, 12)

            // Location-denied notice
            if locationManager.permissionDenied {
                VStack(spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: "location.slash.fill").foregroundColor(Color.nostiaWarning)
                        Text("Location is off").font(.subheadline.bold()).foregroundColor(Color.nostiaTextPrimary)
                    }
                    Text("Enable location in Settings to see nearby experiences and share your location.")
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
                .nostiaCard(in: RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal)
                .padding(.top, 164)   // sit below the search bar + visibility pills + tag search
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
                CreateExperienceSheet(coordinate: coord) { newEvent in
                    events.append(newEvent)
                    didCreateExperienceThisSession = true   // suppress empty state for the rest of the session
                    pendingCoordinate = nil
                }
            }
        }
        .sheet(item: $selectedEvent, onDismiss: { Task { await loadAll() } }) { event in
            ExperienceDetailSheet(event: event, vm: adventuresVM)
        }
        .sheet(isPresented: $showEventsList) {
            NearbyExperiencesListView(events: visibleExperiences)
        }
        .toolbar {
            // Accessible list alternative to the visual map (Section 1.4 "Map alternative").
            ToolbarItem(placement: .topBarLeading) {
                Button { showEventsList = true } label: {
                    Image(systemName: "list.bullet")
                        .foregroundColor(Color.nostiaTextPrimary)
                }
                .accessibilityLabel("Nearby experiences list")
                .accessibilityHint("Shows a list of nearby experiences for screen-reader navigation")
            }
        }
        .overlay {
            if !hasSeenMapIntro {
                MapIntroOverlay {
                    withAnimation(.easeOut(duration: 0.25)) { hasSeenMapIntro = true }
                }
            }
        }
    }

    func loadAll() async {
        isLoading = true
        friendLocations = (try? await FriendsAPI.shared.getLocations()) ?? []
        isLoading = false
    }

    func loadExperiencesForRegion(_ region: MKCoordinateRegion) async {
        let half = region.span
        let minLat = region.center.latitude - half.latitudeDelta / 2
        let maxLat = region.center.latitude + half.latitudeDelta / 2
        let minLng = region.center.longitude - half.longitudeDelta / 2
        let maxLng = region.center.longitude + half.longitudeDelta / 2
        let radiusMiles = half.latitudeDelta / 2 * 69.0
        events = (try? await ExperiencesAPI.shared.getMapExperiences(
            minLat: minLat, maxLat: maxLat, minLng: minLng, maxLng: maxLng,
            viewportRadiusMiles: radiusMiles, tags: selectedMapTags
        )) ?? []
    }

    // Fetch the heatmap grid for the active filters. The grid is platform-wide and
    // normalized, so it isn't viewport-bound — one fetch per filter combo per session.
    // Private pill drives the followers flag; the retired only-me flag is always false.
    func loadHeatmap() async {
        let key = filterKey
        if let cached = heatmapCache[key] {
            withAnimation(.easeInOut(duration: 0.25)) { heatmapCells = cached }
            return
        }
        let cells = (try? await ExperiencesAPI.shared.getHeatmap(
            includePublic: filterPublic,
            includeFollowers: filterPrivate,
            includePrivate: false
        )) ?? []
        heatmapCache[key] = cells
        withAnimation(.easeInOut(duration: 0.25)) { heatmapCells = cells }
    }

    // A visibility pill was toggled: drop the session cache and refresh if showing heatmap.
    // Pin display updates automatically through `visibleExperiences`.
    func onFiltersChanged() {
        heatmapCache.removeAll()
        if isHeatmapMode {
            viewportTask?.cancel()
            viewportTask = Task { await loadHeatmap() }
        }
    }

    // A tag chip was toggled: reload the viewport experiences with the new server-side filter.
    func toggleMapTag(_ tag: String) {
        if let idx = selectedMapTags.firstIndex(of: tag) {
            selectedMapTags.remove(at: idx)
        } else {
            selectedMapTags.append(tag)
        }
        guard !isHeatmapMode, let region = lastRegion else { return }
        viewportTask?.cancel()
        viewportTask = Task { await loadExperiencesForRegion(region) }
    }

    // MARK: - Place search

    /// A text field (with autocomplete suggestions) for jumping the map to any place or
    /// address. Selecting a result recenters the camera; the existing
    /// `onMapCameraChange` handler then reloads experiences/heatmap for the new region.
    private var placeSearchBar: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass").foregroundColor(Color.nostiaTextSecond)
                TextField("Search a place or address", text: $placeCompleter.query)
                    .foregroundColor(Color.nostiaTextPrimary)
                    .autocorrectionDisabled()
                    .focused($placeSearchFocused)
                    .submitLabel(.search)
                    .onChange(of: placeCompleter.query) { _, q in
                        showPlaceResults = !q.isEmpty
                    }
                if !placeCompleter.query.isEmpty {
                    Button {
                        placeCompleter.query = ""
                        showPlaceResults = false
                        placeSearchFocused = false
                    } label: {
                        Image(systemName: "xmark.circle.fill").foregroundColor(Color.nostiaTextMuted)
                    }
                    .accessibilityLabel("Clear search")
                }
            }
            .padding(12)
            .nostiaCard(in: RoundedRectangle(cornerRadius: 12))

            if showPlaceResults && !placeCompleter.results.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(placeCompleter.results.prefix(5), id: \.self) { result in
                        Button {
                            Task { await goToPlace(result) }
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(result.title)
                                    .font(.subheadline).foregroundColor(Color.nostiaTextPrimary)
                                if !result.subtitle.isEmpty {
                                    Text(result.subtitle)
                                        .font(.caption).foregroundColor(Color.nostiaTextSecond)
                                }
                            }
                            .padding(.horizontal, 14).padding(.vertical, 10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .buttonStyle(.plain)
                        Divider().background(Color.nostiaDivider)
                    }
                }
                .nostiaCard(in: RoundedRectangle(cornerRadius: 12))
                .padding(.top, 4)
            }
        }
        .padding(.horizontal, 12)
    }

    @MainActor
    private func goToPlace(_ result: MKLocalSearchCompletion) async {
        guard let coord = await placeCompleter.resolve(result) else { return }
        placeCompleter.query = result.title
        showPlaceResults = false
        placeSearchFocused = false
        withAnimation(.easeInOut(duration: 0.4)) {
            cameraPosition = .region(MKCoordinateRegion(
                center: coord,
                span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
            ))
        }
    }
}

// MARK: - First-time map intro

/// One-time explainer shown over the map the first time this device opens it.
/// Dismissal persists via `@AppStorage("hasSeenMapIntro")` in `FriendsMapView`.
private struct MapIntroOverlay: View {
    let onDismiss: () -> Void

    var body: some View {
        ZStack {
            // Dim + swallow touches so the map underneath can't be poked while the intro is up.
            Color.black.opacity(0.45)
                .ignoresSafeArea()
                .onTapGesture {}

            VStack(spacing: 16) {
                Image(systemName: "map.fill")
                    .font(.system(size: 38))
                    .foregroundColor(Color.nostiaAccent)
                Text("Welcome to the Map")
                    .font(.nostiaDisplay(20, weight: .heavy))
                    .foregroundColor(Color.nostiaTextPrimary)

                VStack(alignment: .leading, spacing: 13) {
                    introRow(icon: "hand.tap.fill",
                             text: "Press and hold anywhere on the map to create an experience there.")
                    introRow(icon: "mappin.circle.fill",
                             text: "Tap a pin to see an experience's details and join in.")
                    introRow(icon: "magnifyingglass",
                             text: "Search any place or address to jump the map there.")
                    introRow(icon: "line.3.horizontal.decrease.circle.fill",
                             text: "Filter what you see with the Public, Private and Orgs pills — plus activity tags.")
                    introRow(icon: "person.2.fill",
                             text: "Friends who share their location appear on the map too.")
                }

                Button(action: onDismiss) {
                    Text("Got It")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.nostiaAccent))
                }
                .buttonStyle(.plain)
            }
            .padding(22)
            .frame(maxWidth: 360)
            .nostiaCard(in: RoundedRectangle(cornerRadius: 20), elevation: .raised)
            .padding(24)
        }
        .transition(.opacity)
    }

    private func introRow(icon: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(Color.nostiaAccent)
                .frame(width: 26)
            Text(text)
                .font(.subheadline)
                .foregroundColor(Color.nostiaTextSecond)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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

// MARK: - Experience Map Pin

struct ExperienceMapPin: View {
    let event: Experience

    // Org experiences → orange (matches the Orgs filter pill); otherwise two-state scheme
    // (D6): public → accent; private (followers/legacy) → purple.
    private var typeColor: Color {
        if event.isOrgExperience { return Color.nostiaWarning }
        return (event.visibility ?? "public") == "public" ? Color.nostiaAccent : Color.nostriaPurple
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
                .fill(event.myStatus == "visited" ? Color.nostiaSuccess : typeColor)
                .frame(width: 40, height: 40)
                .shadow(color: .black.opacity(0.4), radius: 4)
            Image(systemName: defaultPinIcon)
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(.white)
        }
    }

    // Visited → seal; org experience → building; otherwise the default sparkles.
    private var defaultPinIcon: String {
        if event.myStatus == "visited" { return "checkmark.seal.fill" }
        return event.isOrgExperience ? "building.2.fill" : "sparkles"
    }
}

// MARK: - Create Experience Sheet

struct CreateExperienceSheet: View {
    let coordinate: CLLocationCoordinate2D
    let onSave: (Experience) -> Void

    @State private var title = ""
    @State private var locationName = ""
    @State private var description = ""
    @State private var visibility = "public"
    @State private var selectedTags: [String] = []
    @State private var hasSchedule = false
    @State private var scheduledDate = Date().addingTimeInterval(3600)
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var adjustedCoord: CLLocationCoordinate2D?
    @State private var previewPosition: MapCameraPosition
    @Environment(\.dismiss) private var dismiss

    private var activeCoord: CLLocationCoordinate2D { adjustedCoord ?? coordinate }

    init(coordinate: CLLocationCoordinate2D, onSave: @escaping (Experience) -> Void) {
        self.coordinate = coordinate
        self.onSave = onSave
        self._previewPosition = State(initialValue: .region(MKCoordinateRegion(
            center: coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
        )))
    }

    // Public = wire "public"; Private = wire "followers" (D2). Only-me retired.
    let visibilityOptions = ["public", "followers"]

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

                    NostiaTextField(label: "Experience Title *", placeholder: "What's happening?", text: $title)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Location Name")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(Color.nostiaTextSecond)
                        AddressSearchField(locationName: $locationName) { coord, _ in
                            adjustedCoord = coord
                        }
                    }

                    ExperienceTagPicker(selectedTags: $selectedTags)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Visibility")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(Color.nostiaTextSecond)
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
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(Color.nostiaTextSecond)
                        LinkInsertBar(text: $description)
                        TextEditor(text: $description)
                            .frame(minHeight: 72).padding(12)
                            .nostiaCard(in: RoundedRectangle(cornerRadius: 12))
                            .foregroundColor(Color.nostiaTextPrimary).scrollContentBackground(.hidden)
                    }

                    if let err = errorMessage {
                        Text(err).font(.footnote).foregroundColor(Color.nostriaDanger)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(12)
                            .nostiaCard(in: RoundedRectangle(cornerRadius: 8))
                    }
                }
                .padding(20)
            }
            .background(.clear)
            .navigationTitle("Create Experience")
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
                                let event = try await ExperiencesAPI.shared.createExperience(
                                    title: title.trimmingCharacters(in: .whitespaces),
                                    description: description.isEmpty ? nil : description,
                                    location: locationName.isEmpty ? nil : locationName,
                                    lat: activeCoord.latitude,
                                    lng: activeCoord.longitude,
                                    visibility: visibility,
                                    tags: selectedTags,
                                    eventDate: hasSchedule ? Experience.wireDate(from: scheduledDate) : nil
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
        .presentationBackground(Color.nostiaBackground)
    }
}

// MARK: - Experience Tag Picker (§4)

/// Multi-select activity-tag picker built from the shared `experienceTags` constant.
/// Wrapping rows of FilterChips, capped at `maxExperienceTags`.
struct ExperienceTagPicker: View {
    @Binding var selectedTags: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Tags")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(Color.nostiaTextSecond)
            FlowLayout(spacing: 8) {
                ForEach(experienceTags, id: \.self) { tag in
                    FilterChip(title: tag.capitalized, isActive: selectedTags.contains(tag)) {
                        toggle(tag)
                    }
                }
            }
            Text("Add up to \(maxExperienceTags) tags")
                .font(.caption).foregroundColor(Color.nostiaTextMuted)
        }
    }

    private func toggle(_ tag: String) {
        if let idx = selectedTags.firstIndex(of: tag) {
            selectedTags.remove(at: idx)
        } else if selectedTags.count < maxExperienceTags {
            selectedTags.append(tag)
        }
    }
}
