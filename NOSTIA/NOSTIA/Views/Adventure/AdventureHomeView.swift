import SwiftUI

/// The home screen and the app's identity (Product Definition v2 §3): opens on
/// one primary action — Start an adventure — with a List/Map view toggle
/// underneath. The map is the old Map tab demoted to a toggle; the list merges
/// what the Experiences surface used to do. Vault and the theme store are
/// screens reached from here, not destinations.
struct AdventureHomeView: View {
    @EnvironmentObject private var deepLinkRouter: DeepLinkRouter
    @StateObject private var planVM = PlanViewModel()
    @State private var viewMode: ViewMode = .list
    @State private var pointsBalance = 0
    @State private var showStore = false
    @State private var nearbyExperiences: [Experience] = []
    @State private var selectedExperience: Experience?
    @State private var experienceActionsVM = ExperienceActionsViewModel()
    @State private var showSearch = false

    enum ViewMode: String, CaseIterable, Identifiable {
        case list = "List"
        case map = "Map"
        var id: String { rawValue }
    }

    var body: some View {
        Group {
            switch viewMode {
            case .list:
                listBody
            case .map:
                // The demoted map keeps everything it had as a tab — friend
                // pins, experience pins, heatmap, long-press create.
                FriendsMapView()
                    .overlay(alignment: .top) { modeToggle.padding(.top, 6) }
            }
        }
        .sheet(isPresented: $showStore) {
            ThemeStoreView(balance: pointsBalance) {
                Task { await loadPoints() }
            }
            .presentationBackground(Color.nostiaBackground)
        }
        .sheet(item: $selectedExperience) { event in
            ExperienceDetailSheet(event: event, vm: experienceActionsVM)
        }
        .sheet(isPresented: $showSearch) {
            ExperienceSearchSheet(initialTags: [])
        }
        .task {
            await planVM.loadCurrent()
            await loadPoints()
            await loadNearby()
            // A shared invite link may have arrived before this view mounted.
            consumePendingInvite(deepLinkRouter.pendingTarget)
        }
        .onChange(of: deepLinkRouter.pendingTarget) { _, target in
            consumePendingInvite(target)
        }
    }

    /// Redeem a shared plan link (§4.6). Joining is what the k-factor counts,
    /// so this path has to work from a cold launch too.
    private func consumePendingInvite(_ target: DeepLinkRouter.Target?) {
        guard case .planInvite(let token) = target else { return }
        deepLinkRouter.clear()
        Task { await planVM.redeem(token: token) }
    }

    // MARK: - List side

    private var listBody: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header

                PlanTonightSection(vm: planVM)

                modeToggle

                if !nearbyExperiences.isEmpty {
                    nearbySection
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 6)
            .padding(.bottom, 110) // clear the floating tab bar
        }
        .background(Color.nostiaBackground.ignoresSafeArea())
        .refreshable {
            await planVM.loadCurrent()
            await loadNearby()
        }
    }

    private var header: some View {
        HStack(alignment: .center) {
            NostiaScreenTitle(title: "Adventure")
            Spacer()
            Button {
                Haptics.tap()
                showStore = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "star.circle.fill")
                        .font(.nostiaBody(16, weight: .bold))
                        .foregroundColor(Color.nostiaStar)
                    Text("\(pointsBalance)")
                        .font(.nostiaDisplay(15, weight: .heavy))
                        .foregroundColor(Color.nostiaTextPrimary)
                }
                .padding(.horizontal, 13)
                .padding(.vertical, 8)
                .nostiaCard(cornerRadius: 14, elevation: .flat)
            }
            .buttonStyle(.nostiaTap)
            .accessibilityLabel("\(pointsBalance) points. Opens the theme store")
        }
    }

    private var modeToggle: some View {
        Picker("View", selection: $viewMode) {
            ForEach(ViewMode.allCases) { mode in
                Text(mode.rawValue).tag(mode)
            }
        }
        .pickerStyle(.segmented)
        .frame(maxWidth: 240)
        .frame(maxWidth: .infinity)
    }

    private var nearbySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Happening nearby")
                    .font(.nostiaDisplay(19, weight: .heavy))
                    .foregroundColor(Color.nostiaTextPrimary)
                Spacer()
                Button {
                    Haptics.tap()
                    showSearch = true
                } label: {
                    Text("Search")
                        .font(.nostiaBody(14, weight: .semibold))
                        .foregroundColor(Color.nostiaAccent)
                }
                .buttonStyle(.nostiaTap)
                .accessibilityLabel("Search experiences")
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(nearbyExperiences) { event in
                        Button {
                            Haptics.tap()
                            selectedExperience = event
                        } label: {
                            AtlasExperienceMiniCard(event: event)
                        }
                        .buttonStyle(.nostiaTap)
                        .accessibilityLabel(event.title)
                    }
                }
            }
        }
    }

    // MARK: - Data

    private func loadPoints() async {
        if let state = try? await AdventureAPI.shared.getCurrent() {
            pointsBalance = state.pointsBalance ?? 0
        }
    }

    private func loadNearby() async {
        let loc = LocationManager.shared.location
        let events = try? await ExperiencesAPI.shared.getForYouExperiences(
            lat: loc?.coordinate.latitude,
            lng: loc?.coordinate.longitude,
            limit: 8
        )
        nearbyExperiences = events ?? []
    }
}
