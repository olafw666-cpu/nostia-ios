import Combine
import Foundation
import CoreLocation
import Darwin

@MainActor
final class HomeViewModel: ObservableObject {
    @Published var user: User?
    @Published var trips: [Trip] = []
    @Published var upcomingEvents: [Event] = []
    @Published var nearbyEvents: [Event] = []
    @Published var goingEvents: [Event] = []
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
        async let mg = AdventuresAPI.shared.getMineEvents()
        trips = (try? await t) ?? []
        upcomingEvents = (try? await e) ?? []
        friends = (try? await f) ?? []
        feed = (try? await fd) ?? []
        goingEvents = (try? await mg) ?? []
        isLoading = false
    }

    func updateLocation(_ location: CLLocation) async {
        let lat = location.coordinate.latitude
        let lng = location.coordinate.longitude
        do {
            _ = try await AuthAPI.shared.updateMe([
                "latitude": lat,
                "longitude": lng
            ])
            let latDelta = 50.0 / 111.0
            let lngDelta = 50.0 / (111.0 * cos(lat * .pi / 180.0))
            let nearby = try await AdventuresAPI.shared.getMapEvents(
                minLat: lat - latDelta, maxLat: lat + latDelta,
                minLng: lng - lngDelta, maxLng: lng + lngDelta,
                viewportRadiusMiles: 31
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
