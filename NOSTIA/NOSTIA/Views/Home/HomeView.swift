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
    @State private var eventActionsVM = EventActionsViewModel()

    private var isIPad: Bool { hSizeClass == .regular }

    private enum HomeSheet: Identifiable {
        case comments(FeedPost)
        case eventDetail(Event)
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
        .onTapGesture(count: 2) { showBackgroundMenu = true }
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
                EventDetailSheet(event: event, vm: eventActionsVM)
            case .editPost(let post):
                EditPostSheet(post: post, feedVM: feedVM)
            }
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
                    if !vm.nearbyEvents.isEmpty { nearbyEventsSection }
                    if !vm.upcomingEvents.isEmpty { upcomingEventsSection }
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity)

                // Right column: feed
                feedSection
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(responsive.spacing(24))
        .padding(.bottom, 40)
    }

    @ViewBuilder
    private var phoneLayout: some View {
        LazyVStack(spacing: responsive.spacing(16)) {
            welcomeHeader
            statCards
            if !vm.nearbyEvents.isEmpty { nearbyEventsSection }
            if !vm.upcomingEvents.isEmpty { upcomingEventsSection }
            feedSection
        }
        .padding(responsive.spacing(16))
        .padding(.bottom, 40)
        .frame(maxWidth: responsive.contentMaxWidth)
        .frame(maxWidth: .infinity)
    }

    // MARK: - Sections

    @ViewBuilder
    private var welcomeHeader: some View {
        LinearGradient(colors: [Color.nostiaAccent.opacity(0.85), Color.nostriaPurple.opacity(0.85)],
                       startPoint: .topLeading, endPoint: .bottomTrailing)
            .cornerRadius(20)
            .frame(height: responsive.spacing(isIPad ? 180 : 150))
            .overlay {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Welcome back,")
                            .font(.subheadline)
                            .foregroundColor(Color(hex: "E0E7FF"))
                        Text(vm.user?.name ?? "Adventurer")
                            .font(.system(size: responsive.fontSize(isIPad ? 34 : 28), weight: .bold))
                            .foregroundColor(.white)
                        Text("Your next adventure awaits")
                            .font(isIPad ? .callout : .subheadline)
                            .foregroundColor(Color(hex: "E0E7FF"))
                    }
                    Spacer()
                    NavigationLink {
                        ProfileView()
                            .navigationBarTitleDisplayMode(.inline)
                            .toolbarBackground(.hidden, for: .navigationBar)
                    } label: {
                        ProfilePictureView(
                            urlString: vm.user?.profilePictureUrl,
                            initial: vm.user?.initial ?? "?",
                            size: isIPad ? 110 : 88
                        )
                    }
                }
                .padding(responsive.spacing(20))
            }
            .shadow(color: Color.nostiaAccent.opacity(0.35), radius: 20, y: 8)
    }

    @ViewBuilder
    private var statCards: some View {
        HStack(spacing: 12) {
            StatCard(icon: "creditcard", color: Color.nostiaAccent,
                     count: vm.trips.count, label: "Vaults") {
                selectedTab = 1
            }
            StatCard(icon: "person.2.fill", color: Color.nostiaSuccess,
                     count: vm.followers.count, label: "Followers") {
                selectedTab = 4
            }
            StatCard(icon: "calendar", color: Color.nostiaWarning,
                     count: vm.upcomingEvents.count, label: "Events") {
                selectedTab = 3
            }
        }
    }

    @ViewBuilder
    private var nearbyEventsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "Nearby Events")
            ForEach(vm.nearbyEvents.prefix(isIPad ? 5 : 3)) { event in
                Button { activeSheet = .eventDetail(event) } label: {
                    EventPreviewCard(event: event)
                }
                .buttonStyle(.plain)
                .id("nearby-\(event.id)")
                .contextMenu {
                    if authManager.isDev {
                        Button(role: .destructive) {
                            Task { await vm.adminDeleteEvent(id: event.id) }
                        } label: {
                            Label("Delete Event", systemImage: "trash")
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var upcomingEventsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "Events You're Going To")
            ForEach(vm.upcomingEvents.prefix(isIPad ? 5 : 3)) { event in
                Button { activeSheet = .eventDetail(event) } label: {
                    EventPreviewCard(event: event)
                }
                .buttonStyle(.plain)
                .id("going-\(event.id)")
                .contextMenu {
                    if authManager.isDev {
                        Button(role: .destructive) {
                            Task { await vm.adminDeleteEvent(id: event.id) }
                        } label: {
                            Label("Delete Event", systemImage: "trash")
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var feedSection: some View {
        VStack(spacing: responsive.spacing(16)) {
            SectionHeader(title: "Feed")
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
            VStack(spacing: 8) {
                Image(systemName: icon).font(.title2).foregroundColor(color)
                Text("\(count)").font(.system(size: responsive.fontSize(24), weight: .bold)).foregroundColor(.white)
                Text(label).font(.caption).foregroundColor(Color.nostiaTextSecond)
            }
            .frame(maxWidth: .infinity)
            .padding(responsive.spacing(16))
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
    }
}

struct SectionHeader: View {
    let title: String
    var body: some View {
        Text(title).font(.headline).foregroundColor(.white)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct TripPreviewCard: View {
    let trip: Trip
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(trip.title).font(.headline).foregroundColor(.white)
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
        .glassEffect(in: RoundedRectangle(cornerRadius: 16))
    }
}

struct EventPreviewCard: View {
    let event: Event
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(event.title).font(.headline).foregroundColor(.white)
                Spacer()
                if let dist = event.formattedDistance {
                    Text(dist).font(.caption.bold()).foregroundColor(.white)
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(Color.nostiaAccent).cornerRadius(12)
                }
            }
            if let loc = event.location {
                Label(loc, systemImage: "location").font(.footnote).foregroundColor(Color.nostiaTextSecond)
            }
            Text(event.formattedDate).font(.footnote.bold()).foregroundColor(Color.nostiaWarning)
        }
        .padding(16)
        .glassEffect(in: RoundedRectangle(cornerRadius: 16))
    }
}
