import SwiftUI

/// Shared "Visited" tab body (spec §4): a search bar, a preset-tag filter row, and a
/// vertical list of ExperienceCards for the experiences a user marked Visited (D6).
/// Filtering/sorting is client-side over the loaded list.
///
/// Designed to embed inside a parent ScrollView (ProfileView / PublicProfileView), so it
/// uses a LazyVStack rather than its own List/ScrollView.
struct VisitedExperiencesView: View {
    let userId: Int
    /// When the parent already fetched the list (e.g. PublicProfileView probed permission),
    /// pass it here to skip a second network call.
    var preloaded: [Experience]? = nil

    @State private var experiences: [Experience] = []
    @State private var isLoading = false
    @State private var didLoad = false
    @State private var searchText = ""
    @State private var selectedTags: Set<String> = []
    @State private var selectedEvent: Experience?
    @State private var selectedCreatorId: Int?
    @State private var actionsVM = ExperienceActionsViewModel()
    @EnvironmentObject var responsive: ResponsiveLayoutManager

    // Client-side filter: search matches title/location, tags match any selected tag.
    private var filtered: [Experience] {
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return experiences.filter { exp in
            let matchesSearch = q.isEmpty
                || exp.title.lowercased().contains(q)
                || (exp.location?.lowercased().contains(q) ?? false)
            let matchesTags = selectedTags.isEmpty
                || !selectedTags.isDisjoint(with: Set(exp.tags ?? []))
            return matchesSearch && matchesTags
        }
    }

    var body: some View {
        VStack(spacing: responsive.spacing(12)) {
            searchBar
            tagFilterRow
            content
        }
        .task {
            guard !didLoad else { return }
            didLoad = true
            if let preloaded { experiences = preloaded }
            else { await load() }
        }
        .sheet(item: $selectedEvent, onDismiss: { Task { await load() } }) { event in
            ExperienceDetailSheet(event: event, vm: actionsVM)
        }
        .sheet(item: Binding(
            get: { selectedCreatorId.map { CreatorNavTarget(id: $0) } },
            set: { selectedCreatorId = $0?.id }
        )) { target in
            NavigationStack { PublicProfileView(userId: target.id) }
                .presentationBackground(Color.nostiaBackground)
        }
    }

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass").foregroundColor(Color.nostiaTextMuted)
            TextField("", text: $searchText, prompt: Text("Search visited").foregroundColor(Color.nostiaTextMuted))
                .foregroundColor(Color.nostiaTextPrimary)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
            if !searchText.isEmpty {
                Button { searchText = "" } label: {
                    Image(systemName: "xmark.circle.fill").foregroundColor(Color.nostiaTextMuted)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(responsive.spacing(12))
        .nostiaWarmCard(in: RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, responsive.spacing(16))
    }

    private var tagFilterRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(experienceTags, id: \.self) { tag in
                    FilterChip(title: tag, isActive: selectedTags.contains(tag)) {
                        if selectedTags.contains(tag) { selectedTags.remove(tag) }
                        else { selectedTags.insert(tag) }
                    }
                }
            }
            .padding(.horizontal, responsive.spacing(16))
        }
    }

    @ViewBuilder
    private var content: some View {
        if isLoading {
            ProgressView().tint(Color.nostiaAccent).padding(.vertical, responsive.spacing(24))
        } else if experiences.isEmpty {
            Text("No visited experiences yet.")
                .font(.subheadline).foregroundColor(Color.nostiaTextMuted)
                .padding(.vertical, responsive.spacing(24))
        } else if filtered.isEmpty {
            Text("No experiences match your filters.")
                .font(.subheadline).foregroundColor(Color.nostiaTextMuted)
                .padding(.vertical, responsive.spacing(24))
        } else {
            LazyVStack(spacing: responsive.spacing(10)) {
                ForEach(filtered) { event in
                    Button { selectedEvent = event } label: {
                        ExperienceCard(event: event, onCreatorTap: { selectedCreatorId = $0 })
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, responsive.spacing(16))
                }
            }
        }
    }

    private func load() async {
        isLoading = true
        // Server enforces visibility on GET /users/{id}/visited; a 403 yields an empty list.
        experiences = (try? await ExperiencesAPI.shared.getVisited(userId: userId)) ?? []
        isLoading = false
    }
}

private struct CreatorNavTarget: Identifiable { let id: Int }
