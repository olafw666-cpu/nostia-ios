import SwiftUI

/// Cosmetic theme store (Adventure Page spec §9). Points are earned-only —
/// no purchasing, no transfers, no cash value; the server gates unlock state
/// and this screen applies unlocked palettes via `ThemeManager.accentTheme`.
struct ThemeStoreView: View {
    let balance: Int
    var onBalanceChanged: (() -> Void)? = nil

    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.dismiss) private var dismiss

    @State private var catalog: CosmeticCatalog?
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var confirmItem: CosmeticItem?
    @State private var isPurchasing = false

    private var liveBalance: Int { catalog?.pointsBalance ?? balance }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    balanceCard

                    Text("Profile Themes")
                        .font(.nostiaDisplay(19, weight: .heavy))
                        .foregroundColor(Color.nostiaTextPrimary)

                    // Stock palette — always owned, lets the user switch back.
                    themeRow(theme: .stock, item: nil)

                    if isLoading {
                        ProgressView().frame(maxWidth: .infinity).padding(.top, 30)
                    } else if let catalog {
                        ForEach(catalog.items) { item in
                            if let theme = AccentTheme.forCosmeticKey(item.key) {
                                themeRow(theme: theme, item: item)
                            }
                        }
                    }

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.nostiaBody(13))
                            .foregroundColor(Color.nostriaDanger)
                    }

                    Text("Earn points by completing daily adventures. Themes are one-time unlocks tied to your account.")
                        .font(.nostiaBody(12))
                        .foregroundColor(Color.nostiaTextMuted)
                        .padding(.top, 4)
                }
                .padding(18)
            }
            .background(Color.nostiaBackground.ignoresSafeArea())
            .navigationTitle("Theme Store")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
                        .foregroundColor(Color.nostiaAccent)
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
        }
        .task { await load() }
        .alert(
            "Unlock this theme?",
            isPresented: Binding(
                get: { confirmItem != nil },
                set: { if !$0 { confirmItem = nil } }
            ),
            presenting: confirmItem
        ) { item in
            Button("Unlock") { Task { await purchase(item) } }
            Button("Cancel", role: .cancel) {}
        } message: { item in
            Text("\(AccentTheme.forCosmeticKey(item.key)?.label ?? item.key) costs \(item.price) points. You have \(liveBalance).")
        }
    }

    private var balanceCard: some View {
        HStack(spacing: 10) {
            Image(systemName: "star.circle.fill")
                .font(.nostiaBody(28))
                .foregroundColor(Color.nostiaStar)
            VStack(alignment: .leading, spacing: 2) {
                Text("\(liveBalance)")
                    .font(.nostiaDisplay(24, weight: .heavy))
                    .foregroundColor(Color.nostiaTextPrimary)
                Text("adventure points")
                    .font(.nostiaBody(12))
                    .foregroundColor(Color.nostiaTextSecond)
            }
            Spacer()
        }
        .padding(16)
        .nostiaWarmCard(cornerRadius: 18)
    }

    /// One row per palette: swatch, name, and the contextual action —
    /// Applied / Apply / price / not-enough-points.
    private func themeRow(theme: AccentTheme, item: CosmeticItem?) -> some View {
        let owned = item == nil || item?.owned == true
        let applied = themeManager.accentTheme == theme
        let affordable = item.map { liveBalance >= $0.price } ?? true

        return HStack(spacing: 14) {
            // Swatch: the palette's light+dark accents side by side.
            HStack(spacing: 0) {
                Color(hex: theme.accentLight)
                Color(hex: theme.accentDark)
            }
            .frame(width: 44, height: 44)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.nostiaCardStroke, lineWidth: 0.75)
            )

            VStack(alignment: .leading, spacing: 2) {
                Text(theme.label)
                    .font(.nostiaBody(15, weight: .bold))
                    .foregroundColor(Color.nostiaTextPrimary)
                if let item, !owned {
                    Text("\(item.price) points")
                        .font(.nostiaBody(12))
                        .foregroundColor(affordable ? Color.nostiaTextSecond : Color.nostriaDanger)
                } else {
                    Text(applied ? "Applied" : "Unlocked")
                        .font(.nostiaBody(12))
                        .foregroundColor(applied ? Color.nostiaSuccess : Color.nostiaTextSecond)
                }
            }
            Spacer()

            if applied {
                Image(systemName: "checkmark.circle.fill")
                    .font(.nostiaBody(22))
                    .foregroundColor(Color.nostiaSuccess)
            } else if owned {
                Button {
                    Haptics.tap()
                    themeManager.accentTheme = theme
                } label: {
                    Text("Apply")
                        .font(.nostiaBody(13, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Capsule().fill(Color.nostiaAccent))
                }
                .buttonStyle(.nostiaTap)
            } else if let item {
                Button {
                    Haptics.tap()
                    confirmItem = item
                } label: {
                    Text("Unlock")
                        .font(.nostiaBody(13, weight: .bold))
                        .foregroundColor(affordable ? Color.nostiaAccent : Color.nostiaTextMuted)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Capsule().fill(Color.nostiaButton))
                        .overlay(Capsule().stroke(Color.nostiaCardStroke, lineWidth: 0.75))
                }
                .buttonStyle(.nostiaTap)
                .disabled(!affordable || isPurchasing)
            }
        }
        .padding(14)
        .nostiaCard(cornerRadius: 16)
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            catalog = try await AdventureAPI.shared.getCosmetics()
        } catch {
            errorMessage = "Couldn't load the store — try again later."
        }
    }

    private func purchase(_ item: CosmeticItem) async {
        guard !isPurchasing else { return }
        isPurchasing = true
        defer { isPurchasing = false }
        errorMessage = nil
        do {
            _ = try await AdventureAPI.shared.purchase(itemId: item.id)
            await load()
            onBalanceChanged?()
            Haptics.tap()
        } catch let APIError.httpError(statusCode, message) {
            errorMessage = statusCode == 402 ? "Not enough points yet — keep adventuring!" : message
            await load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
