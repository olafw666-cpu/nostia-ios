import SwiftUI
import MapKit
import CoreLocation

struct FriendsMapView: View {
    @State private var friendLocations: [FriendLocation] = []
    @State private var mapEvents: [Event] = []
    @State private var selectedEvent: Event? = nil
    @State private var cameraPosition: MapCameraPosition = .automatic
    @State private var isLoading = false
    @State private var hasCenteredOnUser = false
    @ObservedObject private var locationManager = LocationManager.shared

    var body: some View {
        ZStack {
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
                ForEach(mapEvents) { event in
                    if let lat = event.latitude, let lng = event.longitude {
                        Annotation(event.title, coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lng), anchor: .bottom) {
                            Button { selectedEvent = event } label: {
                                VStack(spacing: 4) {
                                    ZStack {
                                        Circle()
                                            .fill(event.myRsvp == "going" ? Color.nostiaSuccess : Color.nostiaWarning)
                                            .frame(width: 40, height: 40)
                                            .shadow(color: .black.opacity(0.4), radius: 4)
                                        Image(systemName: event.myRsvp == "going" ? "checkmark.calendar" : "calendar")
                                            .font(.system(size: 17, weight: .semibold))
                                            .foregroundColor(.white)
                                    }
                                    Text(event.title)
                                        .font(.caption.bold()).foregroundColor(.white)
                                        .padding(.horizontal, 6).padding(.vertical, 2)
                                        .glassEffect(in: Capsule())
                                        .lineLimit(1)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .ignoresSafeArea(edges: .bottom)
            .onMapCameraChange(frequency: .onEnd) { context in
                Task { await loadEvents(for: context.region) }
            }

            if isLoading {
                ProgressView().tint(Color.nostiaAccent)
                    .padding(16)
                    .glassEffect(in: RoundedRectangle(cornerRadius: 12))
            }

            if !isLoading && friendLocations.isEmpty && mapEvents.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "map").font(.system(size: 48)).foregroundColor(Color.nostiaAccent.opacity(0.8))
                    Text("Nothing on the map yet").font(.headline).foregroundColor(.white)
                    Text("Pan and zoom to discover nearby events")
                        .font(.footnote).foregroundColor(Color.nostiaTextSecond)
                        .multilineTextAlignment(.center)
                }
                .padding(24)
                .glassEffect(in: RoundedRectangle(cornerRadius: 20))
                .padding()
            }
        }
        .task {
            isLoading = true
            await loadLocations()
            if let loc = locationManager.location {
                hasCenteredOnUser = true
                let region = makeRegion(center: loc.coordinate)
                cameraPosition = .region(region)
                await loadEvents(for: region)
            }
            isLoading = false
        }
        .onChange(of: locationManager.location) { _, loc in
            guard let loc, !hasCenteredOnUser else { return }
            hasCenteredOnUser = true
            let region = makeRegion(center: loc.coordinate)
            cameraPosition = .region(region)
            Task { await loadEvents(for: region) }
        }
        .sheet(item: $selectedEvent) { event in
            EventDetailSheet(event: event) { updated in
                if let idx = mapEvents.firstIndex(where: { $0.id == updated.id }) {
                    mapEvents[idx] = updated
                }
            }
        }
    }

    private func makeRegion(center: CLLocationCoordinate2D) -> MKCoordinateRegion {
        MKCoordinateRegion(
            center: center,
            latitudinalMeters: 20 * 1609.34 * 2,
            longitudinalMeters: 20 * 1609.34 * 2
        )
    }

    private func loadLocations() async {
        if let locations = try? await FriendsAPI.shared.getLocations() {
            friendLocations = locations
        }
    }

    private func loadEvents(for region: MKCoordinateRegion) async {
        let span = region.span
        let center = region.center
        let minLat = center.latitude - span.latitudeDelta / 2
        let maxLat = center.latitude + span.latitudeDelta / 2
        let minLng = center.longitude - span.longitudeDelta / 2
        let maxLng = center.longitude + span.longitudeDelta / 2
        let viewportRadiusMiles = span.latitudeDelta / 2.0 * 69.0
        mapEvents = (try? await AdventuresAPI.shared.getMapEvents(
            minLat: minLat, maxLat: maxLat,
            minLng: minLng, maxLng: maxLng,
            viewportRadiusMiles: viewportRadiusMiles
        )) ?? []
    }
}

struct EventDetailSheet: View {
    @State private var event: Event
    @State private var isSubmitting = false
    let onUpdated: (Event) -> Void

    init(event: Event, onUpdated: @escaping (Event) -> Void) {
        self._event = State(initialValue: event)
        self.onUpdated = onUpdated
    }

    private var isGoing: Bool { event.myRsvp == "going" }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(event.title)
                        .font(.title2.bold()).foregroundColor(.white)

                    if let loc = event.location {
                        Label(loc, systemImage: "location")
                            .font(.subheadline).foregroundColor(Color.nostiaTextSecond)
                    }

                    Label(event.formattedDate, systemImage: "calendar")
                        .font(.subheadline.bold()).foregroundColor(Color.nostiaWarning)

                    HStack(spacing: 6) {
                        Image(systemName: "person.2.fill").foregroundColor(Color.nostiaAccent)
                        Text("\(event.goingCount ?? 0) going").foregroundColor(Color.nostiaTextSecond)
                    }
                    .font(.subheadline)

                    if let desc = event.description, !desc.isEmpty {
                        Divider().background(Color.nostriaBorder)
                        Text(desc).font(.body).foregroundColor(Color.nostiaTextSecond)
                    }

                    Divider().background(Color.nostriaBorder)

                    Button {
                        guard !isSubmitting else { return }
                        isSubmitting = true
                        let newStatus = isGoing ? "not_going" : "going"
                        Task {
                            if let updated = try? await AdventuresAPI.shared.rsvp(eventId: event.id, status: newStatus) {
                                event = updated
                                onUpdated(updated)
                            }
                            isSubmitting = false
                        }
                    } label: {
                        HStack(spacing: 8) {
                            if isSubmitting {
                                ProgressView().tint(.white)
                            } else {
                                Image(systemName: isGoing ? "xmark.circle" : "checkmark.circle.fill")
                                Text(isGoing ? "Remove Going" : "Mark as Going")
                                    .fontWeight(.semibold)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(14)
                        .background(isGoing ? Color.nostriaDanger : Color.nostiaAccent)
                        .foregroundColor(.white)
                        .cornerRadius(14)
                    }
                    .disabled(isSubmitting)
                }
                .padding(20)
            }
            .background(.clear)
            .navigationTitle("Event Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
        }
        .presentationBackground(.ultraThinMaterial)
        .presentationDetents([.medium, .large])
    }
}
