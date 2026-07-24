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

    func loadCurrent() async {
        do {
            let resp = try await api.current()
            if let live = resp.plan, live.isLive { plan = live } else { plan = nil }
        } catch {
            // Load failures stay quiet — the CTA still works, which is the product.
            print("plan current failed: \(error)")
        }
    }

    /// §4: location asked in context → compose → plan in hand. Under 90 seconds
    /// from first open means this path must never stall on optional steps.
    func startAdventure() async {
        guard !isWorking else { return }
        isWorking = true
        errorMessage = nil
        deadZoneReason = nil
        defer { isWorking = false }

        guard let loc = await LocationManager.shared.acquireLocation() else {
            locationDenied = true
            return
        }
        locationDenied = false

        do {
            let resp = try await api.generate(
                lat: loc.coordinate.latitude,
                lng: loc.coordinate.longitude,
                vibe: selectedVibe?.rawValue
            )
            apply(resp)
            if plan != nil { showDetail = true }
        } catch {
            errorMessage = "Couldn't put a plan together. Try again."
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
            if isNewPlan {
                MapKitEnrichmentService.shared.clearMemo()
                Task { await validateRenderedStops() }
            }
        } else {
            // §13 dead zone: honest empty state, never a fake plan.
            plan = nil
            deadZoneReason = resp.reason ?? "Nothing composable nearby right now."
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
