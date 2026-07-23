import Combine
import CoreLocation
import Foundation

/// Foreground geofence-dwell sampler (Product Definition v2 §6). When the user
/// taps "I'm here" on a stop, this collects high-accuracy fixes for the dwell
/// window and posts the batch; the SERVER decides whether it constitutes a
/// completion. Deliberately when-in-use + foreground-only — no Always
/// permission, no region monitoring, no background location (App Store and
/// battery posture; an Always-based passive path is a later enhancement).
@MainActor
final class DwellVerifier: NSObject, ObservableObject {
    enum Phase: Equatable {
        case idle
        case sampling(secondsRemaining: Int)
        case submitting
        case confirmed(corroborated: Bool)
        case rejected(reason: String)
        case failed(message: String)
    }

    @Published private(set) var phase: Phase = .idle

    /// Mirrors the server's DWELL_MIN_SECONDS (90) plus margin so the batch
    /// never fails on span alone.
    private let dwellSeconds = 100
    private let manager = CLLocationManager()
    private var samples: [[String: Any]] = []
    private var countdownTask: Task<Void, Never>?
    private var activePlanId: Int?
    private var activeStopId: Int?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
        manager.activityType = .fitness
    }

    var isRunning: Bool {
        switch phase {
        case .sampling, .submitting: return true
        default: return false
        }
    }

    func start(planId: Int, stopId: Int) {
        guard !isRunning else { return }
        guard manager.authorizationStatus == .authorizedWhenInUse ||
              manager.authorizationStatus == .authorizedAlways else {
            phase = .failed(message: "Location permission is needed to verify you're here.")
            return
        }
        activePlanId = planId
        activeStopId = stopId
        samples = []
        manager.startUpdatingLocation()
        phase = .sampling(secondsRemaining: dwellSeconds)

        countdownTask?.cancel()
        countdownTask = Task { [weak self] in
            guard let self else { return }
            for remaining in stride(from: dwellSeconds - 1, through: 0, by: -1) {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                if Task.isCancelled { return }
                if case .sampling = self.phase {
                    self.phase = .sampling(secondsRemaining: remaining)
                }
            }
            await self.submit()
        }
    }

    func cancel() {
        countdownTask?.cancel()
        countdownTask = nil
        manager.stopUpdatingLocation()
        samples = []
        phase = .idle
    }

    private func submit() async {
        manager.stopUpdatingLocation()
        countdownTask = nil
        guard let planId = activePlanId, let stopId = activeStopId else { return }

        guard samples.count >= 5 else {
            phase = .failed(message: "Couldn't get enough location fixes — step outside or away from walls and try again.")
            return
        }
        phase = .submitting
        do {
            let resp = try await PlansAPI.shared.verifyDwell(planId: planId, stopId: stopId, samples: samples)
            Haptics.success()
            phase = .confirmed(corroborated: resp.completion.corroborated)
        } catch let APIError.httpError(status, message) where status == 422 {
            // The server says why (outside the fence, dwell too short) — show
            // it honestly; retrying with a longer dwell is the only path.
            phase = .rejected(reason: message)
        } catch let APIError.httpError(status, _) where status == 409 {
            // Already completed — treat as confirmed so the UI settles.
            phase = .confirmed(corroborated: false)
        } catch {
            phase = .failed(message: "Couldn't reach the server. Try again in a moment.")
        }
    }
}

extension DwellVerifier: CLLocationManagerDelegate {
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        Task { @MainActor in
            guard case .sampling = self.phase else { return }
            for loc in locations {
                self.samples.append([
                    "lat": loc.coordinate.latitude,
                    "lng": loc.coordinate.longitude,
                    "acc": loc.horizontalAccuracy,
                    "ts": Int(loc.timestamp.timeIntervalSince1970 * 1000),
                ])
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("DwellVerifier location error: \(error.localizedDescription)")
    }
}
