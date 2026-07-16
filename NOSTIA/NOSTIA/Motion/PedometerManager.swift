import Combine
import CoreMotion
import Foundation

/// Reads step count and walking distance from the motion coprocessor.
///
/// Adventures are measured, not self-reported: the server stores progress, and this is
/// where that progress comes from. Two properties of CMPedometer make the whole design
/// work without any background execution:
///
/// 1. `queryPedometerData(from:to:)` is **retroactive** — iOS logs steps continuously
///    in hardware and keeps ~7 days of history, whether or not the app was running. A
///    24h adventure window is always recoverable, so we simply query from `issued_at`
///    whenever the app opens. No background modes, no location, no battery cost.
/// 2. Distance comes from the same query as steps, derived from cadence and the user's
///    height. That is also why a target's implied stride taxes short users more than
///    tall ones — see TARGET_ENVELOPES in services/adventureTargets.js.
///
/// There is no explicit authorization request API for CoreMotion: the *first query*
/// triggers the system prompt. `requestAuthorization()` below issues a throwaway query
/// for exactly that reason.
@MainActor
final class PedometerManager: ObservableObject {
    static let shared = PedometerManager()

    struct Reading: Equatable {
        let steps: Int
        let distanceM: Double
    }

    @Published private(set) var authorizationStatus: CMAuthorizationStatus = CMPedometer.authorizationStatus()
    @Published private(set) var liveReading: Reading?

    private let pedometer = CMPedometer()
    private var isLive = false

    private init() {}

    /// False on the Simulator, on devices without a motion coprocessor, and when the
    /// user has switched Motion & Fitness off globally in Settings → Privacy.
    static var isAvailable: Bool {
        CMPedometer.isStepCountingAvailable() && CMPedometer.isDistanceAvailable()
    }

    var isDenied: Bool {
        authorizationStatus == .denied || authorizationStatus == .restricted
    }

    func refreshAuthorizationStatus() {
        authorizationStatus = CMPedometer.authorizationStatus()
    }

    /// Triggers the system permission prompt. CoreMotion has no explicit request API —
    /// the first query is what asks — so this fires a cheap one and discards the result.
    func requestAuthorization() async {
        guard Self.isAvailable, authorizationStatus == .notDetermined else { return }
        _ = try? await query(from: Date().addingTimeInterval(-60), to: Date())
        refreshAuthorizationStatus()
    }

    /// Cumulative steps + distance over a window. Throws if unavailable or denied.
    func query(from: Date, to: Date) async throws -> Reading {
        guard Self.isAvailable else { throw PedometerError.unavailable }
        guard to > from else { return Reading(steps: 0, distanceM: 0) }

        return try await withCheckedThrowingContinuation { continuation in
            pedometer.queryPedometerData(from: from, to: to) { data, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let data else {
                    continuation.resume(throwing: PedometerError.noData)
                    return
                }
                continuation.resume(returning: Reading(
                    steps: data.numberOfSteps.intValue,
                    distanceM: data.distance?.doubleValue ?? 0
                ))
            }
        }
    }

    /// Live updates for the on-screen bars while the adventure screen is foregrounded.
    /// `startUpdates` has no end date, so callers must not use it once the 24h window
    /// has closed — it would keep accruing past the deadline. AdventureViewModel
    /// switches to a bounded one-shot `query` in that case.
    func startLiveUpdates(from: Date) {
        guard Self.isAvailable, !isLive else { return }
        isLive = true
        pedometer.startUpdates(from: from) { [weak self] data, _ in
            guard let data else { return }
            Task { @MainActor in
                self?.liveReading = Reading(
                    steps: data.numberOfSteps.intValue,
                    distanceM: data.distance?.doubleValue ?? 0
                )
            }
        }
    }

    func stopLiveUpdates() {
        guard isLive else { return }
        pedometer.stopUpdates()
        isLive = false
        liveReading = nil
    }

    enum PedometerError: LocalizedError {
        case unavailable
        case noData

        var errorDescription: String? {
            switch self {
            case .unavailable: return "Step tracking isn't available on this device."
            case .noData: return "No motion data available for that period."
            }
        }
    }
}
