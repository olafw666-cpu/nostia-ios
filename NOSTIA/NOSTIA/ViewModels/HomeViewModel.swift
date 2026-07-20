import Combine
import Foundation
import CoreLocation

@MainActor
final class HomeViewModel: ObservableObject {
    @Published var user: User?
    @Published var trips: [Trip] = []
    @Published var upcomingEvents: [Experience] = []
    @Published var nearbyEvents: [Experience] = []
    @Published var forYouEvents: [Experience] = []
    @Published var following: [FollowUser] = []
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
        // Load the rest concurrently, ignoring individual failures. For-you uses the
        // server-side stored-location fallback; updateLocation() refreshes it with live coords.
        async let t = TripsAPI.shared.getAll()
        async let e = ExperiencesAPI.shared.getMyGoingExperiences()
        // "Following" stat card counts who the user follows — /following, not /followers.
        async let f = FriendsAPI.shared.getFollowing()
        async let fy = ExperiencesAPI.shared.getForYouExperiences()
        trips = (try? await t) ?? []
        upcomingEvents = (try? await e) ?? []
        following = (try? await f) ?? []
        forYouEvents = (try? await fy) ?? forYouEvents
        isLoading = false
    }

    func adminDeleteExperience(id: Int) async {
        do {
            try await ExperiencesAPI.shared.adminDeleteExperience(id: id)
            upcomingEvents.removeAll { $0.id == id }
            nearbyEvents.removeAll { $0.id == id }
            forYouEvents.removeAll { $0.id == id }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func updateLocation(_ location: CLLocation) async {
        // Sync the stored location first, but never let a failed sync (transient network
        // error or a 429 from the rate limiter) block the nearby/for-you refresh below —
        // both fetches take explicit coordinates and don't need the sync to have landed.
        do {
            _ = try await AuthAPI.shared.updateMe([
                "latitude": location.coordinate.latitude,
                "longitude": location.coordinate.longitude
            ])
        } catch {
            print("Location sync failed: \(error.localizedDescription)")
        }
        async let nearby = ExperiencesAPI.shared.getNearbyExperiences(
            lat: location.coordinate.latitude,
            lng: location.coordinate.longitude,
            radius: 50
        )
        async let forYou = ExperiencesAPI.shared.getForYouExperiences(
            lat: location.coordinate.latitude,
            lng: location.coordinate.longitude
        )
        nearbyEvents = (try? await nearby) ?? nearbyEvents
        forYouEvents = (try? await forYou) ?? forYouEvents
    }


}
