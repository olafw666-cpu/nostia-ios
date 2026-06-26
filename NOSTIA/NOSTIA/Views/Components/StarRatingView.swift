import SwiftUI

/// Reusable star-rating control (spec §2). Two modes:
/// • Read-only — renders a decimal average with full / half / empty stars.
/// • Interactive — tap or drag to pick 0…5 in half-star steps (D3); calls `onRate`.
///
/// A 0-star rating is a real, selectable value (distinct from "unrated"); drag to the
/// far left of the row to choose it.
struct StarRatingView: View {
    /// The value to render. In interactive mode this is the user's current pick.
    var rating: Double
    var maxRating: Int = 5
    var size: CGFloat = 16
    var spacing: CGFloat = 3
    var color: Color = Color.nostiaWarning
    var isInteractive: Bool = false
    /// Called with the snapped half-star value when an interactive gesture ends.
    var onRate: ((Double) -> Void)? = nil

    // Live preview while the user is dragging, before the gesture commits.
    @State private var dragValue: Double? = nil

    private var displayRating: Double { dragValue ?? rating }
    private var starWidth: CGFloat { size + spacing }

    var body: some View {
        Group {
            if isInteractive {
                stars.gesture(dragGesture).contentShape(Rectangle())
            } else {
                stars
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(isInteractive ? "Your rating" : "Average rating")
        .accessibilityValue(String(format: "%.1f out of %d stars", displayRating, maxRating))
        .accessibilityAddTraits(isInteractive ? .isButton : [])
    }

    private var stars: some View {
        HStack(spacing: spacing) {
            ForEach(1...maxRating, id: \.self) { index in
                symbol(for: index)
                    .font(.system(size: size))
                    .foregroundColor(color)
                    .frame(width: size, height: size)
            }
        }
    }

    private func symbol(for index: Int) -> Image {
        let r = displayRating
        if r >= Double(index) {
            return Image(systemName: "star.fill")
        } else if r >= Double(index) - 0.5 {
            return Image(systemName: "star.leadinghalf.filled")
        } else {
            return Image(systemName: "star")
        }
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                dragValue = snapped(at: value.location.x)
            }
            .onEnded { value in
                let final = snapped(at: value.location.x)
                dragValue = nil
                Haptics.select()
                onRate?(final)
            }
    }

    /// Maps a horizontal touch position to the nearest half-star, clamped to 0…maxRating.
    private func snapped(at x: CGFloat) -> Double {
        let raw = Double(x / starWidth)
        let half = (raw * 2).rounded() / 2
        return min(max(half, 0), Double(maxRating))
    }
}

/// Compact read-only "★ 2.5 (100)" badge used on cards and the detail sheet (D4).
struct AverageRatingBadge: View {
    let avgRating: Double?
    let ratingCount: Int?
    var starSize: CGFloat = 13
    var showCount: Bool = true

    var body: some View {
        if let avg = avgRating, (ratingCount ?? 0) > 0 {
            HStack(spacing: 4) {
                Image(systemName: "star.fill")
                    .font(.system(size: starSize))
                    .foregroundColor(Color.nostiaWarning)
                Text(String(format: "%.1f", avg))
                    .font(.caption.bold())
                    .foregroundColor(.white)
                if showCount, let count = ratingCount {
                    Text("(\(count))")
                        .font(.caption2)
                        .foregroundColor(Color.nostiaTextMuted)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(
                String(format: "Average rating %.1f out of 5, from %d ratings", avg, ratingCount ?? 0)
            )
        }
    }
}
