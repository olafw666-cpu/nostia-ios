import Foundation
import MapKit

/// Live enrichment (Product Definition v2 §5). The durable `places` layer knows
/// a venue exists; only a live source knows whether it's open right now. Apple
/// MapKit answers that on-device, for free, with no API key.
///
/// **The ToS boundary is absolute: enrichment is session-scoped display only.**
/// Nothing returned here is serialized, persisted, or sent to the server — the
/// server only ever hears the *verdict* (a recompose request), never the data.
/// The in-memory memo means a venue enriched twice in one session is one
/// lookup (§11 cost rule), and the whole cache dies with the process.
///
/// Cost is capped by construction: `enrich` is called only for stops actually
/// rendered, never for the candidates the composer considered.
protocol EnrichmentProvider {
    func enrich(name: String, lat: Double, lng: Double) async -> EnrichmentResult
}

struct EnrichmentResult {
    enum Liveness {
        case open           // matched and open at lookup time
        case closedNow      // matched, currently closed
        case notFound       // no plausible match near the coordinates
        case unknown        // lookup failed / no hours published — never a fail signal
    }

    let liveness: Liveness
    let matchedName: String?

    /// Only a confident negative should cost a user their stop. `unknown`
    /// (the lookup itself failed) must never trigger a recompose.
    var shouldRecompose: Bool {
        liveness == .closedNow || liveness == .notFound
    }

    /// Reason string sent to the recompose endpoint. `closed` also files a
    /// dead-venue report toward the server's tombstone threshold.
    var recomposeReason: String {
        switch liveness {
        case .notFound: return "closed_or_missing"
        case .closedNow: return "closed_now"
        default: return "unknown"
        }
    }

    var displayNote: String? {
        switch liveness {
        case .open: return nil
        case .closedNow: return "Closed right now"
        case .notFound: return "Couldn't find this one"
        case .unknown: return nil
        }
    }
}

@MainActor
final class MapKitEnrichmentService: EnrichmentProvider {
    static let shared = MapKitEnrichmentService()
    private init() {}

    /// Session-scoped memo, keyed by place id when known (§11: the same venue
    /// enriched twice in one session is one call). Never written to disk.
    private var memo: [String: EnrichmentResult] = [:]

    /// Match tolerance: a POI row and MapKit rarely agree to the metre.
    private let matchRadiusMeters: CLLocationDistance = 120

    func enrich(placeId: Int?, name: String, lat: Double, lng: Double) async -> EnrichmentResult {
        let key = placeId.map(String.init) ?? "\(name)@\(lat),\(lng)"
        if let cached = memo[key] { return cached }
        let result = await enrich(name: name, lat: lat, lng: lng)
        memo[key] = result
        return result
    }

    func enrich(name: String, lat: Double, lng: Double) async -> EnrichmentResult {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = name
        request.region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: lat, longitude: lng),
            latitudinalMeters: 400,
            longitudinalMeters: 400
        )

        do {
            let response = try await MKLocalSearch(request: request).start()
            let origin = CLLocation(latitude: lat, longitude: lng)
            let match = response.mapItems.first { item in
                guard let coord = item.placemark.location else { return false }
                return coord.distance(from: origin) <= matchRadiusMeters
            }

            guard let match else {
                // Apple's live index doesn't know this venue at these
                // coordinates. That is the signal that matters most: a plan
                // routing someone to a permanently shut café is the uninstall
                // case (§5). Drop it and recompose.
                return EnrichmentResult(liveness: .notFound, matchedName: nil)
            }
            // Matched: the venue is live. Open/closed hours are NOT read here —
            // MapKit's opening-hours surface isn't stable across the SDKs we
            // build against, and a wrong "closed" costs a user their stop.
            // Stored source hours (places.hours_json) already gate composition
            // server-side; this call is the existence check.
            return EnrichmentResult(liveness: .open, matchedName: match.name)
        } catch {
            // A failed lookup is not evidence of a closed venue.
            return EnrichmentResult(liveness: .unknown, matchedName: nil)
        }
    }

    /// Called when a plan is replaced so a long session can't grow unbounded.
    func clearMemo() { memo.removeAll() }
}
