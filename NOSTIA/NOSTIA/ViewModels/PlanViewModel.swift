import Foundation
import SwiftUI
import Combine
import CoreLocation

/// Drives the composed-plan surface (Product Definition v2 §4). One primary
/// action — start an adventure — with optional, defaulted refinements. The
/// location permission ask happens inside `startAdventure()` (in context, at
/// the tap that needs it), never at signup or app launch.
@MainActor
final class PlanViewModel: ObservableObject {
    @Published var plan: AdventurePlan?
    @Published var isWorking = false
    @Published var deadZoneReason: String?
    /// True when the server said the problem is coverage, not this block —
    /// nothing the user does here (widening, rerolling, waiting) will help, so
    /// the copy is presented as information rather than a retryable hiccup.
    @Published var isOutOfRegion = false
    /// The dead zone's answer instead of a dead end: a location-free adventure
    /// the user can do from wherever they're standing. Set together with
    /// `deadZoneReason`; the reason explains, this is the thing to go and do.
    @Published var anywhere: AnywhereAdventure?
    @Published var errorMessage: String?
    @Published var locationDenied = false
    @Published var selectedVibe: PlanVibe?
    @Published var showDetail = false
    /// Surfaced when the live-validation pass changed the plan under the user
    /// — they must never find a swapped stop without being told why.
    @Published var validationNote: String?
    /// Invite state (§4.6): suggestions ride along with the plan itself.
    @Published var inviteSuggestions: [InviteSuggestion] = []
    @Published var invitedUserIds: Set<Int> = []
    @Published var shareLink: ShareTarget?

    private let api = PlansAPI.shared
    /// Origin of the last generate, kept so "show me another" doesn't re-acquire
    /// a location it already has.
    private var lastOrigin: CLLocationCoordinate2D?
    /// Cursor through the anywhere pool. Only ever moved by an explicit "show me
    /// another": re-tapping the main CTA in a dead zone must not silently hand
    /// back an adventure they already skipped past.
    private var anywhereSkip = 0

    /// How long the start tap must visibly be working before the adventure lands.
    ///
    /// Composition is deterministic and server-local — no model call — so a plan
    /// comes back in a couple hundred milliseconds and the sheet is up before the
    /// tap has finished registering as a tap. This is a FLOOR on the working
    /// state, not a sleep bolted onto the front: a request that already took
    /// longer than this waits no extra time at all.
    private static let minimumWorkingSeconds: Double = 1.4

    /// Hold the spinner until `startedAt` is `minimumWorkingSeconds` old.
    private func holdWorkingState(since startedAt: Date) async {
        let elapsed = Date().timeIntervalSince(startedAt)
        guard elapsed < Self.minimumWorkingSeconds else { return }
        let remaining = Self.minimumWorkingSeconds - elapsed
        try? await Task.sleep(nanoseconds: UInt64(remaining * 1_000_000_000))
    }

    func loadCurrent() async {
        do {
            let resp = try await api.current()
            if let live = resp.plan, live.isLive { plan = live } else { plan = nil }
        } catch {
            // Load failures stay quiet — the CTA still works, which is the product.
            NostiaLog.error("Plan", "current failed: \(error)")
        }
    }

    /// §4: location asked in context → compose → plan in hand. Under 90 seconds
    /// from first open means this path must never stall on optional steps.
    func startAdventure() async {
        guard !isWorking else { return }
        isWorking = true
        errorMessage = nil
        deadZoneReason = nil
        let startedAt = Date()
        defer { isWorking = false }

        // The permission prompt is deliberately outside the hold: a denial is an
        // answer, and making the user watch a spinner for it would be theatre.
        guard let loc = await LocationManager.shared.acquireLocation() else {
            locationDenied = true
            return
        }
        locationDenied = false
        lastOrigin = loc.coordinate

        do {
            let resp = try await api.generate(
                lat: loc.coordinate.latitude,
                lng: loc.coordinate.longitude,
                vibe: selectedVibe?.rawValue,
                anywhereSkip: anywhereSkip
            )
            // Held before apply, never after: the plan and the sheet have to
            // arrive together, or the card flashes in and the sheet chases it.
            await holdWorkingState(since: startedAt)
            apply(resp)
            if plan != nil { showDetail = true }
        } catch {
            await holdWorkingState(since: startedAt)
            errorMessage = "Couldn't put a plan together. Try again."
        }
    }

    /// Reroll's equivalent for the dead zone. There is no plan row to reroll out
    /// here, so this re-asks generate with the pool cursor moved on — which also
    /// means a user who has since walked into coverage gets a real plan instead,
    /// handled by `apply` like any other response.
    func anotherAnywhere() async {
        guard !isWorking else { return }
        isWorking = true
        errorMessage = nil
        defer { isWorking = false }

        var resolved = lastOrigin
        if resolved == nil {
            resolved = (await LocationManager.shared.acquireLocation())?.coordinate
        }
        guard let origin = resolved else {
            locationDenied = true
            return
        }
        lastOrigin = origin
        anywhereSkip += 1

        do {
            let resp = try await api.generate(
                lat: origin.latitude,
                lng: origin.longitude,
                vibe: selectedVibe?.rawValue,
                anywhereSkip: anywhereSkip
            )
            apply(resp)
            if plan != nil { showDetail = true }
        } catch {
            // The card they're already holding stays — a failed swap is not a
            // reason to take away the thing they had to do.
            errorMessage = "Couldn't load another one. Try again."
        }
    }

    /// Rejecting a plan costs one tap and nothing else (§4.7).
    func reroll() async {
        guard let current = plan, current.isGenerated, !isWorking else { return }
        isWorking = true
        defer { isWorking = false }
        do {
            apply(try await api.reroll(planId: current.id))
        } catch {
            errorMessage = "Reroll didn't take. Try again."
        }
    }

    func accept() async {
        guard let current = plan, current.isGenerated else { return }
        do {
            apply(try await api.accept(planId: current.id))
        } catch {
            errorMessage = "Couldn't save the plan. Try again."
        }
    }

    private func apply(_ resp: PlanResponse) {
        if let p = resp.plan {
            let isNewPlan = plan?.id != p.id
            plan = p
            deadZoneReason = nil
            isOutOfRegion = false
            anywhere = nil
            if isNewPlan {
                MapKitEnrichmentService.shared.clearMemo()
                Task { await validateRenderedStops() }
            }
        } else {
            // §13 dead zone: honest empty state, never a fake plan — but not an
            // empty screen either. The server attaches a location-free adventure
            // so the tap still ends in something to do; keep the one we're
            // already showing if this response didn't carry one.
            plan = nil
            deadZoneReason = resp.reason ?? "Nothing composable nearby right now."
            isOutOfRegion = resp.code == "out_of_region"
            if let fallback = resp.anywhere { anywhere = fallback }
        }
    }

    // MARK: - Live validation (§5)

    /// Render-time liveness pass over the stops actually shown — never the
    /// candidates the composer considered, which is what caps enrichment cost
    /// (§11). A confident negative drops the stop and asks the server to
    /// recompose; anything uncertain leaves the plan alone.
    func validateRenderedStops() async {
        guard let current = plan, current.isLive else { return }
        for stop in current.stops where stop.status == "planned" && stop.completedByMe != true {
            let result = await MapKitEnrichmentService.shared.enrich(
                placeId: stop.placeId, name: stop.name, lat: stop.lat, lng: stop.lng
            )
            guard result.shouldRecompose else { continue }
            do {
                let resp = try await PlansAPI.shared.recompose(
                    planId: current.id, stopId: stop.id, reason: result.recomposeReason
                )
                plan = resp.plan
                validationNote = resp.swapped
                    ? "\(stop.name) looked closed — swapped it out."
                    : "\(stop.name) looked closed, and there was nothing else close by. Dropped it."
                // The plan changed underneath us; re-run against the new set.
                return await validateRenderedStops()
            } catch {
                // A failed recompose must not break the plan the user is holding.
                return
            }
        }
    }

    // MARK: - Invite (§4.6)

    /// Suggestions load with the plan, not on a later prompt — the invite row
    /// is part of the artifact. An empty result is fine and stays quiet.
    func loadInviteSuggestions() async {
        guard let current = plan, current.isLive else { return }
        do {
            let resp = try await PlansAPI.shared.inviteSuggestions(planId: current.id)
            inviteSuggestions = resp.suggestions
        } catch {
            inviteSuggestions = []
        }
    }

    func invite(_ suggestion: InviteSuggestion) async {
        guard let current = plan else { return }
        invitedUserIds.insert(suggestion.id)
        do {
            let resp = try await PlansAPI.shared.invite(planId: current.id, userId: suggestion.id)
            if let updated = resp.planUpdated { plan = updated }
            inviteSuggestions.removeAll { $0.id == suggestion.id }
            await loadInviteSuggestions()
        } catch {
            // Roll the optimistic mark back so the row can be retried.
            invitedUserIds.remove(suggestion.id)
            errorMessage = "Couldn't send that invite. Try again."
        }
    }

    func makeShareLink() async {
        guard let current = plan else { return }
        do {
            let resp = try await PlansAPI.shared.inviteLink(planId: current.id)
            shareLink = URL(string: resp.url).map(ShareTarget.init)
            await loadCurrent()
        } catch {
            errorMessage = "Couldn't make a share link. Try again."
        }
    }

    /// Join from a shared link (nostia://plan/<token>).
    func redeem(token: String) async {
        do {
            apply(try await PlansAPI.shared.redeemInvite(token: token))
            if plan != nil { showDetail = true }
        } catch {
            errorMessage = "That invite link didn't work — it may have expired."
        }
    }

    /// Explicit "this place is gone" from the user — the freshest signal the
    /// durable layer can get. Files the report, then recomposes the stop.
    func reportStopClosed(_ stop: PlanStop) async {
        guard let current = plan else { return }
        if let placeId = stop.placeId {
            try? await PlansAPI.shared.reportPlace(placeId: placeId, reason: "closed")
        }
        do {
            let resp = try await PlansAPI.shared.recompose(
                planId: current.id, stopId: stop.id, reason: "closed"
            )
            plan = resp.plan
            validationNote = resp.swapped
                ? "Thanks — swapped in somewhere else."
                : "Thanks. Nothing else nearby fit, so that stop is off the plan."
        } catch {
            validationNote = "Couldn't update the plan. Try again."
        }
    }
}
