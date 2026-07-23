import SwiftUI

/// First-login walkthrough for brand-new accounts. `AuthViewModel.register` sets the
/// `nostia_pending_app_tour` flag; `RootView` shows this once the profile-builder and
/// payment-setup covers have finished (and replays it via `.replayAppTour` from
/// Settings → Help). Each page switches the real tab behind the scrim, so the user is
/// looking at the actual screen being described — not a mockup of it.
struct AppTourView: View {
    @EnvironmentObject private var deepLinkRouter: DeepLinkRouter
    let onFinish: () -> Void

    @State private var pageIndex = 0

    private struct TourPage {
        let icon: String
        let title: String
        let rows: [(icon: String, text: String)]
        /// Tab shown behind the scrim while this page is up (v2 IA:
        /// Adventure 0 · Friends 1).
        let tab: Int
    }

    // Three pages, matching the product (v2 §3): start an adventure, show up
    // to verify it, bring your people. Short on purpose — the activation
    // budget is 90 seconds and the plan is the pitch, not the tour.
    private static let pages: [TourPage] = [
        TourPage(
            icon: "sparkles",
            title: "Start an adventure",
            rows: [
                ("wand.and.stars", "One tap composes a real plan from where you're standing — a few stops, short walks, timed out."),
                ("arrow.triangle.2.circlepath", "Not feeling it? Reroll. It's free, and the next plan is always different."),
                ("map.fill", "Flip the List/Map toggle to see everything around you."),
            ],
            tab: 0
        ),
        TourPage(
            icon: "checkmark.seal.fill",
            title: "Show up to make it count",
            rows: [
                ("location.fill", "At each stop, tap \"I'm here\" — hang out a minute and the stop verifies itself."),
                ("camera.fill", "Add a photo if you want the night remembered; rate the plan when you're done."),
                ("star.circle.fill", "Verified stops earn points — spend them in the theme store."),
            ],
            tab: 0
        ),
        TourPage(
            icon: "person.2.fill",
            title: "Bring your people",
            rows: [
                ("square.text.square.fill", "The Friends tab holds your feed — your people and your area, nothing else."),
                ("person.crop.circle.badge.plus", "Find friends by search or Contacts; orgs and crash pads live under Community."),
                ("wallet.bifold.fill", "Splitting costs? A vault lives right inside your plan."),
            ],
            tab: 1
        ),
    ]

    private var page: TourPage { Self.pages[pageIndex] }
    private var isLastPage: Bool { pageIndex == Self.pages.count - 1 }

    var body: some View {
        ZStack {
            // Dim + swallow touches so the live screen behind can't be poked mid-tour.
            Color.black.opacity(0.45)
                .ignoresSafeArea()
                .onTapGesture {}

            VStack(spacing: 16) {
                ZStack {
                    Circle().fill(Color.nostiaAccentSoft).frame(width: 64, height: 64)
                    Image(systemName: page.icon)
                        .font(.nostiaBody(28))
                        .foregroundColor(Color.nostiaAccent)
                }
                Text(page.title)
                    .font(.nostiaDisplay(20, weight: .heavy))
                    .foregroundColor(Color.nostiaTextPrimary)
                    .accessibilityAddTraits(.isHeader)

                VStack(alignment: .leading, spacing: 13) {
                    ForEach(page.rows, id: \.text) { row in
                        tourRow(icon: row.icon, text: row.text)
                    }
                }

                pageDots

                HStack(spacing: 10) {
                    if pageIndex > 0 {
                        Button {
                            Haptics.select()
                            goTo(pageIndex - 1)
                        } label: {
                            Text("Back")
                                .font(.nostiaBody(16, weight: .bold))
                                .foregroundColor(Color.nostiaAccent)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 13)
                                .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.nostiaAccentSoft))
                        }
                        .buttonStyle(.nostiaTap)
                    }
                    Button {
                        Haptics.tap()
                        if isLastPage { onFinish() } else { goTo(pageIndex + 1) }
                    } label: {
                        Text(isLastPage ? "Let's Go" : "Next")
                            .font(.nostiaBody(16, weight: .bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 13)
                            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.nostiaAccent))
                    }
                    .buttonStyle(.nostiaTap)
                }

                if !isLastPage {
                    Button {
                        Haptics.tap()
                        onFinish()
                    } label: {
                        Text("Skip Tour")
                            .font(.nostiaBody(14, weight: .semibold))
                            .foregroundColor(Color.nostiaTextSecond)
                            .frame(minHeight: 36)
                    }
                    .buttonStyle(.nostiaTap)
                    .accessibilityHint("Ends the tour; you can replay it from Settings")
                }
            }
            .padding(22)
            .frame(maxWidth: 380)
            .nostiaCard(in: RoundedRectangle(cornerRadius: 20), elevation: .raised)
            .padding(24)
            .animation(.easeInOut(duration: 0.2), value: pageIndex)
        }
        .transition(.opacity)
        .onAppear { showTab(for: Self.pages[0]) }
    }

    private func goTo(_ index: Int) {
        withAnimation(.easeInOut(duration: 0.2)) { pageIndex = index }
        showTab(for: Self.pages[index])
    }

    /// Bring the described screen up behind the scrim. The tour covers the
    /// map's ground too, so the one-time map intro is marked seen here.
    private func showTab(for page: TourPage) {
        deepLinkRouter.selectedTab = page.tab
        UserDefaults.standard.set(true, forKey: "hasSeenMapIntro")
    }

    private var pageDots: some View {
        HStack(spacing: 6) {
            ForEach(0..<Self.pages.count, id: \.self) { i in
                Circle()
                    .fill(i == pageIndex ? Color.nostiaAccent : Color.nostiaTextMuted.opacity(0.4))
                    .frame(width: 7, height: 7)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Page \(pageIndex + 1) of \(Self.pages.count)")
    }

    private func tourRow(icon: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.nostiaBody(18))
                .foregroundColor(Color.nostiaAccent)
                .frame(width: 26)
            Text(text)
                .font(.subheadline)
                .foregroundColor(Color.nostiaTextSecond)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
