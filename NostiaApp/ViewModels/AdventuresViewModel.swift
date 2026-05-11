import Combine
import Foundation
import Darwin

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
        errorMessage = nil
        async let advsTask = AdventuresAPI.shared.getAll()
        // Use radius-based map endpoint if location is available
        let loc = LocationManager.shared.location
        if let loc = loc {
            let lat = loc.coordinate.latitude
            let lng = loc.coordinate.longitude
            let latDelta = 50.0 / 111.0
            let lngDelta = 50.0 / (111.0 * cos(lat * .pi / 180.0))
            events = (try? await AdventuresAPI.shared.getMapEvents(
                minLat: lat - latDelta, maxLat: lat + latDelta,
                minLng: lng - lngDelta, maxLng: lng + lngDelta,
                viewportRadiusMiles: 31
            )) ?? []
        } else {
            events = (try? await AdventuresAPI.shared.getAllEvents()) ?? []
        }
        adventures = (try? await advsTask) ?? []
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
