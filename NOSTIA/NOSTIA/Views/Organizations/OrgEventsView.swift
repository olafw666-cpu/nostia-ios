import SwiftUI
import MapKit
import CoreLocation

// Org-only events (Section 8). Members-only list; reuses ExperienceDetailSheet for viewing,
// RSVP and chat. Org events are excluded from the public map/heatmap server-side.
struct OrgEventsView: View {
    let org: Organization

    @State private var events: [Experience] = []
    @State private var isLoading = true
    @State private var showCreate = false
    @State private var selectedEvent: Experience?
    @State private var eventActionsVM = ExperienceActionsViewModel()

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 14) {
                if org.canPost {
                    Button { showCreate = true } label: {
                        Label("New Experience", systemImage: "plus.circle.fill")
                            .font(.subheadline.bold()).foregroundColor(Color.nostiaAccent)
                            .frame(maxWidth: .infinity).padding(.vertical, 12)
                            .nostiaButton(in: RoundedRectangle(cornerRadius: 14))
                    }
                }

                if isLoading && events.isEmpty {
                    ProgressView().tint(Color.nostiaAccent).padding()
                } else if events.isEmpty {
                    EmptyStateView(icon: "sparkles",
                                   text: "No experiences yet",
                                   sub: org.canPost ? "Create the first org experience" : "Check back later")
                } else {
                    ForEach(events) { event in
                        Button { selectedEvent = event } label: { ExperiencePreviewCard(event: event) }
                            .buttonStyle(.nostiaTap)
                    }
                }
            }
            .padding(16)
        }
        .background(.clear)
        .task { await load() }
        .sheet(isPresented: $showCreate) {
            CreateOrgEventSheet(orgId: org.id) { Task { await load() } }
        }
        .sheet(item: $selectedEvent, onDismiss: { Task { await load() } }) { event in
            ExperienceDetailSheet(event: event, vm: eventActionsVM)
        }
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        events = (try? await OrganizationsAPI.shared.getEvents(id: org.id)) ?? []
    }
}

// MARK: - Create org event

struct CreateOrgEventSheet: View {
    let orgId: Int
    var onCreated: () -> Void

    @EnvironmentObject private var locationManager: LocationManager
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var locationName = ""
    @State private var description = ""
    @State private var eventDate = Date().addingTimeInterval(3600)
    @State private var coordinate: CLLocationCoordinate2D?
    @State private var previewPosition: MapCameraPosition = .region(MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
    ))
    @State private var isSaving = false
    @State private var errorMessage: String?

    private var isoFormatter: ISO8601DateFormatter {
        let f = ISO8601DateFormatter(); f.formatOptions = [.withInternetDateTime]; return f
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    if let coordinate {
                        Map(position: $previewPosition) {
                            Annotation("", coordinate: coordinate) {
                                Image(systemName: "mappin.circle.fill")
                                    .font(.nostiaBody(30)).foregroundColor(Color.nostiaAccent)
                            }
                        }
                        .frame(height: 140).cornerRadius(14).allowsHitTesting(false)
                    }

                    NostiaTextField(label: "Experience Title *", placeholder: "What's happening?", text: $title)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Location *").font(.nostiaBody(14, weight: .semibold)).foregroundColor(Color.nostiaTextSecond)
                        AddressSearchField(locationName: $locationName) { coord, _ in
                            coordinate = coord
                            previewPosition = .region(MKCoordinateRegion(
                                center: coord, span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)))
                        }
                        if coordinate == nil {
                            Text("Search an address to place the experience")
                                .font(.caption).foregroundColor(Color.nostiaTextMuted)
                        }
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Date & Time *").font(.nostiaBody(14, weight: .semibold)).foregroundColor(Color.nostiaTextSecond)
                        DatePicker("", selection: $eventDate, displayedComponents: [.date, .hourAndMinute])
                            .datePickerStyle(.compact).labelsHidden().padding(12)
                            .nostiaCard(in: RoundedRectangle(cornerRadius: 12))
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Description").font(.nostiaBody(14, weight: .semibold)).foregroundColor(Color.nostiaTextSecond)
                        TextEditor(text: $description)
                            .frame(minHeight: 72).padding(12)
                            .nostiaCard(in: RoundedRectangle(cornerRadius: 12))
                            .foregroundColor(Color.nostiaTextPrimary).scrollContentBackground(.hidden)
                    }

                    if let errorMessage {
                        Text(errorMessage).font(.footnote).foregroundColor(Color.nostriaDanger)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(20)
            }
            .background(.clear)
            .navigationTitle("New Org Experience")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }.foregroundColor(Color.nostiaTextSecond)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { Task { await create() } } label: {
                        if isSaving { ProgressView().tint(Color.nostiaAccent) }
                        else { Text("Create").fontWeight(.semibold).foregroundColor(Color.nostiaAccent) }
                    }
                    .disabled(isSaving)
                }
            }
            .task {
                if coordinate == nil, let loc = locationManager.location {
                    coordinate = loc.coordinate
                    previewPosition = .region(MKCoordinateRegion(
                        center: loc.coordinate, span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)))
                }
            }
        }
        .presentationBackground(Color.nostiaBackground)
    }

    private func create() async {
        guard !title.trimmingCharacters(in: .whitespaces).isEmpty else {
            errorMessage = "Title is required"; return
        }
        guard let coordinate else { errorMessage = "A location is required"; return }
        isSaving = true
        defer { isSaving = false }
        do {
            _ = try await OrganizationsAPI.shared.createEvent(
                id: orgId,
                title: title.trimmingCharacters(in: .whitespaces),
                description: description.isEmpty ? nil : description,
                location: locationName.isEmpty ? nil : locationName,
                eventDate: isoFormatter.string(from: eventDate),
                latitude: coordinate.latitude,
                longitude: coordinate.longitude,
                flyerImage: nil
            )
            Haptics.success()
            onCreated()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
