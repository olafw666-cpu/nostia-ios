import SwiftUI
import PhotosUI

struct HomeView: View {
    @Binding var selectedTab: Int
    @StateObject private var vm = HomeViewModel()
    @StateObject private var feedVM = FeedViewModel()
    @EnvironmentObject var locationManager: LocationManager
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var responsive: ResponsiveLayoutManager
    @EnvironmentObject var router: DeepLinkRouter

    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.horizontalSizeClass) private var hSizeClass

    @State private var backgroundImage: UIImage?
    @State private var showBackgroundMenu = false
    @State private var showBackgroundPicker = false
    @State private var backgroundPickerItem: PhotosPickerItem?
    @State private var activeSheet: HomeSheet?
    @State private var eventActionsVM = ExperienceActionsViewModel()
    @State private var showOrganizations = false

    private var isIPad: Bool { hSizeClass == .regular }

    private enum HomeSheet: Identifiable {
        case comments(FeedPost)
        case eventDetail(Experience)
        case editPost(FeedPost)
        var id: String {
            switch self {
            case .comments(let p): return "c\(p.id)"
            case .eventDetail(let e): return "e\(e.id)"
            case .editPost(let p): return "edit\(p.id)"
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
            }
        }
        .refreshable {
            await vm.loadAll()
            await feedVM.loadFeed()
        }
        .navigationTitle("Nostia")
        .navigationBarTitleDisplayMode(.inline)
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

            HStack(alignment: .top, spacing: responsive.spacing(20)) {
                // Left column: stats + events
                VStack(spacing: responsive.spacing(16)) {
                    statCards
                    orgsButton
                    if !vm.nearbyEvents.isEmpty { nearbyEventsSection }
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
            statCards
            NostiaSearchBar(placeholder: "Search places & experiences…") { selectedTab = 1 }
            if !vm.nearbyEvents.isEmpty { nearbyEventsSection }
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

    @ViewBuilder
    private var welcomeHeader: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("NOSTIA")
                .font(.nostiaBody(15, weight: .medium))
                .tracking(2.7)
                .foregroundColor(Color.nostiaAccent)
            Text("Welcome back, \(vm.user?.name ?? "Adventurer")")
                .font(.nostiaDisplay(isIPad ? 34 : 28))
                .foregroundColor(Color.nostiaTextPrimary)
                .fixedSize(horizontal: false, vertical: true)
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
                     count: vm.followers.count, label: "Following") {
                selectedTab = 4
            }
            StatCard(icon: "location.north.fill", color: Color.nostiaAccent,
                     count: vm.upcomingEvents.count, label: "Experiences") {
                selectedTab = 1
            }
        }
    }

    @ViewBuilder
    private var orgsButton: some View {
        VStack(alignment: .leading, spacing: 10) {
            NostiaRowHeader(title: "Organizations", actionTitle: "See all") {
                Haptics.tap(); showOrganizations = true
            }
            Text("Location-gated groups with their own events & experiences.")
                .font(.system(size: 13)).foregroundColor(Color.nostiaTextSecond)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button { Haptics.tap(); showOrganizations = true } label: {
                HStack(spacing: 12) {
                    ZStack {
                        Circle().fill(Color.nostiaAccentSoft).frame(width: 46, height: 46)
                        Image(systemName: "plus").font(.system(size: 22, weight: .semibold))
                            .foregroundColor(Color.nostiaAccent)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Create or join an org")
                            .font(.system(size: 15, weight: .bold)).foregroundColor(Color.nostiaTextPrimary)
                        Text("Host your own events")
                            .font(.system(size: 12)).foregroundColor(Color.nostiaTextSecond)
                    }
                    Spacer()
                    Image(systemName: "chevron.right").foregroundColor(Color.nostiaTextMuted)
                }
                .padding(16)
                .nostiaCard(in: RoundedRectangle(cornerRadius: 18))
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    private var nearbyEventsSection: some View {
        experienceRow(title: "Trending near you", events: Array(vm.nearbyEvents.prefix(8)), idPrefix: "nearby") {
            selectedTab = 1
        }
    }

    @ViewBuilder
    private var upcomingEventsSection: some View {
        experienceRow(title: "Experiences you're visiting", events: Array(vm.upcomingEvents.prefix(8)), idPrefix: "going") {
            selectedTab = 1
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

    @ViewBuilder
    private var themedSections: some View {
        ForEach(homeCategories) { category in
            let tagSet = Set(category.tags)
            let matches = themePool.filter { !Set($0.tags ?? []).isDisjoint(with: tagSet) }
            if !matches.isEmpty {
                experienceRow(title: category.title,
                              events: Array(matches.prefix(8)),
                              idPrefix: "theme-\(category.id)") {
                    router.pendingExploreTags = category.tags
                    selectedTab = 1
                }
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
                        .buttonStyle(.plain)
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

struct StatCard: View {
    let icon: String; let color: Color; let count: Int; let label: String
    var onTap: (() -> Void)? = nil
    @EnvironmentObject var responsive: ResponsiveLayoutManager
    var body: some View {
        Button {
            onTap?()
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                Image(systemName: icon).font(.system(size: 20)).foregroundColor(color)
                Text("\(count)")
                    .font(.system(size: responsive.fontSize(24), weight: .heavy))
                    .foregroundColor(Color.nostiaTextPrimary)
                    .padding(.top, 4)
                Text(label).font(.system(size: 12)).foregroundColor(Color.nostiaTextSecond)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .nostiaCard(in: RoundedRectangle(cornerRadius: 18))
        }
        .buttonStyle(.plain)
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
