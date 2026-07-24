import SwiftUI

/// Verified vs Suggested map pins (Product Definition v2 §7).
///
/// The two classes are **different shapes, not just different colors** — a
/// user must be able to tell a machine's guess from a place three of their
/// friends actually went, at a glance, without a legend. Verified is a
/// seal/badge silhouette; Suggested is a plain hollow circle that reads as
/// provisional.
struct VerifiedPlacePin: View {
    let pin: PlacePin

    var body: some View {
        VStack(spacing: 2) {
            ZStack {
                // Seal silhouette — deliberately not a circle.
                Image(systemName: "seal.fill")
                    .font(.system(size: 34))
                    .foregroundStyle(Color.nostiaAccent)
                    .shadow(color: Color.nostiaShadow.opacity(0.3), radius: 4, y: 2)
                Image(systemName: pin.symbolName)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
            }
            if pin.verifiedCompletions > 1 {
                Text("\(pin.verifiedCompletions)")
                    .font(.nostiaBody(10, weight: .heavy))
                    .foregroundColor(.white)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .background(Capsule().fill(Color.nostiaAccent))
            }
        }
        .accessibilityLabel(
            pin.socialProof.map { "\(pin.name), verified. \($0)" }
                ?? "\(pin.name), verified by \(pin.verifiedCompletions) completions"
        )
    }
}

struct SuggestedPlacePin: View {
    let pin: PlacePin

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.nostiaCard.opacity(0.92))
                .frame(width: 24, height: 24)
            Circle()
                .strokeBorder(Color.nostiaTextMuted, style: StrokeStyle(lineWidth: 1.5, dash: [3, 2]))
                .frame(width: 24, height: 24)
            Image(systemName: pin.symbolName)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(Color.nostiaTextSecond)
        }
        .accessibilityLabel("\(pin.name), suggested — nobody has been yet")
    }
}

/// Callout body shown when a pin is tapped. The social-proof line is the
/// entire reason to open this map instead of Google's, so it gets top billing
/// on verified pins — and is simply absent when it isn't true.
struct PlacePinCallout: View {
    let pin: PlacePin
    let onReportClosed: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(pin.name)
                .font(.nostiaBody(16, weight: .bold))
                .foregroundColor(Color.nostiaTextPrimary)

            if let proof = pin.socialProof {
                HStack(spacing: 6) {
                    Image(systemName: "person.2.fill")
                        .font(.nostiaBody(12, weight: .semibold))
                        .foregroundColor(Color.nostiaAccent)
                    Text(proof)
                        .font(.nostiaBody(13, weight: .semibold))
                        .foregroundColor(Color.nostiaAccent)
                        .fixedSize(horizontal: false, vertical: true)
                }
            } else if pin.isVerified {
                Text("\(pin.verifiedCompletions) completed this")
                    .font(.nostiaBody(13))
                    .foregroundColor(Color.nostiaTextSecond)
            } else {
                Text("Nobody's been yet — could be yours")
                    .font(.nostiaBody(13))
                    .foregroundColor(Color.nostiaTextSecond)
            }

            Button(role: .destructive, action: onReportClosed) {
                Text("Report as closed")
                    .font(.nostiaBody(12, weight: .semibold))
            }
            .buttonStyle(.nostiaTap)
        }
        .padding(12)
        .frame(maxWidth: 240, alignment: .leading)
    }
}

// MARK: - Model

struct PlacePin: Codable, Identifiable, Equatable {
    let placeId: Int
    let name: String
    let lat: Double
    let lng: Double
    let category: String?
    let pinClass: String       // verified | suggested
    let verifiedCompletions: Int
    let distinctUsers: Int
    /// Server-computed and viewer-specific ("3 people you follow completed
    /// this"). Never synthesized client-side — if it's absent, it isn't true.
    let socialProof: String?

    var id: Int { placeId }
    var isVerified: Bool { pinClass == "verified" }

    enum CodingKeys: String, CodingKey {
        case name, lat, lng, category
        case placeId = "place_id"
        case pinClass = "pin_class"
        case verifiedCompletions = "verified_completions"
        case distinctUsers = "distinct_users"
        case socialProof = "social_proof"
    }

    /// Same bucket vocabulary the plan stops use (poi_category_map.json).
    var symbolName: String {
        switch category {
        case "coffee": return "cup.and.saucer.fill"
        case "dessert": return "birthday.cake.fill"
        case "bar": return "wineglass.fill"
        case "food": return "fork.knife"
        case "park": return "tree.fill"
        case "scenic": return "mountain.2.fill"
        case "culture": return "theatermasks.fill"
        case "activity": return "figure.bowling"
        case "shop": return "bag.fill"
        default: return "mappin"
        }
    }
}

struct PlacePinsResponse: Codable {
    let pins: [PlacePin]
    let verifiedCount: Int
    let suggestedCount: Int

    enum CodingKeys: String, CodingKey {
        case pins
        case verifiedCount = "verified_count"
        case suggestedCount = "suggested_count"
    }
}
