import SwiftUI

/// Accessible, VoiceOver-navigable alternative to the visual map (spec Section 1.4
/// "Map alternative"). Lists nearby experiences with name, type, and distance so
/// screen-reader users get the same information the map conveys visually.
struct NearbyExperiencesListView: View {
    let events: [Experience]
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var responsive: ResponsiveLayoutManager

    var body: some View {
        NavigationStack {
            Group {
                if events.isEmpty {
                    ContentUnavailableView(
                        "No nearby experiences",
                        systemImage: "sparkles",
                        description: Text("Experiences near the area shown on the map will appear here.")
                    )
                } else {
                    List(events) { event in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(event.title)
                                .font(.headline).foregroundColor(Color.nostiaTextPrimary)
                            if let dist = event.formattedDistance {
                                Label(dist, systemImage: "location")
                                    .font(.caption).foregroundColor(Color.nostiaTextSecond)
                            }
                            HStack(spacing: 10) {
                                if let type = event.visibility {
                                    Text("\(type.capitalized) experience")
                                }
                                if let visited = event.visitedCount, visited > 0 {
                                    Text("\(visited) visited")
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
            .navigationTitle("Nearby Experiences")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }.foregroundColor(Color.nostiaAccent)
                }
            }
        }
        .presentationBackground(Color.nostiaBackground)
    }

    private func accessibilityLabel(for e: Experience) -> String {
        var parts = [e.title]
        if let type = e.visibility { parts.append("\(type) experience") }
        if let dist = e.formattedDistance { parts.append("\(dist) away") }
        if let visited = e.visitedCount, visited > 0 { parts.append("\(visited) visited") }
        return parts.joined(separator: ", ")
    }
}
