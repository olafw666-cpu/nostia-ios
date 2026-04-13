import Foundation
import CoreLocation

@MainActor
final class HomeViewModel: ObservableObject {
    @Published var user: User?
    @Published var trips: [Trip] = []
    @Published var upcomingEvents: [Event] = []
    @Published var nearbyEvents: [Event] = []
    @Published var friends: [Friend] = []
    @Published var feed: [FeedPost] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    func loadAll() async {
        isLoading = true
        errorMessage = nil
        // Load user first — failure means session is invalid
        do {
            user = try await AuthAPI.shared.getMe()
        } catch {
            AuthManager.shared.logout()
            isLoading = false
            return
        }
        // Load the rest concurrently, ignoring individual failures
        async let t = TripsAPI.shared.getAll()
        async let e = AdventuresAPI.shared.getUpcomingEvents(limit: 5)
        async let f = FriendsAPI.shared.getAll()
        async let fd = FeedAPI.shared.getUserFeed(limit: 5)
        trips = (try? await t) ?? []
        upcomingEvents = (try? await e) ?? []
        friends = (try? await f) ?? []
        feed = (try? await fd) ?? []
        isLoading = false
    }

    func updateLocation(_ location: CLLocation) async {
        do {
            _ = try await AuthAPI.shared.updateMe([
                "latitude": location.coordinate.latitude,
                "longitude": location.coordinate.longitude
            ])
            let nearby = try await AdventuresAPI.shared.getNearbyEvents(
                lat: location.coordinate.latitude,
                lng: location.coordinate.longitude,
                radius: 50
            )
            nearbyEvents = nearby
        } catch {
            print("Location update failed: \(error.localizedDescription)")
        }
    }

    func toggleHomeStatus() async {
        guard let u = user else { return }
        let newStatus = u.isHomeOpen ? "closed" : "open"
        do {
            let updated = try await AuthAPI.shared.updateMe(["homeStatus": newStatus])
            user = updated
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
