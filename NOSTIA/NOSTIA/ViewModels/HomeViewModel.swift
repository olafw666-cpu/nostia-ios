import Combine
import Foundation
import CoreLocation

@MainActor
final class HomeViewModel: ObservableObject {
    @Published var user: User?
    @Published var trips: [Trip] = []
    @Published var upcomingEvents: [Experience] = []
    @Published var nearbyEvents: [Experience] = []
    @Published var followers: [FollowUser] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    func loadAll() async {
        isLoading = true
        errorMessage = nil
        do {
            user = try await AuthAPI.shared.getMe()
        } catch {
            // APIClient already calls logout() on 401/403 — don't double-logout on transient errors
            errorMessage = error.localizedDescription
            isLoading = false
            return
        }
        // Load the rest concurrently, ignoring individual failures
        async let t = TripsAPI.shared.getAll()
        async let e = ExperiencesAPI.shared.getMyGoingExperiences()
        async let f = FriendsAPI.shared.getFollowers()
        trips = (try? await t) ?? []
        upcomingEvents = (try? await e) ?? []
        followers = (try? await f) ?? []
        isLoading = false
    }

    func adminDeleteExperience(id: Int) async {
        do {
            try await ExperiencesAPI.shared.adminDeleteExperience(id: id)
            upcomingEvents.removeAll { $0.id == id }
            nearbyEvents.removeAll { $0.id == id }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func updateLocation(_ location: CLLocation) async {
        do {
            _ = try await AuthAPI.shared.updateMe([
                "latitude": location.coordinate.latitude,
                "longitude": location.coordinate.longitude
            ])
            let nearby = try await ExperiencesAPI.shared.getNearbyExperiences(
                lat: location.coordinate.latitude,
                lng: location.coordinate.longitude,
                radius: 50
            )
            nearbyEvents = nearby
        } catch {
            print("Location update failed: \(error.localizedDescription)")
        }
    }


}
