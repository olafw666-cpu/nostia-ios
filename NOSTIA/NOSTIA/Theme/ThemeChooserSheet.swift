import SwiftUI

/// One-time popup shown after first login inviting the user to confirm or change their
/// appearance. Selecting an option applies it instantly; the choice is remembered and the
/// prompt never reappears. Theme can always be changed later in Settings → Appearance.
struct ThemeChooserSheet: View {
    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 22) {
            VStack(spacing: 10) {
                Image(systemName: "circle.lefthalf.filled")
                    .font(.nostiaBody(42))
                    .foregroundColor(Color.nostiaAccent)
                Text("Choose your look")
                    .font(.nostiaDisplay(22, weight: .heavy))
                    .foregroundColor(Color.nostiaTextPrimary)
                Text("Nostia opens in Dark by default. Pick what suits you — you can change it anytime in Settings.")
                    .font(.nostiaBody(14))
                    .foregroundColor(Color.nostiaTextSecond)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 8)

            VStack(spacing: 10) {
                ForEach(AppTheme.allCases) { option in
                    themeOption(option)
                }
            }

            NostiaPrimaryButton(title: "Done") { dismiss() }
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .center)
        .presentationDetents([.height(540)])
        .presentationDragIndicator(.visible)
    }

    @ViewBuilder
    private func themeOption(_ option: AppTheme) -> some View {
        let selected = themeManager.theme == option
        Button {
            Haptics.select()
            themeManager.theme = option
        } label: {
            HStack(spacing: 14) {
                Image(systemName: option.icon)
                    .font(.nostiaBody(19))
                    .frame(width: 26)
                    .foregroundColor(selected ? .white : Color.nostiaAccent)
                VStack(alignment: .leading, spacing: 2) {
                    Text(option.label)
                        .font(.nostiaBody(16, weight: .bold))
                    Text(option.blurb)
                        .font(.nostiaBody(12))
                        .foregroundColor(selected ? .white.opacity(0.85) : Color.nostiaTextSecond)
                }
                Spacer()
                if selected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.nostiaBody(20))
                        .foregroundColor(.white)
                }
            }
            .foregroundColor(selected ? .white : Color.nostiaTextPrimary)
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(selected ? Color.nostiaAccent : Color.nostiaCard)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.nostriaBorder, lineWidth: selected ? 0 : 1)
            )
        }
        .buttonStyle(.nostiaTap)
        .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
    }
}
