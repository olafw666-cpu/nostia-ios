import Combine
import Foundation

@MainActor
final class AdventuresViewModel: ObservableObject {
    @Published var adventures: [Adventure] = []
    @Published var events: [Event] = []
    @Published var searchQuery = ""
    @Published var selectedCategory: String?
    @Published var selectedDifficulty: String?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var selectedTab: AdventureTab = .events

    enum AdventureTab { case events, adventures }

    let categories = ["All", "Hiking", "Cycling", "Water Sports", "Climbing", "Skiing", "Cultural", "Other"]
    let difficulties = ["All", "Easy", "Moderate", "Hard", "Expert"]

    func loadAll() async {
        isLoading = true
        async let advsData = AdventuresAPI.shared.getAll()
        async let eventsData = AdventuresAPI.shared.getAllEvents()
        do {
            let (a, e) = try await (advsData, eventsData)
            adventures = a
            events = e
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func search() async {
        isLoading = true
        do {
            adventures = try await AdventuresAPI.shared.getAll(
                search: searchQuery.isEmpty ? nil : searchQuery,
                category: selectedCategory,
                difficulty: selectedDifficulty
            )
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func createAdventure(title: String, location: String, description: String, category: String?, difficulty: String?) async throws {
        let _ = try await AdventuresAPI.shared.createAdventure(
            title: title,
            location: location,
            description: description.isEmpty ? nil : description,
            category: category,
            difficulty: difficulty
        )
        await loadAll()
    }
}
