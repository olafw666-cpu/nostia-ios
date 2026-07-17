import Combine
import CoreMotion
import Foundation
import SwiftUI

/// Drives AdventureView: load current state, generate (a synchronous pool draw), sync
/// pedometer progress to the server, complete, discard.
@MainActor
final class AdventureViewModel: ObservableObject {

    @Published var state: AdventureCurrentState?
    @Published var isLoading = false
    @Published var isCrafting = false          // generate request in flight (incl. reveal hold)
    @Published var craftingStartedAt: Date?    // drives the crafting card's phased copy
    @Published var errorMessage: String?
    @Published var celebrationPoints: Int?     // set on completion → points toast
    @Published var pointsBalance: Int = 0
    @Published var isSyncing = false

    /// Ticks every second while a countdown is visible so the label stays live.
    @Published var now = Date()

    private let pedometer = PedometerManager.shared
    private var clockTask: Task<Void, Never>?
    private var liveCancellable: AnyCancellable?

    /// Throttle state. Steady state is ~1 POST/60s while the screen is open — about 15
    /// per 15min against the server's 60/15min progress limiter.
    private var lastSyncAt: Date?
    private var lastSyncedSteps = 0
    private var lastSyncedDistanceM = 0.0
    private static let minSyncInterval: TimeInterval = 60
    private static let minStepDelta = 25
    private static let minDistanceDeltaM = 25.0

    var adventure: DailyAdventure? { state?.adventure }

    /// A new generation is permitted once the rolling 24h has elapsed (or the user has
    /// never generated). The last adventure stays visible and completable until they
    /// actually generate again.
    var canGenerateNow: Bool {
        guard let state else { return false }
        guard let next = state.nextAvailableDate else { return true }
        return now >= next
    }

    var countdownText: String? {
        guard let next = state?.nextAvailableDate, next > now else { return nil }
        let s = Int(next.timeIntervalSince(now))
        return String(format: "%02d:%02d:%02d", s / 3600, (s % 3600) / 60, s % 60)
    }

    /// Fat-finger discard: within 5 min of issuance. Progress is deliberately NOT a
    /// condition — it accrues passively from the pedometer now, so gating on it would
    /// burn the discard for merely walking to the kitchen.
    var canDiscard: Bool {
        guard let adv = adventure, adv.isActive, let issued = adv.issuedDate else { return false }
        return now.timeIntervalSince(issued) <= 5 * 60
    }

    /// Motion permission is what the whole feature rests on — surface it, don't fail
    /// silently into an empty progress bar.
    var motionUnavailable: Bool { !PedometerManager.isAvailable }
    var motionDenied: Bool { pedometer.isDenied }

    // MARK: - Lifecycle

    func onAppear() {
        startClock()
        pedometer.refreshAuthorizationStatus()
        Task {
            await pedometer.requestAuthorization()
            await load()
            await syncProgress()
            startLiveUpdatesIfNeeded()
        }
    }

    func onDisappear() {
        clockTask?.cancel()
        clockTask = nil
        stopLive()
    }

    /// AdventureView had no scenePhase handling before this feature; it needs it now,
    /// because a backgrounded app misses steps that the retroactive query will pick up.
    func onScenePhaseChange(_ phase: ScenePhase) {
        switch phase {
        case .active:
            pedometer.refreshAuthorizationStatus()
            Task {
                await load()
                await syncProgress()
                startLiveUpdatesIfNeeded()
            }
        case .background, .inactive:
            // Flush before we lose foreground time, then stop the live stream.
            Task { await syncProgress(force: true) }
            stopLive()
        @unknown default:
            break
        }
    }

    func load() async {
        isLoading = state == nil
        defer { isLoading = false }
        do {
            let fresh = try await AdventureAPI.shared.getCurrent()
            state = fresh
            pointsBalance = fresh.pointsBalance ?? pointsBalance
        } catch {
            errorMessage = (error as? APIError)?.localizedDescription ?? error.localizedDescription
        }
    }

    // MARK: - Generation

    /// The reveal hold: a pool draw returns in milliseconds, but an adventure that
    /// appears instantly reads as dispensed, not made. Keep the crafting state up for
    /// 20–30s before revealing — deliberate UX, not a bug. The adventure is already
    /// issued server-side the moment the API call returns, so an interruption mid-hold
    /// (background, force-quit) loses nothing: /current shows it on the next load.
    /// Errors skip the hold — nobody should wait half a minute to see a failure.
    private static let craftHold: ClosedRange<Double> = 20...30

    func generate(difficulty: AdventureDifficulty) async {
        errorMessage = nil
        isCrafting = true
        let craftStart = Date()
        craftingStartedAt = craftStart
        defer {
            isCrafting = false
            craftingStartedAt = nil
        }
        do {
            _ = try await AdventureAPI.shared.generate(difficulty: difficulty)
            let hold = Double.random(in: Self.craftHold) - Date().timeIntervalSince(craftStart)
            if hold > 0 {
                try? await Task.sleep(nanoseconds: UInt64(hold * 1_000_000_000))
            }
            resetSyncState()
            await load()
            await syncProgress(force: true)  // baseline from issue time
            startLiveUpdatesIfNeeded()
            Haptics.tap()
        } catch let APIError.httpError(statusCode, message) {
            if statusCode == 429 {
                await load() // refresh next_available_at and show the countdown
            } else {
                errorMessage = message
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Progress

    /// Query the pedometer from the adventure's issue time and report the reading.
    /// Used by the appear / foreground / pre-complete paths, where we have no live
    /// value in hand. Safe to call often — the throttle drops the redundant ones.
    func syncProgress(force: Bool = false) async {
        guard let adv = adventure, adv.isActive, adv.isMeasured,
              let issued = adv.issuedDate, PedometerManager.isAvailable, !pedometer.isDenied
        else { return }

        // Never read past the 24h boundary — the server clamps to the same edge.
        let to = min(Date(), adv.windowEnd ?? Date())
        guard to > issued else { return }
        guard let reading = try? await pedometer.query(from: issued, to: to) else { return }
        await ingest(reading, force: force)
    }

    /// Apply the throttle and POST. Takes a reading rather than fetching one, so the
    /// live-update path doesn't spend an XPC round-trip re-reading a value the tick
    /// already delivered. Live readings are cumulative from `issued`, exactly like a
    /// query over the same window, so the two are interchangeable here.
    private func ingest(_ reading: PedometerManager.Reading, force: Bool = false) async {
        guard let adv = adventure, adv.isActive, adv.isMeasured else { return }

        // startUpdates has no end date, so once the window closes its readings would
        // keep climbing past what the adventure allows. Stop trusting them and let the
        // server's stored progress stand.
        if let end = adv.windowEnd, Date() > end {
            stopLive()
            return
        }
        guard force || shouldSync(reading) else { return }

        isSyncing = true
        defer { isSyncing = false }
        do {
            let resp = try await AdventureAPI.shared.reportProgress(
                adventureId: adv.id, steps: reading.steps, distanceM: reading.distanceM
            )
            replaceAdventure(resp.adventure)
            lastSyncAt = Date()
            lastSyncedSteps = reading.steps
            lastSyncedDistanceM = reading.distanceM
        } catch {
            // Best-effort: the server keeps the last good value and the next read
            // re-reads the whole window from issued_at, so a dropped sync self-heals.
            // Never surface it as an error.
        }
    }

    private func shouldSync(_ reading: PedometerManager.Reading) -> Bool {
        // Always push the moment targets are first met, so Complete lights up without
        // waiting out the interval.
        if let adv = adventure, let st = adv.stepsTarget, let dt = adv.distanceTargetM,
           reading.steps >= st, Int(reading.distanceM) >= dt, !adv.targetsMet {
            return true
        }
        guard let last = lastSyncAt else { return true }
        guard Date().timeIntervalSince(last) >= Self.minSyncInterval else { return false }
        let stepDelta = reading.steps - lastSyncedSteps
        let distDelta = reading.distanceM - lastSyncedDistanceM
        return stepDelta >= Self.minStepDelta || distDelta >= Self.minDistanceDeltaM
    }

    private func startLiveUpdatesIfNeeded() {
        guard let adv = adventure, adv.isActive, adv.isMeasured,
              let issued = adv.issuedDate, let end = adv.windowEnd,
              Date() < end, PedometerManager.isAvailable, !pedometer.isDenied
        else { return }

        pedometer.startLiveUpdates(from: issued)
        // The tick already carries the reading — hand it straight to the throttle
        // rather than re-querying for a value we were just given.
        liveCancellable = pedometer.$liveReading
            .compactMap { $0 }
            .sink { [weak self] reading in
                Task { @MainActor in await self?.ingest(reading) }
            }
    }

    private func stopLive() {
        liveCancellable?.cancel()
        liveCancellable = nil
        pedometer.stopLiveUpdates()
    }

    private func resetSyncState() {
        lastSyncAt = nil
        lastSyncedSteps = 0
        lastSyncedDistanceM = 0
        stopLive()
    }

    // MARK: - Completion

    /// Completion reads the SERVER's stored progress, so a tap on fresh-but-unsynced
    /// local progress would 409. Force a sync first, then complete — sequentially.
    func complete() async {
        guard let adv = adventure, adv.isActive else { return }
        await syncProgress(force: true)
        guard let fresh = adventure, fresh.targetsMet else {
            errorMessage = "Keep going — you haven't hit both targets yet."
            return
        }
        do {
            let resp = try await AdventureAPI.shared.complete(adventureId: fresh.id)
            celebrationPoints = resp.pointsAwarded
            pointsBalance = resp.pointsBalance
            stopLive()
            await load()
            Haptics.tap()
        } catch {
            errorMessage = (error as? APIError)?.localizedDescription ?? error.localizedDescription
            await load()
        }
    }

    func discard() async {
        guard let adv = adventure else { return }
        do {
            try await AdventureAPI.shared.discard(adventureId: adv.id)
            resetSyncState()
            await load()
        } catch {
            errorMessage = (error as? APIError)?.localizedDescription ?? error.localizedDescription
        }
    }

    // MARK: - Helpers

    private func replaceAdventure(_ adv: DailyAdventure) {
        guard let state else { return }
        self.state = AdventureCurrentState(
            adventure: adv,
            nextAvailableAt: state.nextAvailableAt,
            pointsBalance: state.pointsBalance
        )
    }

    private func startClock() {
        guard clockTask == nil else { return }
        clockTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                await MainActor.run { self?.now = Date() }
            }
        }
    }
}
