import Foundation
import SwiftUI

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
            plan = p
            deadZoneReason = nil
        } else {
            // §13 dead zone: honest empty state, never a fake plan.
            plan = nil
            deadZoneReason = resp.reason ?? "Nothing composable nearby right now."
        }
    }
}
