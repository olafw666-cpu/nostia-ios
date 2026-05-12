import SwiftUI
import PhotosUI

struct HomeView: View {
    @StateObject private var vm = HomeViewModel()
    @EnvironmentObject var locationManager: LocationManager
    @EnvironmentObject var authManager: AuthManager

    @State private var backgroundImage: UIImage?
    @State private var showBackgroundMenu = false
    @State private var showBackgroundPicker = false
    @State private var backgroundPickerItem: PhotosPickerItem?

    private var backgroundImageURL: URL? {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?
            .appendingPathComponent("home_background.jpg")
    }

    var body: some View {
        ZStack {
            // Background image layer (non-interactive)
            if let bgImage = backgroundImage {
                Image(uiImage: bgImage)
                    .resizable()
                    .scaledToFill()
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
            }

            // Scrollable content with double-tap gesture on background
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
                                        size: 44
                                    )
                                }
                            }
                            .padding(20)
                        }
                        .shadow(color: Color.nostiaAccent.opacity(0.35), radius: 20, y: 8)

                    // Home status card
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Home Status").font(.headline).foregroundColor(.white)
                            Spacer()
                            Button {
                                Task { await vm.toggleHomeStatus() }
                            } label: {
                                Text(vm.user?.isHomeOpen == true ? "🏠 Open" : "🔒 Closed")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 16).padding(.vertical, 8)
                                    .glassEffect(in: Capsule())
                                    .overlay(
                                        Capsule().stroke(
                                            vm.user?.isHomeOpen == true ? Color.nostiaSuccess : Color.nostriaBorder,
                                            lineWidth: 1
                                        )
                                    )
                            }
                        }
                        Text(vm.user?.isHomeOpen == true
                             ? "Friends can see you're available to host"
                             : "Toggle to let friends know your home is open")
                            .font(.footnote).foregroundColor(Color.nostiaTextSecond)
                    }
                    .padding(16)
                    .glassEffect(in: RoundedRectangle(cornerRadius: 16))

                    // Quick stats
                    HStack(spacing: 12) {
                        StatCard(icon: "airplane", color: Color.nostiaAccent,
                                 count: vm.trips.count, label: "Trips")
                        StatCard(icon: "person.2.fill", color: Color.nostiaSuccess,
                                 count: vm.friends.count, label: "Friends")
                        StatCard(icon: "calendar", color: Color.nostiaWarning,
                                 count: vm.upcomingEvents.count, label: "Events")
                    }

                    // Upcoming trips preview
                    if !vm.trips.isEmpty {
                        SectionHeader(title: "Upcoming Trips")
                        ForEach(vm.trips.prefix(2)) { trip in
                            TripPreviewCard(trip: trip)
                        }
                    }

                    // Nearby events (location-based)
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

                    // Events I'm Going To
                    if !vm.goingEvents.isEmpty {
                        SectionHeader(title: "Events I'm Going To")
                        ForEach(vm.goingEvents.prefix(3)) { event in
                            EventGoingCard(event: event)
                        }
                    }

                    // Recent feed posts
                    if !vm.feed.isEmpty {
                        SectionHeader(title: "Recent Posts")
                        ForEach(vm.feed.prefix(3)) { post in
                            FeedPreviewCard(post: post)
                        }
                    }
                }
                .padding(16)
                .padding(.bottom, 40)
            }
            .background(.clear)
            .refreshable { await vm.loadAll() }
            .navigationTitle("Nostia")
            .navigationBarTitleDisplayMode(.inline)
            .onTapGesture(count: 2) { showBackgroundMenu = true }
        }
        .task {
            await vm.loadAll()
            locationManager.requestLocationOnce()
            loadBackgroundFromDisk()
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
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon).font(.title2).foregroundColor(color)
            Text("\(count)").font(.system(size: 24, weight: .bold)).foregroundColor(.white)
            Text(label).font(.caption).foregroundColor(Color.nostiaTextSecond)
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .glassEffect(in: RoundedRectangle(cornerRadius: 16))
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
                    Text(trip.destination).font(.footnote).foregroundColor(Color.nostiaTextSecond)
                }
                Spacer()
                HStack(spacing: 4) {
                    Image(systemName: "person.2").foregroundColor(Color.nostiaTextSecond)
                    Text("\(trip.participantCount)").foregroundColor(Color.nostiaTextSecond)
                }
                .font(.footnote)
            }
            Text(trip.formattedDates).font(.footnote.bold()).foregroundColor(Color.nostiaAccent)
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

struct EventGoingCard: View {
    let event: Event
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(event.title).font(.headline).foregroundColor(.white)
                Spacer()
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill").font(.caption).foregroundColor(Color.nostiaSuccess)
                    Text("Going").font(.caption.bold()).foregroundColor(Color.nostiaSuccess)
                }
                .padding(.horizontal, 8).padding(.vertical, 4)
                .background(Color.nostiaSuccess.opacity(0.15))
                .cornerRadius(12)
            }
            if let loc = event.location {
                Label(loc, systemImage: "location").font(.footnote).foregroundColor(Color.nostiaTextSecond)
            }
            Text(event.formattedDate).font(.footnote.bold()).foregroundColor(Color.nostiaWarning)
        }
        .padding(16)
        .background(Color(hex: "052E16"))
        .cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color(hex: "065F46"), lineWidth: 1))
    }
}

struct FeedPreviewCard: View {
    let post: FeedPost
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                AvatarView(initial: String(post.name.prefix(1)).uppercased(), color: Color.nostiaAccent, size: 32)
                VStack(alignment: .leading, spacing: 2) {
                    Text(post.name).font(.subheadline.bold()).foregroundColor(.white)
                    Text(post.timeAgo).font(.caption).foregroundColor(Color.nostiaTextMuted)
                }
                Spacer()
                HStack(spacing: 10) {
                    Label("\(post.likeCount)", systemImage: "heart")
                        .font(.caption).foregroundColor(Color.nostiaTextMuted)
                    Label("\(post.commentCount)", systemImage: "bubble.right")
                        .font(.caption).foregroundColor(Color.nostiaTextMuted)
                }
            }
            if let content = post.content, !content.isEmpty {
                Text(content).font(.subheadline).foregroundColor(Color.nostiaTextSecond).lineLimit(2)
            }
        }
        .padding(14)
        .glassEffect(in: RoundedRectangle(cornerRadius: 16))
    }
}
