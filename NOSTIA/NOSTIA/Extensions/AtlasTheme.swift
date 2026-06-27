import SwiftUI

// MARK: - Atlas (Light) design system
//
// Recreates the "Atlas (Light)" redesign: a soft off-white canvas with solid white
// cards, gentle drop shadows, JetBrains-Mono-style monospaced display type, a green
// primary and orange star accent.
//
// `nostiaCard(in:)` is a drop-in replacement for the system `glassEffect(in:)`
// modifier the app previously used — same call shape, but renders an opaque white
// surface with a soft shadow instead of translucent Liquid Glass.

extension View {
    /// Atlas surface: white fill, hairline border and a soft drop shadow, clipped to
    /// `shape`. Drop-in replacement for the system `glassEffect(in:)` modifier.
    func nostiaCard<S: Shape>(in shape: S, elevation: NostiaElevation = .card) -> some View {
        self
            .background(Color.nostiaCard)
            .clipShape(shape)
            .overlay(shape.stroke(Color.nostiaShadow.opacity(0.06), lineWidth: 0.5))
            .shadow(color: Color.nostiaShadow.opacity(elevation.opacity),
                    radius: elevation.radius, x: 0, y: elevation.y)
    }

    /// Convenience for the common rounded-rectangle case.
    func nostiaCard(cornerRadius: CGFloat, elevation: NostiaElevation = .card) -> some View {
        nostiaCard(in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous),
                   elevation: elevation)
    }
}

/// Shadow presets matching the Atlas mock (`box-shadow` values are rgba(30,50,70,…)).
enum NostiaElevation {
    case flat       // chips / inline controls — barely-there lift
    case card       // standard content card
    case raised     // hero / total cards, floating sheets

    var opacity: Double {
        switch self {
        case .flat:   return 0.05
        case .card:   return 0.06
        case .raised: return 0.10
        }
    }
    var radius: CGFloat {
        switch self {
        case .flat:   return 8
        case .card:   return 14
        case .raised: return 24
        }
    }
    var y: CGFloat {
        switch self {
        case .flat:   return 2
        case .card:   return 4
        case .raised: return 12
        }
    }
}

// MARK: - Typography

extension Font {
    /// Display / heading type — monospaced to echo the mock's JetBrains Mono titles.
    static func nostiaDisplay(_ size: CGFloat, weight: Font.Weight = .heavy) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }
    /// Body / supporting type.
    static func nostiaBody(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight)
    }
}

// MARK: - Label style

/// Atlas rows frequently pair a tinted leading icon with neutral text
/// ("👥 3 members"). This keeps the icon colour independent of the label colour.
struct AtlasLeadingIconLabel: LabelStyle {
    var tint: Color
    var spacing: CGFloat = 6
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: spacing) {
            configuration.icon.foregroundColor(tint)
            configuration.title
        }
    }
}

// MARK: - Reusable Atlas components

/// The pill "search bar" affordance used on Home / Explore / Following etc. Tapping it
/// runs `action` (most screens drive a real search field from here).
struct NostiaSearchBar: View {
    let placeholder: String
    var action: (() -> Void)? = nil

    var body: some View {
        Button { action?() } label: {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 18))
                    .foregroundColor(Color.nostiaTextMuted)
                Text(placeholder)
                    .font(.nostiaBody(15))
                    .foregroundColor(Color.nostiaTextMuted)
                Spacer()
            }
            .padding(.horizontal, 16)
            .frame(height: 48)
            .nostiaCard(cornerRadius: 15)
        }
        .buttonStyle(.plain)
        .disabled(action == nil)
    }
}

/// A real, editable Atlas search field (white pill). Use where the search bar must work.
struct NostiaSearchField: View {
    let placeholder: String
    @Binding var text: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 18))
                .foregroundColor(Color.nostiaTextMuted)
            TextField(placeholder, text: $text)
                .font(.nostiaBody(15))
                .foregroundColor(Color.nostiaTextPrimary)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
            if !text.isEmpty {
                Button { text = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(Color.nostiaTextMuted)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .frame(height: 48)
        .nostiaCard(cornerRadius: 15)
    }
}

/// Rounded category / filter chip. Green when active, white when not.
struct NostiaChip: View {
    let label: String
    let isActive: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.nostiaDisplay(13, weight: .bold))
                .foregroundColor(isActive ? .white : Color(hex: "4B5563"))
                .padding(.horizontal, 15)
                .padding(.vertical, 9)
                .background(
                    Capsule().fill(isActive ? Color.nostiaAccent : Color.nostiaCard)
                )
                .shadow(color: Color.nostiaShadow.opacity(0.08), radius: 8, x: 0, y: 2)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isActive ? [.isButton, .isSelected] : .isButton)
    }
}

/// Section header used above horizontal rows ("Trending near you · See all").
struct NostiaRowHeader: View {
    let title: String
    var actionTitle: String? = "See all"
    var action: (() -> Void)? = nil

    var body: some View {
        HStack {
            Text(title)
                .font(.nostiaDisplay(19, weight: .heavy))
                .foregroundColor(Color.nostiaTextPrimary)
            Spacer()
            if let actionTitle {
                Button { action?() } label: {
                    HStack(spacing: 2) {
                        Text(actionTitle)
                            .font(.system(size: 13, weight: .bold))
                        Image(systemName: "chevron.right")
                            .font(.system(size: 13, weight: .bold))
                    }
                    .foregroundColor(Color.nostiaAccent)
                }
                .buttonStyle(.plain)
                .disabled(action == nil)
            }
        }
    }
}

/// iOS-style segmented control in Atlas dressing (grey track, white selected pill).
struct AtlasSegmented: View {
    let segments: [String]
    @Binding var selection: Int

    var body: some View {
        HStack(spacing: 6) {
            ForEach(Array(segments.enumerated()), id: \.offset) { index, title in
                let on = selection == index
                Button { Haptics.select(); selection = index } label: {
                    Text(title)
                        .font(.system(size: 14, weight: on ? .bold : .semibold))
                        .foregroundColor(on ? Color.nostiaTextPrimary : Color.nostiaTextSecond)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(on ? Color.nostiaCard : Color.clear)
                                .shadow(color: on ? Color.nostiaShadow.opacity(0.06) : .clear, radius: 4, y: 1)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(5)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color(hex: "E7ECF1")))
    }
}

/// Large title used at the top of standalone tabs (Explore, Vaults, Following…).
struct NostiaScreenTitle: View {
    let title: String
    var body: some View {
        Text(title)
            .font(.nostiaDisplay(27, weight: .heavy))
            .foregroundColor(Color.nostiaTextPrimary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Primary green pill button (full-width CTA).
struct NostiaPrimaryButton: View {
    let title: String
    var systemImage: String? = nil
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let systemImage { Image(systemName: systemImage).font(.system(size: 18, weight: .semibold)) }
                Text(title).font(.system(size: 16, weight: .bold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.nostiaAccent))
        }
        .buttonStyle(.plain)
    }
}
