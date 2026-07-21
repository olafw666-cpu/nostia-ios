import SwiftUI
import PhotosUI

struct HomeView: View {
    @Binding var selectedTab: Int
    @StateObject private var vm = HomeViewModel()
    @StateObject private var feedVM = FeedViewModel()
    @EnvironmentObject var locationManager: LocationManager
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var responsive: ResponsiveLayoutManager

    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.horizontalSizeClass) private var hSizeClass

    @State private var backgroundImage: UIImage?
    @State private var showBackgroundMenu = false
    @State private var showBackgroundPicker = false
    @State private var backgroundPickerItem: PhotosPickerItem?
    @State private var activeSheet: HomeSheet?
    @State private var eventActionsVM = ExperienceActionsViewModel()
    @State private var showOrganizations = false
    @State private var showCrashPads = false
    @State private var forYouPage = 0
    // Tapping a post author pushes their profile onto the Home nav stack.
    @State private var profileDestination: ProfileDestination?

    private var isIPad: Bool { hSizeClass == .regular }

    private enum HomeSheet: Identifiable {
        case comments(FeedPost)
        case eventDetail(Experience)
        case editPost(FeedPost)
        case createExperience
        case search([String])   // experience search; non-empty = tags pre-checked
        case visiting           // full "you're visiting" list
        var id: String {
            switch self {
            case .comments(let p): return "c\(p.id)"
            case .eventDetail(let e): return "e\(e.id)"
            case .editPost(let p): return "edit\(p.id)"
            case .createExperience: return "create"
            case .search: return "search"
            case .visiting: return "visiting"
            }
        }
    }

    private var backgroundImageURL: URL? {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?
            .appendingPathComponent("home_background.jpg")
    }

    var body: some View {
        ScrollView {
            if isIPad {
                iPadLayout
            } else {
                phoneLayout
            }
        }
        .background {
            // Base off-white canvas so the screen never shows the system surface (black in
            // Dark Mode) when no custom photo is set; the optional photo layers on top.
            Color.nostiaBackground.ignoresSafeArea()
            if let bgImage = backgroundImage {
                Image(uiImage: bgImage)
                    .resizable()
                    .scaledToFill()
                    .ignoresSafeArea()
                // Theme-tinted scrim: an arbitrary photo can zero out the contrast of
                // text sitting directly on the canvas (headers, row titles).
                Color.nostiaBackground.opacity(0.45).ignoresSafeArea()
            }
        }
        .refreshable {
            await vm.loadAll()
            // Nearby + themed rows come from the location-scoped fetch — without this,
            // pull-to-refresh left them stale.
            if let loc = locationManager.location {
                await vm.updateLocation(loc)
            }
            await feedVM.loadFeed()
        }
        .navigationTitle("Nostia")
        .navigationBarTitleDisplayMode(.inline)
        // Tour replay in the header's left corner (the right corner holds the shared
        // bell + avatar cluster). Same 40pt bubble as the bell; RootView presents the
        // tour and MainTabView closes any sheets over it.
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    Haptics.tap()
                    NotificationCenter.default.post(name: .replayAppTour, object: nil)
                } label: {
                    Circle()
                        .fill(Color.nostiaCard)
                        .frame(width: 40, height: 40)
                        .shadow(color: Color.nostiaShadow.opacity(0.08), radius: 8, y: 2)
                        .overlay(
                            Image(systemName: "questionmark")
                                .font(.nostiaBody(18))
                                .foregroundColor(Color.nostiaTextSecond)
                        )
                }
                .accessibilityLabel("App tour")
                .accessibilityHint("Replays the walkthrough of the app's main features")
            }
        }
        .onTapGesture(count: 2) { Haptics.tap(); showBackgroundMenu = true }
        .task {
            await vm.loadAll()
            locationManager.startPeriodicSync()
            if let loc = locationManager.location {
                await vm.updateLocation(loc)
            }
            await feedVM.loadFeed()
            loadBackgroundFromDisk()
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                locationManager.startPeriodicSync()
            } else if newPhase == .background {
                locationManager.stopPeriodicSync()
            }
        }
        .onChange(of: selectedTab) { _, newTab in
            if newTab == 0 {
                Task { await vm.loadAll() }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .profileUpdated)) { _ in
            Task { await vm.loadAll() }
        }
        .onChange(of: locationManager.location) { _, newLoc in
            guard let loc = newLoc else { return }
            Task { await vm.updateLocation(loc) }
        }
        .onChange(of: backgroundPickerItem) { _, item in
            Task {
                if let data = try? await item?.loadTransferable(type: Data.self),
                   let img = UIImage(data: data) {
                    saveBackgroundToDisk(img)
                    backgroundImage = img
                }
                backgroundPickerItem = nil
            }
        }
        .confirmationDialog("Home Screen Background", isPresented: $showBackgroundMenu, titleVisibility: .visible) {
            Button("Choose Photo") { showBackgroundPicker = true }
            if backgroundImage != nil {
                Button("Remove Background", role: .destructive) {
                    removeBackgroundFromDisk()
                    backgroundImage = nil
                }
            }
            Button("Cancel", role: .cancel) {}
        }
        .photosPicker(isPresented: $showBackgroundPicker,
                      selection: $backgroundPickerItem,
                      matching: .images,
                      photoLibrary: .shared())
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .comments(let post):
                CommentsSheet(postId: post.id, vm: feedVM)
                    .onAppear { Task { await feedVM.loadComments(for: post) } }
            case .eventDetail(let event):
                ExperienceDetailSheet(event: event, vm: eventActionsVM)
            case .editPost(let post):
                EditPostSheet(post: post, feedVM: feedVM)
            case .createExperience:
                CreateExperienceFromDiscoverSheet { _ in
                    Task { await vm.loadAll() }
                }
            case .search(let tags):
                ExperienceSearchSheet(initialTags: tags)
            case .visiting:
                ExperienceListSheet(title: "You're visiting", events: vm.upcomingEvents)
            }
        }
        .sheet(item: $feedVM.reportTarget) { target in
            ReportSheet(target: target)
        }
        .sheet(isPresented: $feedVM.showCreateSheet) {
            CreatePostSheet(vm: feedVM)
        }
        .sheet(isPresented: $showOrganizations) {
            OrganizationsHubView()
                .presentationBackground(Color.nostiaBackground)
        }
        .sheet(isPresented: $showCrashPads) {
            CrashPadsView()
        }
        // Tapping a post author opens their profile (pushed on the Home nav stack).
        .navigationDestination(item: $profileDestination) { dest in
            PublicProfileView(userId: dest.id)
        }
        .alert("Blocked", isPresented: Binding(
            get: { feedVM.moderationMessage != nil },
            set: { if !$0 { feedVM.moderationMessage = nil } }
        )) {
            Button("OK") { feedVM.moderationMessage = nil }
        } message: {
            Text(feedVM.moderationMessage ?? "")
        }
    }

    // MARK: - Layouts

    @ViewBuilder
    private var iPadLayout: some View {
        VStack(spacing: responsive.spacing(20)) {
            welcomeHeader
            loadErrorBanner

            HStack(alignment: .top, spacing: responsive.spacing(20)) {
                // Left column: stats + events
                VStack(spacing: responsive.spacing(16)) {
                    statCards
                    forYouSection
                    orgsButton
                    if !vm.upcomingEvents.isEmpty { upcomingEventsSection }
                    themedSections
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity)

                // Right column: feed
                feedSection
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(responsive.spacing(24))
        .padding(.bottom, 120)
    }

    @ViewBuilder
    private var phoneLayout: some View {
        LazyVStack(spacing: responsive.spacing(18)) {
            welcomeHeader
            loadErrorBanner
            statCards
            forYouSection
            NostiaSearchBar(placeholder: "Search places & experiences…") { activeSheet = .search([]) }
            if !vm.upcomingEvents.isEmpty { upcomingEventsSection }
            themedSections
            orgsButton
            feedSection
        }
        .padding(responsive.spacing(16))
        .padding(.bottom, 120)
        .frame(maxWidth: responsive.contentMaxWidth)
        .frame(maxWidth: .infinity)
    }

    // MARK: - Sections

    /// A user whose profile has a blank/whitespace name would otherwise render
    /// "Welcome back, " — fall back to the same placeholder as a missing user.
    private var welcomeName: String {
        let name = vm.user?.name.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return name.isEmpty ? "Adventurer" : name
    }

    /// Shown when the initial profile load failed (offline, expired session mid-refresh,
    /// server hiccup). Without it a failed `loadAll` left Home silently empty with no
    /// way back besides discovering pull-to-refresh.
    @ViewBuilder
    private var loadErrorBanner: some View {
        if vm.errorMessage != nil {
            HStack(spacing: 12) {
                Image(systemName: "wifi.exclamationmark")
                    .font(.nostiaBody(18, weight: .semibold))
                    .foregroundColor(Color.nostiaWarning)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Couldn't load your Home")
                        .font(.nostiaBody(14, weight: .bold))
                        .foregroundColor(Color.nostiaTextPrimary)
                    Text("Check your connection and try again.")
                        .font(.nostiaBody(12))
                        .foregroundColor(Color.nostiaTextSecond)
                }
                Spacer()
                Button {
                    Haptics.tap()
                    Task {
                        await vm.loadAll()
                        if let loc = locationManager.location { await vm.updateLocation(loc) }
                        await feedVM.loadFeed()
                    }
                } label: {
                    Text("Retry")
                        .font(.nostiaBody(13, weight: .bold))
                        .foregroundColor(Color.nostiaAccent)
                        .padding(.horizontal, 12).padding(.vertical, 7)
                        .background(Color.nostiaAccent.opacity(0.12), in: Capsule())
                }
                .buttonStyle(.nostiaTap)
            }
            .padding(14)
            .nostiaCard(in: RoundedRectangle(cornerRadius: 16))
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Home failed to load. Retry.")
        }
    }

    @ViewBuilder
    private var welcomeHeader: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 5) {
                Text("NOSTIA")
                    .font(.nostiaBody(15, weight: .medium))
                    .tracking(2.7)
                    .foregroundColor(Color.nostiaAccent)
                Text("Welcome back, \(welcomeName)")
                    .font(.nostiaDisplay(isIPad ? 34 : 28))
                    .foregroundColor(Color.nostiaTextPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            // Visible entry to the background customizer (double-tap still works, but
            // a hidden gesture can't be the only way in).
            Button { Haptics.tap(); showBackgroundMenu = true } label: {
                Image(systemName: "photo.on.rectangle")
                    .font(.nostiaBody(15, weight: .semibold))
                    .foregroundColor(Color.nostiaTextMuted)
                    .frame(width: 34, height: 34)
                    .nostiaCard(in: Circle(), elevation: .flat)
            }
            .buttonStyle(.nostiaTap)
            .accessibilityLabel("Customize Home background")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 4)
    }

    @ViewBuilder
    private var statCards: some View {
        HStack(spacing: 10) {
            StatCard(icon: "wallet.bifold.fill", color: Color.nostiaAccent,
                     count: vm.trips.count, label: "Vaults") {
                selectedTab = 2
            }
            StatCard(icon: "person.2.fill", color: Color.nostiaAccent,
                     count: vm.following.count, label: "Following") {
                selectedTab = 4
            }
            StatCard(icon: "location.north.fill", color: Color.nostiaAccent,
                     count: vm.upcomingEvents.count, label: "Visiting") {
                activeSheet = .visiting
            }
        }
    }

    /// One "Community" section instead of a full-width promo per feature — orgs and
    /// crash pads share a row of two compact cards, keeping Home short.
    @ViewBuilder
    private var orgsButton: some View {
        VStack(alignment: .leading, spacing: 10) {
            NostiaRowHeader(title: "Community", actionTitle: nil)
            HStack(spacing: 10) {
                communityCard(icon: "building.2.fill",
                              title: "Organizations",
                              sub: "Location-gated groups") {
                    showOrganizations = true
                }
                communityCard(icon: "sofa.fill",
                              title: "Crash Pads",
                              sub: "Stay with friends") {
                    showCrashPads = true
                }
            }
        }
    }

    private func communityCard(icon: String, title: String, sub: String, action: @escaping () -> Void) -> some View {
        Button { Haptics.tap(); action() } label: {
            VStack(alignment: .leading, spacing: 8) {
                ZStack {
                    Circle().fill(Color.nostiaAccentSoft).frame(width: 40, height: 40)
                    Image(systemName: icon).font(.nostiaBody(17, weight: .semibold))
                        .foregroundColor(Color.nostiaAccent)
                }
                Text(title)
                    .font(.nostiaBody(15, weight: .bold)).foregroundColor(Color.nostiaTextPrimary)
                Text(sub)
                    .font(.nostiaBody(12)).foregroundColor(Color.nostiaTextSecond)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .nostiaCard(in: RoundedRectangle(cornerRadius: 18))
        }
        .buttonStyle(.nostiaTap)
        .accessibilityLabel("\(title). \(sub)")
    }

    // MARK: - For You carousel (above the search bar)

    /// Paged hero carousel: the two closest feed-blend picks (followed creators → my orgs
    /// → nearby public, from /experiences/for-you) plus a trailing "Create Experience" card.
    @ViewBuilder
    private var forYouSection: some View {
        let picks = Array(vm.forYouEvents.prefix(2))
        let pageCount = picks.count + 1 // + trailing create card
        VStack(alignment: .leading, spacing: 10) {
            NostiaRowHeader(title: "For You") { activeSheet = .search([]) }
            TabView(selection: $forYouPage) {
                ForEach(Array(picks.enumerated()), id: \.element.id) { index, event in
                    Button { Haptics.tap(); activeSheet = .eventDetail(event) } label: {
                        HomeHeroExperienceCard(event: event)
                    }
                    .buttonStyle(.nostiaTap)
                    .contextMenu {
                        if authManager.isDev {
                            Button(role: .destructive) {
                                Task { await vm.adminDeleteExperience(id: event.id) }
                            } label: {
                                Label("Delete Experience", systemImage: "trash")
                            }
                        }
                    }
                    .tag(index)
                }
                Button { Haptics.tap(); activeSheet = .createExperience } label: {
                    createExperienceCard
                }
                .buttonStyle(.nostiaTap)
                .tag(pageCount - 1)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(height: 224)

            if pageCount > 1 {
                HStack(spacing: 6) {
                    ForEach(0..<pageCount, id: \.self) { i in
                        Circle()
                            .fill(i == forYouPage ? Color.nostiaAccent : Color.nostiaTextMuted.opacity(0.4))
                            .frame(width: 7, height: 7)
                    }
                }
                .frame(maxWidth: .infinity)
                .animation(.easeInOut(duration: 0.15), value: forYouPage)
            }
        }
        // Picks load async — snap back to the first page so the selection never points
        // at a tag that no longer exists.
        .onChange(of: vm.forYouEvents.count) { _, _ in forYouPage = 0 }
    }

    /// Trailing carousel card: create your own experience.
    @ViewBuilder
    private var createExperienceCard: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle().fill(Color.nostiaAccentSoft).frame(width: 56, height: 56)
                Image(systemName: "plus").font(.nostiaBody(26, weight: .semibold))
                    .foregroundColor(Color.nostiaAccent)
            }
            Text("Create Experience")
                .font(.nostiaBody(16, weight: .bold)).foregroundColor(Color.nostiaTextPrimary)
            Text("Host something near you")
                .font(.nostiaBody(12.5)).foregroundColor(Color.nostiaTextSecond)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 212)
        .nostiaCard(in: RoundedRectangle(cornerRadius: 20))
    }

    @ViewBuilder
    private var upcomingEventsSection: some View {
        experienceRow(title: "Experiences you're visiting", events: Array(vm.upcomingEvents.prefix(8)), idPrefix: "going") {
            activeSheet = .visiting
        }
    }

    // MARK: - Themed category rows (batch 4 §4/§5)

    /// A tag-themed Home row. "See all" opens Explore with `tags` pre-checked.
    private struct HomeCategory: Identifiable {
        let title: String
        let icon: String
        let tags: [String]
        var id: String { title }
    }

    /// Default grouping covering all 12 preset experience tags (batch 4 §5).
    private let homeCategories: [HomeCategory] = [
        .init(title: "Outdoors",        icon: "leaf.fill",         tags: ["outdoors", "hiking", "nature"]),
        .init(title: "On the Water",    icon: "drop.fill",         tags: ["water"]),
        .init(title: "Food & Nightlife", icon: "fork.knife",       tags: ["food", "nightlife"]),
        .init(title: "Arts & Culture",  icon: "theatermasks.fill", tags: ["culture", "art", "music"]),
        .init(title: "Active",          icon: "figure.run",        tags: ["sports", "fitness"]),
        .init(title: "Social",          icon: "person.2.fill",     tags: ["social"]),
    ]

    /// Broad experience pool the Home VM already loads (nearby + visiting, de-duplicated)
    /// used to populate the themed rows without an extra fetch (Q-B default).
    private var themePool: [Experience] {
        var seen = Set<Int>()
        return (vm.nearbyEvents + vm.upcomingEvents).filter { seen.insert($0.id).inserted }
    }

    /// The non-empty themed rows, capped at three — Home should read as a highlight
    /// reel, not an endless scroll; the search sheet has every tag.
    private var visibleCategories: [(HomeCategory, [Experience])] {
        homeCategories.compactMap { category in
            let tagSet = Set(category.tags)
            let matches = themePool.filter { !Set($0.tags ?? []).isDisjoint(with: tagSet) }
            return matches.isEmpty ? nil : (category, Array(matches.prefix(8)))
        }
        .prefix(3)
        .map { $0 }
    }

    @ViewBuilder
    private var themedSections: some View {
        ForEach(visibleCategories, id: \.0.id) { category, matches in
            experienceRow(title: category.title,
                          events: matches,
                          idPrefix: "theme-\(category.id)") {
                activeSheet = .search(category.tags)
            }
        }
    }

    /// Atlas horizontal photo-card row with a "See all" header.
    @ViewBuilder
    private func experienceRow(title: String, events: [Experience], idPrefix: String, seeAll: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            NostiaRowHeader(title: title, action: seeAll)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 13) {
                    ForEach(events) { event in
                        Button { Haptics.tap(); activeSheet = .eventDetail(event) } label: {
                            AtlasExperienceMiniCard(event: event)
                        }
                        .buttonStyle(.nostiaTap)
                        .id("\(idPrefix)-\(event.id)")
                        .contextMenu {
                            if authManager.isDev {
                                Button(role: .destructive) {
                                    Task { await vm.adminDeleteExperience(id: event.id) }
                                } label: {
                                    Label("Delete Experience", systemImage: "trash")
                                }
                            }
                        }
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }

    @ViewBuilder
    private var feedSection: some View {
        VStack(spacing: responsive.spacing(16)) {
            HStack {
                NostiaRowHeader(title: "Feed", actionTitle: nil)
                Button {
                    Haptics.tap()
                    feedVM.showCreateSheet = true
                } label: {
                    Label("New Post", systemImage: "plus.circle.fill")
                        .font(.subheadline.bold())
                        .foregroundColor(Color.nostiaAccent)
                }
            }
            if feedVM.isLoading && feedVM.posts.isEmpty {
                ProgressView().tint(Color.nostiaAccent)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            } else if feedVM.posts.isEmpty {
                EmptyStateView(
                    icon: "photo.on.rectangle.angled",
                    text: "Nothing to show yet",
                    sub: "Follow users or check back later"
                )
            } else {
                ForEach(feedVM.posts) { post in
                    PostCard(
                        post: post,
                        currentUserId: authManager.currentUserId,
                        isCurrentUserDev: authManager.isDev,
                        onLike: { Task { await feedVM.toggleLike(post: post) } },
                        onDislike: { Task { await feedVM.toggleDislike(post: post) } },
                        onDelete: {
                            if authManager.isDev && post.userId != authManager.currentUserId {
                                Task { await feedVM.adminDeletePost(post: post) }
                            } else {
                                Task { await feedVM.deletePost(post: post) }
                            }
                        },
                        onEdit: post.userId == authManager.currentUserId ? { activeSheet = .editPost(post) } : nil,
                        onComment: { activeSheet = .comments(post) },
                        onProfileTap: { profileDestination = ProfileDestination(id: $0) },
                        onReport: { feedVM.reportTarget = ReportTarget(contentType: "post", contentId: post.id) },
                        onBlockUser: { Task { await feedVM.blockUser(userId: post.userId, username: post.username) } },
                        isLikeProcessing: feedVM.likingPostIds.contains(post.id),
                        isDislikeProcessing: feedVM.dislikingPostIds.contains(post.id)
                    )
                }
            }
        }
    }

    // MARK: - Background helpers

    private func loadBackgroundFromDisk() {
        guard let url = backgroundImageURL,
              let data = try? Data(contentsOf: url),
              let img = UIImage(data: data) else { return }
        backgroundImage = img
    }

    private func saveBackgroundToDisk(_ image: UIImage) {
        guard let url = backgroundImageURL,
              let data = image.jpegData(compressionQuality: 0.8) else { return }
        try? data.write(to: url)
    }

    private func removeBackgroundFromDisk() {
        guard let url = backgroundImageURL else { return }
        try? FileManager.default.removeItem(at: url)
    }
}

// MARK: - Sub-components

/// Full-width photo card for the Home "For You" paged carousel. Fixed height so the
/// paging TabView can size itself deterministically.
struct HomeHeroExperienceCard: View {
    let event: Experience

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .topLeading) {
                AtlasExperienceImage(flyerImage: event.flyerImage, height: 150)
                if let tag = event.tags?.first {
                    Text(tag.capitalized)
                        .font(.nostiaBody(10.5, weight: .bold))
                        .foregroundColor(Color.nostiaAccent)
                        .padding(.horizontal, 10).padding(.vertical, 4)
                        .background(Capsule().fill(Color.nostiaWarm))
                        .shadow(color: Color.black.opacity(0.08), radius: 4, y: 1)
                        .padding(10)
                }
            }
            VStack(alignment: .leading, spacing: 5) {
                Text(event.title)
                    .font(.nostiaBody(17, weight: .bold))
                    .foregroundColor(Color.nostiaTextPrimary)
                    .lineLimit(1)
                HStack(spacing: 4) {
                    Image(systemName: "star.fill").font(.nostiaBody(13)).foregroundColor(Color.nostiaStar)
                    Text(event.formattedAvgRating ?? "New")
                        .font(.nostiaBody(12.5, weight: .bold)).foregroundColor(Color.nostiaTextPrimary)
                    if let dist = event.formattedDistance {
                        Text("· \(dist)").font(.nostiaBody(12.5)).foregroundColor(Color.nostiaTextMuted)
                    } else if let loc = event.location, !loc.isEmpty {
                        Text("· \(loc)").font(.nostiaBody(12.5)).foregroundColor(Color.nostiaTextMuted).lineLimit(1)
                    }
                }
            }
            .padding(.horizontal, 14).padding(.top, 11).padding(.bottom, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(height: 212)
        .nostiaWarmCard(cornerRadius: 20)
    }
}

struct StatCard: View {
    let icon: String; let color: Color; let count: Int; let label: String
    var onTap: (() -> Void)? = nil
    @EnvironmentObject var responsive: ResponsiveLayoutManager
    var body: some View {
        Button {
            onTap?()
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                Image(systemName: icon).font(.nostiaBody(20)).foregroundColor(color)
                Text("\(count)")
                    .font(.nostiaBody(responsive.fontSize(24), weight: .heavy))
                    .foregroundColor(Color.nostiaTextPrimary)
                    .padding(.top, 4)
                Text(label).font(.nostiaBody(12)).foregroundColor(Color.nostiaTextSecond)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .nostiaCard(in: RoundedRectangle(cornerRadius: 18))
        }
        .buttonStyle(.nostiaTap)
    }
}

struct SectionHeader: View {
    let title: String
    var body: some View {
        Text(title).font(.nostiaDisplay(19, weight: .heavy)).foregroundColor(Color.nostiaTextPrimary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct TripPreviewCard: View {
    let trip: Trip
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(trip.title).font(.headline).foregroundColor(Color.nostiaTextPrimary)
                    if let dest = trip.destination, !dest.isEmpty {
                        Text(dest).font(.footnote).foregroundColor(Color.nostiaTextSecond)
                    }
                }
                Spacer()
                HStack(spacing: 4) {
                    Image(systemName: "person.2").foregroundColor(Color.nostiaTextSecond)
                    Text("\(trip.participantCount)").foregroundColor(Color.nostiaTextSecond)
                }
                .font(.footnote)
            }
            if trip.startDate != nil || trip.endDate != nil {
                Text(trip.formattedDates).font(.footnote.bold()).foregroundColor(Color.nostiaAccent)
            }
        }
        .padding(16)
        .nostiaWarmCard(in: RoundedRectangle(cornerRadius: 16))
    }
}

struct ExperiencePreviewCard: View {
    let event: Experience
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(event.title).font(.headline).foregroundColor(Color.nostiaTextPrimary)
                Spacer()
                if let dist = event.formattedDistance {
                    Text(dist).font(.caption.bold()).foregroundColor(.white)
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(Color.nostiaAccent).cornerRadius(12)
                }
            }
            if let tags = event.tags, !tags.isEmpty {
                ExperienceTagChips(tags: tags)
            }
            if let loc = event.location {
                Label(loc, systemImage: "location").font(.footnote).foregroundColor(Color.nostiaTextSecond)
            }
        }
        .padding(16)
        .nostiaWarmCard(in: RoundedRectangle(cornerRadius: 16))
    }
}
