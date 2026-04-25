import Combine
import Foundation

@MainActor
final class TripsViewModel: ObservableObject {
    @Published var trips: [Trip] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var successMessage: String?

    func loadTrips() async {
        isLoading = true
        errorMessage = nil
        do {
            trips = try await TripsAPI.shared.getAll()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func createTrip(title: String, description: String?, friendIds: [Int]) async -> Trip? {
        do {
            var trip = try await TripsAPI.shared.create(title: title, description: description)
            for friendId in friendIds {
                trip = try await TripsAPI.shared.addParticipant(tripId: trip.id, userId: friendId)
            }
            trips.insert(trip, at: 0)
            return trip
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }

    func updateTrip(_ id: Int, title: String, description: String?) async -> Bool {
        do {
            let updated = try await TripsAPI.shared.update(id, title: title, description: description)
            if let idx = trips.firstIndex(where: { $0.id == id }) {
                trips[idx] = updated
            }
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func deleteTrip(_ id: Int) async -> Bool {
        do {
            try await TripsAPI.shared.delete(id)
            trips.removeAll { $0.id == id }
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func addParticipant(tripId: Int, userId: Int) async -> Bool {
        do {
            let updated = try await TripsAPI.shared.addParticipant(tripId: tripId, userId: userId)
            if let idx = trips.firstIndex(where: { $0.id == tripId }) {
                trips[idx] = updated
            }
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func removeParticipant(tripId: Int, userId: Int) async -> Bool {
        do {
            let updated = try await TripsAPI.shared.removeParticipant(tripId: tripId, userId: userId)
            if let idx = trips.firstIndex(where: { $0.id == tripId }) {
                trips[idx] = updated
            }
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func kickParticipant(tripId: Int, userId: Int) async -> Bool {
        do {
            let updated = try await TripsAPI.shared.kickParticipant(tripId: tripId, userId: userId)
            if let idx = trips.firstIndex(where: { $0.id == tripId }) {
                trips[idx] = updated
            }
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func transferLeadership(tripId: Int, newLeaderId: Int) async -> Bool {
        do {
            let updated = try await TripsAPI.shared.transferLeadership(tripId: tripId, newLeaderId: newLeaderId)
            if let idx = trips.firstIndex(where: { $0.id == tripId }) {
                trips[idx] = updated
            }
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func refreshTrip(_ id: Int) async {
        do {
            let updated = try await TripsAPI.shared.get(id)
            if let idx = trips.firstIndex(where: { $0.id == id }) {
                trips[idx] = updated
            } else {
                trips.insert(updated, at: 0)
            }
        } catch {}
    }
}
