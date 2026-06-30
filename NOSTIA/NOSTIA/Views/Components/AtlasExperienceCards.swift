import SwiftUI
import UIKit

// MARK: - Experience image

/// Renders an experience's flyer (base64) or a diagonal-stripe placeholder matching the
/// Atlas mock. Reused by every experience card variant.
struct AtlasExperienceImage: View {
    let flyerImage: String?
    var height: CGFloat = 148

    private var uiImage: UIImage? {
        guard let s = flyerImage, !s.isEmpty else { return nil }
        let raw = s.contains("base64,") ? (s.components(separatedBy: "base64,").last ?? s) : s
        guard let data = Data(base64Encoded: raw, options: .ignoreUnknownCharacters) else { return nil }
        return UIImage(data: data)
    }

    var body: some View {
        ZStack {
            if let img = uiImage {
                Color.clear.overlay(Image(uiImage: img).resizable().scaledToFill()).clipped()
            } else {
                LinearGradient(
                    colors: [Color(light: "E9EDF2", dark: "3C362E"), Color(light: "E1E6EC", dark: "302A23")],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
                .overlay(
                    Image(systemName: "photo")
                        .font(.system(size: 22))
                        .foregroundColor(Color.nostiaTextMuted)
                )
            }
        }
        .frame(height: height)
        .frame(maxWidth: .infinity)
        .clipped()
    }
}

private extension Experience {
    /// Single category label for the badge — first tag, capitalised.
    var categoryLabel: String { (tags?.first ?? "experience").capitalized }
}

// MARK: - Category badge

private struct AtlasCatBadge: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.system(size: 10.5, weight: .bold))
            .foregroundColor(Color.nostiaAccent)
            .padding(.horizontal, 10).padding(.vertical, 4)
            .background(Capsule().fill(Color.nostiaCard))
            .shadow(color: Color.black.opacity(0.08), radius: 4, y: 1)
    }
}

private struct AtlasRatingLine: View {
    let event: Experience
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "star.fill").font(.system(size: 14)).foregroundColor(Color.nostiaStar)
            if let r = event.formattedAvgRating {
                Text(r).font(.system(size: 12.5, weight: .bold)).foregroundColor(Color.nostiaTextPrimary)
            } else {
                Text("New").font(.system(size: 12.5, weight: .bold)).foregroundColor(Color.nostiaTextPrimary)
            }
            if let v = event.visitedCount, v > 0 {
                Text("· \(v) visited").font(.system(size: 12.5)).foregroundColor(Color.nostiaTextMuted)
            }
        }
    }
}

// MARK: - Mini card (horizontal rows / map sheet)

/// Fixed-width photo card used inside horizontally-scrolling rows.
struct AtlasExperienceMiniCard: View {
    let event: Experience
    var width: CGFloat = 228
    var imageHeight: CGFloat = 148

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .topLeading) {
                AtlasExperienceImage(flyerImage: event.flyerImage, height: imageHeight)
                AtlasCatBadge(text: event.categoryLabel).padding(10)
            }
            VStack(alignment: .leading, spacing: 6) {
                Text(event.title)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(Color.nostiaTextPrimary)
                    .lineLimit(2)
                AtlasRatingLine(event: event)
            }
            .padding(.horizontal, 13).padding(.top, 11).padding(.bottom, 13)
        }
        .frame(width: width, alignment: .leading)
        .nostiaCard(cornerRadius: 20)
    }
}

// MARK: - Full card (Explore feed)

/// Full-width photo card used in the Explore vertical feed.
struct AtlasExperienceCard: View {
    let event: Experience

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .topLeading) {
                AtlasExperienceImage(flyerImage: event.flyerImage, height: 168)
                AtlasCatBadge(text: event.categoryLabel).padding(12)
            }
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top, spacing: 10) {
                    Text(event.title)
                        .font(.nostiaDisplay(18, weight: .bold))
                        .foregroundColor(Color.nostiaTextPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                    HStack(spacing: 4) {
                        Image(systemName: "star.fill").font(.system(size: 16)).foregroundColor(Color.nostiaStar)
                        Text(event.formattedAvgRating ?? "New")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(Color.nostiaTextPrimary)
                    }
                }
                if let loc = event.location, !loc.isEmpty {
                    HStack(spacing: 5) {
                        Image(systemName: "mappin.and.ellipse").font(.system(size: 14))
                        Text(loc + (event.formattedDistance.map { " · \($0)" } ?? ""))
                    }
                    .font(.system(size: 13))
                    .foregroundColor(Color.nostiaTextSecond)
                    .padding(.top, 4)
                }
                if let when = event.formattedSchedule {
                    HStack(spacing: 5) {
                        Image(systemName: "calendar").font(.system(size: 14))
                        Text(when)
                    }
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Color.nostiaAccent)
                    .padding(.top, 4)
                }
                if let desc = event.description, !desc.isEmpty {
                    Text(desc)
                        .font(.system(size: 13.5))
                        .foregroundColor(Color.nostiaTextSecond)
                        .lineLimit(2)
                        .padding(.top, 8)
                }
                if let v = event.visitedCount, v > 0 {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.seal.fill").font(.system(size: 16)).foregroundColor(Color.nostiaAccent)
                        Text("\(v) people visited")
                    }
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Color.nostiaTextSecond)
                    .padding(.top, 12)
                    .overlay(alignment: .top) {
                        Rectangle().fill(Color.nostiaDivider).frame(height: 1).offset(y: 0)
                    }
                }
            }
            .padding(.horizontal, 16).padding(.top, 14).padding(.bottom, 16)
        }
        .nostiaCard(cornerRadius: 20)
    }
}
