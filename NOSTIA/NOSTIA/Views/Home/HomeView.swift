import SwiftUI
import PhotosUI

struct HomeView: View {
    @Binding var selectedTab: Int
    @StateObject private var vm = HomeViewModel()
    @StateObject private var feedVM = FeedViewModel()
    @EnvironmentObject var locationManager: LocationManager
    @EnvironmentObject var authManager: AuthManager

    @Environment(\.scenePhase) private var scenePhase

    @State private var backgroundImage: UIImage?
    @State private var showBackgroundMenu = false
    @State private var showBackgroundPicker = false
    @State private var backgroundPickerItem: PhotosPickerItem?

    private var backgroundImageURL: URL? {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?
            .appendingPathComponent("home_background.jpg")
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                // Welcome header
                LinearGradient(colors: [Color.nostiaAccent.opacity(0.85), Color.nostriaPurple.opacity(0.85)],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
                    .cornerRadius(20)
                    .frame(height: 150)
                    .overlay {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Welcome back,")
                                    .font(.subheadline)
                                    .foregroundColor(Color(hex: "E0E7FF"))
                                Text(vm.user?.name ?? "Adventurer")
                                    .font(.system(size: 28, weight: .bold))
                                    .foregroundColor(.white)
                                Text("Your next adventure awaits")
                                    .font(.subheadline)
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
                                    size: 88
                                )
                            }
                        }
                        .padding(20)
                    }
                    .shadow(color: Color.nostiaAccent.opacity(0.35), radius: 20, y: 8)

                // Quick stats
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

                // Upcoming/nearby events
                if !vm.nearbyEvents.isEmpty {
                    SectionHeader(title: "Nearby Events")
                    ForEach(vm.nearbyEvents.prefix(3)) { event in
                        EventPreviewCard(event: event)
                    }
                } else if !vm.upcomingEvents.isEmpty {
                    SectionHeader(title: "Upcoming Events")
                    ForEach(vm.upcomingEvents.prefix(2)) { event in
                        EventPreviewCard(event: event)
                    }
                }

                // Post feed
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
                            onLike: { Task { await feedVM.toggleLike(post: post) } },
                            onDislike: { Task { await feedVM.toggleDislike(post: post) } },
                            onComment: { Task { await feedVM.loadComments(for: post) } }
                        )
                    }
                }
            }
            .padding(16)
                .padding(.bottom, 40)
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
        .sheet(item: $feedVM.selectedPost) { post in
            CommentsSheet(postId: post.id, vm: feedVM)
                .onAppear { Task { await feedVM.loadComments(for: post) } }
        }
    }

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
    var body: some View {
        Button {
            onTap?()
        } label: {
            VStack(spacing: 8) {
                Image(systemName: icon).font(.title2).foregroundColor(color)
                Text("\(count)").font(.system(size: 24, weight: .bold)).foregroundColor(.white)
                Text(label).font(.caption).foregroundColor(Color.nostiaTextSecond)
            }
            .frame(maxWidth: .infinity)
            .padding(16)
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
