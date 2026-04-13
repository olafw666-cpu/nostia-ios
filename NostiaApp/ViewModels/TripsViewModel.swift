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

    func createTrip(title: String, destination: String, description: String?, startDate: String?, endDate: String?) async -> Bool {
        do {
            let trip = try await TripsAPI.shared.create(title: title, destination: destination, description: description, startDate: startDate, endDate: endDate)
            trips.insert(trip, at: 0)
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func updateTrip(_ id: Int, title: String, destination: String, description: String?, startDate: String?, endDate: String?) async -> Bool {
        do {
            let updated = try await TripsAPI.shared.update(id, title: title, destination: destination, description: description, startDate: startDate, endDate: endDate)
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
}
