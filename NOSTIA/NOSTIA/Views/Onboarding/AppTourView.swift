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
        /// Tab shown behind the scrim while this page is up (Atlas order:
        /// Home 0 · Adventure 1 · Vaults 2 · Map 3 · Following 4).
        let tab: Int
    }

    // Order mirrors a new user's first session: get oriented, then create,
    // discover, split costs, and follow people.
    private static let pages: [TourPage] = [
        TourPage(
            icon: "hand.wave.fill",
            title: "Welcome to Nostia",
            rows: [
                ("circle.grid.2x2.fill", "The bottom bar moves you around: Home, Adventure, Vaults, Map and Following."),
                ("bell.fill", "The bell (top right) holds your notifications; your avatar opens your profile and settings."),
                ("sparkles", "This quick tour shows you the essentials — you can skip it anytime."),
            ],
            tab: 0
        ),
        TourPage(
            icon: "house.fill",
            title: "Home",
            rows: [
                ("square.text.square.fill", "Your feed shows posts from people you follow."),
                ("wand.and.stars", "For You picks experiences happening near you."),
                ("magnifyingglass", "Search experiences, or browse rows like Outdoors and Food & Nightlife."),
            ],
            tab: 0
        ),
        TourPage(
            icon: "plus.circle.fill",
            title: "Create an Experience",
            rows: [
                ("hand.tap.fill", "Swipe to the end of For You and tap Create Experience — or press and hold anywhere on the Map."),
                ("tag.fill", "Give it a title and up to 3 tags so the right people find it."),
                ("eye.fill", "Choose who sees it — everyone, or just your followers."),
            ],
            tab: 0
        ),
        TourPage(
            icon: "map.fill",
            title: "Find It on the Map",
            rows: [
                ("mappin.circle.fill", "Every pin is an experience — tap one for details and to join in."),
                ("magnifyingglass", "Search any place or address to jump the map there."),
                ("line.3.horizontal.decrease.circle.fill", "Filter with the Public and Private pills, plus activity tags."),
            ],
            tab: 3
        ),
        TourPage(
            icon: "wallet.bifold.fill",
            title: "Vaults",
            rows: [
                ("plus.circle.fill", "Tap the + button to create a vault — a shared pot for a trip or a night out."),
                ("person.2.badge.plus", "Add people you follow, or let anyone scan the vault's QR code to join."),
                ("creditcard.fill", "Log expenses, split costs and settle up right in the app."),
            ],
            tab: 2
        ),
        TourPage(
            icon: "person.2.fill",
            title: "Add Friends",
            rows: [
                ("magnifyingglass", "Search anyone by name or username and tap Follow."),
                ("person.crop.circle.badge.plus", "Find via Contacts shows you who you already know on Nostia."),
                ("sparkles", "Check the suggestions row for people near you worth following."),
            ],
            tab: 4
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

    /// Bring the described screen up behind the scrim. Reaching the Map page also marks
    /// the one-time map intro as seen — this page covers the same ground, so letting
    /// `MapIntroOverlay` greet the user again right after the tour (or render dimmed
    /// underneath it) would be redundant.
    private func showTab(for page: TourPage) {
        deepLinkRouter.selectedTab = page.tab
        if page.tab == 3 {
            UserDefaults.standard.set(true, forKey: "hasSeenMapIntro")
        }
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
