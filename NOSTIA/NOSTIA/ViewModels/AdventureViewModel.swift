import Combine
import Foundation
import SwiftUI

/// Drives AdventureView (spec §12.1): load current state, generate (with the
/// 202-poll / 200-instant split), optimistic step checks, complete, discard.
@MainActor
final class AdventureViewModel: ObservableObject {

    @Published var state: AdventureCurrentState?
    @Published var isLoading = false
    @Published var isCrafting = false          // job queued/running on the server
    @Published var errorMessage: String?
    @Published var promptError: String?        // inline 422 message under the prompt field
    @Published var celebrationPoints: Int?     // set on completion → points toast
    @Published var pointsBalance: Int = 0

    /// Ticks every second while a countdown is visible so the label stays live.
    @Published var now = Date()

    private var pollTask: Task<Void, Never>?
    private var clockTask: Task<Void, Never>?

    var adventure: DailyAdventure? { state?.adventure }

    /// §6 — a new generation is permitted once the rolling 24h has elapsed
    /// (or the user has never generated). The last adventure stays visible and
    /// completable until they actually generate again.
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

    /// §6 fat-finger discard: zero steps checked and within 5 min of issuance.
    var canDiscard: Bool {
        guard let adv = adventure, adv.isActive, adv.checkedCount == 0,
              let issued = adv.issuedDate else { return false }
        return now.timeIntervalSince(issued) <= 5 * 60
    }

    func onAppear() {
        startClock()
        Task { await load() }
    }

    func onDisappear() {
        clockTask?.cancel()
        clockTask = nil
    }

    func load() async {
        isLoading = state == nil
        defer { isLoading = false }
        do {
            let fresh = try await AdventureAPI.shared.getCurrent()
            state = fresh
            pointsBalance = fresh.pointsBalance ?? pointsBalance
            // A job may still be resolving from a previous visit — reflect it.
            if isCrafting, fresh.adventure?.isActive == true { isCrafting = false }
        } catch {
            errorMessage = (error as? APIError)?.localizedDescription ?? error.localizedDescription
        }
    }

    // MARK: - Generation (§12.1 onGenerateTapped)

    func generate(difficulty: AdventureDifficulty, prompt: String) async {
        promptError = nil
        errorMessage = nil
        do {
            let resp = try await AdventureAPI.shared.generate(
                difficulty: difficulty,
                prompt: String(prompt.prefix(280))
            )
            if let jobId = resp.jobId {
                isCrafting = true
                startPolling(jobId: jobId)
            } else if resp.adventure != nil {
                // Instant fallback path — rendered immediately.
                await load()
                Haptics.tap()
            }
        } catch let APIError.httpError(statusCode, message) {
            switch statusCode {
            case 422:
                promptError = "That prompt can't be used — try something else"
            case 429:
                await load() // refresh next_available_at and show the countdown
            default:
                errorMessage = message
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func startPolling(jobId: Int) {
        pollTask?.cancel()
        // Inherits @MainActor from the enclosing context; property access is direct.
        pollTask = Task { [weak self] in
            // Poll every 3s (§2 client wait UX); the server hard-caps a job at
            // ~120s + queue time, so 60 polls is a generous ceiling.
            for _ in 0..<60 {
                if Task.isCancelled { return }
                try? await Task.sleep(nanoseconds: 3_000_000_000)
                guard let self else { return }
                guard let status = try? await AdventureAPI.shared.jobStatus(id: jobId) else { continue }
                if status.status == "done" {
                    await self.load()
                    self.isCrafting = false
                    Haptics.tap()
                    return
                }
                if status.status == "error" {
                    self.isCrafting = false
                    self.errorMessage = "Something went wrong crafting your adventure. Try again."
                    return
                }
            }
            self?.isCrafting = false
        }
    }

    // MARK: - Steps / completion

    func checkStep(_ order: Int) {
        guard var adv = adventure, adv.isActive,
              let idx = adv.steps.firstIndex(where: { $0.order == order }),
              !adv.steps[idx].checked else { return }

        // Optimistic check; rollback on failure (§12.1).
        adv.steps[idx].checked = true
        replaceAdventure(adv)
        Haptics.select()

        Task {
            do {
                try await AdventureAPI.shared.checkStep(adventureId: adv.id, order: order)
            } catch {
                await MainActor.run {
                    if var cur = self.adventure,
                       let i = cur.steps.firstIndex(where: { $0.order == order }) {
                        cur.steps[i].checked = false
                        self.replaceAdventure(cur)
                    }
                    self.errorMessage = "Couldn't save that step — check your connection."
                }
            }
        }
    }

    func complete() async {
        guard let adv = adventure, adv.allStepsChecked else { return }
        do {
            let resp = try await AdventureAPI.shared.complete(adventureId: adv.id)
            celebrationPoints = resp.pointsAwarded
            pointsBalance = resp.pointsBalance
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
