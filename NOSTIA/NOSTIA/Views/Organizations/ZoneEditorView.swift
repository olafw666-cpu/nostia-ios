import SwiftUI
import MapKit
import CoreLocation

// Verification zone editor (Section 3.1). World map with Radius (default) and Freehand
// modes. Multiple zones are OR-combined. Edits the bound zone set in place; the parent
// is responsible for persisting (create flow or settings save).
struct ZoneEditorView: View {
    @Binding var zones: [ZoneDraft]
    var onDone: (() -> Void)? = nil

    @EnvironmentObject private var locationManager: LocationManager
    @Environment(\.dismiss) private var dismiss

    @State private var mode: String = "radius"        // "radius" | "freehand"
    @State private var cameraPosition: MapCameraPosition = .region(MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 20, longitude: 0),
        span: MKCoordinateSpan(latitudeDelta: 120, longitudeDelta: 120)
    ))

    // Radius draft
    @State private var draftCenter: CLLocationCoordinate2D?
    @State private var draftRadius: Double = 500       // metres

    // Freehand draft
    @State private var isDrawing = false
    @State private var freehandPoints: [CLLocationCoordinate2D] = []

    private var isRadius: Bool { mode == "radius" }

    var body: some View {
        ZStack(alignment: .bottom) {
            MapReader { proxy in
                ZStack {
                    Map(position: $cameraPosition) {
                        UserAnnotation()

                        // Committed zones
                        ForEach(Array(zones.enumerated()), id: \.offset) { _, zone in
                            zoneOverlay(zone)
                        }

                        // Radius draft preview
                        if isRadius, let center = draftCenter {
                            MapCircle(center: center, radius: draftRadius)
                                .foregroundStyle(Color.nostiaAccent.opacity(0.25))
                                .stroke(Color.nostiaAccent, lineWidth: 2)
                            Annotation("", coordinate: center) {
                                Image(systemName: "scope")
                                    .font(.title2).foregroundColor(Color.nostiaAccent)
                                    .shadow(radius: 4)
                            }
                        }

                        // Freehand draft preview
                        if !isRadius, freehandPoints.count >= 2 {
                            MapPolygon(coordinates: freehandPoints)
                                .foregroundStyle(Color.nostriaPurple.opacity(0.25))
                                .stroke(Color.nostriaPurple, lineWidth: 2)
                        }
                    }

                    // Freehand draw capture layer — only hittable while drawing so the map
                    // pans normally the rest of the time.
                    if !isRadius && isDrawing {
                        Color.white.opacity(0.001)
                            .contentShape(Rectangle())
                            .gesture(
                                DragGesture(minimumDistance: 0, coordinateSpace: .local)
                                    .onChanged { value in
                                        if let coord = proxy.convert(value.location, from: .local) {
                                            freehandPoints.append(coord)
                                        }
                                    }
                                    .onEnded { _ in isDrawing = false }
                            )
                    }
                }
                // Radius mode: tap to drop / move the centre.
                .onTapGesture(coordinateSpace: .local) { point in
                    guard isRadius, let coord = proxy.convert(point, from: .local) else { return }
                    draftCenter = coord
                    Haptics.tap()
                }
            }
            .ignoresSafeArea(edges: .bottom)

            controls
        }
        .navigationTitle("Verification Zones")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") { onDone?(); dismiss() }
                    .fontWeight(.semibold)
                    .foregroundColor(Color.nostiaAccent)
            }
        }
        .task {
            if let loc = locationManager.location {
                cameraPosition = .region(MKCoordinateRegion(
                    center: loc.coordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
                ))
            }
        }
    }

    @MapContentBuilder
    private func zoneOverlay(_ zone: ZoneDraft) -> some MapContent {
        if zone.type == "radius", let lat = zone.centerLat, let lng = zone.centerLng, let r = zone.radius {
            MapCircle(center: CLLocationCoordinate2D(latitude: lat, longitude: lng), radius: r)
                .foregroundStyle(Color.nostiaAccent.opacity(0.18))
                .stroke(Color.nostiaAccent.opacity(0.9), lineWidth: 2)
        } else if zone.type == "freehand", let poly = zone.polygon, poly.count >= 3 {
            MapPolygon(coordinates: poly.map { CLLocationCoordinate2D(latitude: $0.lat, longitude: $0.lng) })
                .foregroundStyle(Color.nostriaPurple.opacity(0.18))
                .stroke(Color.nostriaPurple.opacity(0.9), lineWidth: 2)
        }
    }

    private var controls: some View {
        VStack(spacing: 12) {
            // Mode toggle (Section 3.1 "Zone mode toggle")
            Picker("Mode", selection: $mode) {
                Text("Radius").tag("radius")
                Text("Freehand").tag("freehand")
            }
            .pickerStyle(.segmented)
            .onChange(of: mode) { _, _ in resetDrafts() }

            if isRadius {
                radiusControls
            } else {
                freehandControls
            }

            if !zones.isEmpty {
                HStack {
                    Text("\(zones.count) zone\(zones.count == 1 ? "" : "s") · joiners verified inside ANY")
                        .font(.caption).foregroundColor(Color.nostiaTextSecond)
                    Spacer()
                    Button(role: .destructive) { zones.removeAll() } label: {
                        Text("Clear all").font(.caption.bold())
                    }
                }
            }
        }
        .padding(16)
        .nostiaCard(in: RoundedRectangle(cornerRadius: 20))
        .padding(12)
    }

    @ViewBuilder
    private var radiusControls: some View {
        VStack(spacing: 10) {
            Text(draftCenter == nil ? "Tap the map to set a centre" : "Adjust the radius, then add the zone")
                .font(.caption).foregroundColor(Color.nostiaTextMuted)
                .frame(maxWidth: .infinity, alignment: .leading)

            if draftCenter != nil {
                HStack {
                    Image(systemName: "circle.dashed").foregroundColor(Color.nostiaAccent)
                    Slider(value: $draftRadius, in: 50...20000, step: 50)
                        .tint(Color.nostiaAccent)
                    Text(radiusLabel(draftRadius))
                        .font(.caption.bold()).foregroundColor(.white)
                        .frame(width: 64, alignment: .trailing)
                }
            }

            Button {
                commitRadius()
            } label: {
                Label("Add zone", systemImage: "plus.circle.fill")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(draftCenter == nil ? AnyShapeStyle(Color(hex: "C2CAD3"))
                                                   : AnyShapeStyle(Color.nostiaAccent))
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
            .disabled(draftCenter == nil)
        }
    }

    @ViewBuilder
    private var freehandControls: some View {
        VStack(spacing: 10) {
            Text(freehandPoints.count >= 3
                 ? "Shape ready — add it, or redraw"
                 : "Tap Draw, then trace a shape on the map with one finger")
                .font(.caption).foregroundColor(Color.nostiaTextMuted)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 10) {
                Button {
                    freehandPoints = []
                    isDrawing = true
                    Haptics.tap()
                } label: {
                    Label(isDrawing ? "Drawing…" : "Draw", systemImage: "scribble")
                        .frame(maxWidth: .infinity).padding(.vertical, 10)
                        .background(isDrawing ? Color.nostriaPurple : Color.nostiaInput)
                        .foregroundColor(.white).cornerRadius(12)
                }
                Button {
                    commitFreehand()
                } label: {
                    Label("Add zone", systemImage: "plus.circle.fill")
                        .frame(maxWidth: .infinity).padding(.vertical, 10)
                        .background(freehandPoints.count >= 3 ? AnyShapeStyle(Color.nostiaAccent)
                                                              : AnyShapeStyle(Color.nostiaInput))
                        .foregroundColor(.white).cornerRadius(12)
                }
                .disabled(freehandPoints.count < 3)
            }
        }
    }

    // MARK: - Helpers

    private func radiusLabel(_ m: Double) -> String {
        m < 1000 ? "\(Int(m)) m" : String(format: "%.1f km", m / 1000)
    }

    private func resetDrafts() {
        draftCenter = nil
        freehandPoints = []
        isDrawing = false
    }

    private func commitRadius() {
        guard let c = draftCenter else { return }
        zones.append(ZoneDraft(type: "radius", centerLat: c.latitude, centerLng: c.longitude,
                               radius: draftRadius, polygon: nil))
        draftCenter = nil
        Haptics.success()
    }

    private func commitFreehand() {
        guard freehandPoints.count >= 3 else { return }
        let poly = freehandPoints.map { OrgZonePoint(lat: $0.latitude, lng: $0.longitude) }
        zones.append(ZoneDraft(type: "freehand", centerLat: nil, centerLng: nil, radius: nil, polygon: poly))
        freehandPoints = []
        Haptics.success()
    }
}
