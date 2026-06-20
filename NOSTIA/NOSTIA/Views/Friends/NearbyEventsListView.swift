import SwiftUI

/// Accessible, VoiceOver-navigable alternative to the visual map (spec Section 1.4
/// "Map alternative"). Lists nearby events with name, type, date, and distance so
/// screen-reader users get the same information the map conveys visually.
struct NearbyEventsListView: View {
    let events: [Event]
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var responsive: ResponsiveLayoutManager

    var body: some View {
        NavigationStack {
            Group {
                if events.isEmpty {
                    ContentUnavailableView(
                        "No nearby events",
                        systemImage: "calendar",
                        description: Text("Events near the area shown on the map will appear here.")
                    )
                } else {
                    List(events) { event in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(event.title)
                                .font(.headline).foregroundColor(.white)
                            HStack(spacing: 10) {
                                Label(event.formattedDate, systemImage: "clock")
                                if let dist = event.formattedDistance {
                                    Label(dist, systemImage: "location")
                                }
                            }
                            .font(.caption).foregroundColor(Color.nostiaTextSecond)
                            HStack(spacing: 10) {
                                if let type = event.visibility {
                                    Text("\(type.capitalized) event")
                                }
                                if let going = event.goingCount, going > 0 {
                                    Text("\(going) going")
                                }
                            }
                            .font(.caption2).foregroundColor(Color.nostiaTextMuted)
                        }
                        .padding(.vertical, 4)
                        .listRowBackground(Color.clear)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(accessibilityLabel(for: event))
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
            .navigationTitle("Nearby Events")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }.foregroundColor(Color.nostiaAccent)
                }
            }
        }
        .presentationBackground(.ultraThinMaterial)
    }

    private func accessibilityLabel(for e: Event) -> String {
        var parts = [e.title]
        if let type = e.visibility { parts.append("\(type) event") }
        parts.append(e.formattedDate)
        if let dist = e.formattedDistance { parts.append("\(dist) away") }
        if let going = e.goingCount, going > 0 { parts.append("\(going) going") }
        return parts.joined(separator: ", ")
    }
}
