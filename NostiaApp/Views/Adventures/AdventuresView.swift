import SwiftUI

struct AdventuresView: View {
    @StateObject private var vm = AdventuresViewModel()
    @State private var showCreateAdventure = false

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
                List(vm.events) { event in
                    EventCard(event: event)
                        .listRowBackground(Color.clear).listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                }
                .listStyle(.plain).background(.clear).scrollContentBackground(.hidden)
                .refreshable { await vm.loadAll() }
                .overlay {
                    if vm.events.isEmpty { EmptyStateView(icon: "calendar", text: "No events", sub: "Check back soon!") }
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
    }
}

struct EventCard: View {
    let event: Event
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(event.title).font(.headline).foregroundColor(.white)
                Spacer()
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
            Label(event.formattedDate, systemImage: "calendar")
                .font(.footnote.bold()).foregroundColor(Color.nostiaWarning)
        }
        .padding(16)
        .glassEffect(in: RoundedRectangle(cornerRadius: 16))
    }
}

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
