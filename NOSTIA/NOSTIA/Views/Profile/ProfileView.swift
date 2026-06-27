import SwiftUI
import PhotosUI

struct ProfileView: View {
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var responsive: ResponsiveLayoutManager
    @State private var user: User?
    @State private var isLoading = true
    @State private var isEditing = false
    @State private var activeSheet: ProfileSheet?
    @State private var editBio = ""
    @State private var editImageData: String?
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var imageToCrop: UIImage?
    @State private var showCrop = false
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var profileTab: ProfileTab = .posts
    @State private var visitedVisibility: String = "followers"
    @State private var isUpdatingVisibility = false
    @StateObject private var feedVM = FeedViewModel()

    var body: some View {
        ScrollView {
            VStack(spacing: responsive.spacing(20)) {
                if isLoading {
                    ProfileSkeletonView()
                } else if let u = user {
                    // Profile picture
                    ZStack(alignment: .bottomTrailing) {
                        UserAvatarView(
                            imageData: isEditing ? editImageData : u.profilePictureUrl,
                            initial: u.initial,
                            color: Color.nostiaAccent,
                            size: responsive.spacing(100)
                        )
                        if isEditing {
                            PhotosPicker(selection: $selectedPhoto, matching: .images) {
                                Image(systemName: "camera.fill")
                                    .font(.system(size: 14))
                                    .foregroundColor(.white)
                                    .frame(width: 32, height: 32)
                                    .background(Color.nostiaAccent)
                                    .clipShape(Circle())
                                    .overlay(Circle().stroke(Color(hex: "1A0E35"), lineWidth: 2))
                            }
                            .offset(x: 4, y: 4)
                        }
                    }
                    .padding(.top, responsive.spacing(8))

                    // Username (read-only)
                    Text("@\(u.username)")
                        .font(.nostiaDisplay(22, weight: .heavy))
                        .foregroundColor(Color.nostiaTextPrimary)

                    // Bio
                    if isEditing {
                        VStack(alignment: .leading, spacing: 4) {
                            ZStack(alignment: .topLeading) {
                                if editBio.isEmpty {
                                    Text("Write a short bio...")
                                        .foregroundColor(Color.nostiaTextMuted)
                                        .padding(.horizontal, responsive.spacing(14))
                                        .padding(.vertical, responsive.spacing(14))
                                }
                                TextEditor(text: $editBio)
                                    .frame(minHeight: responsive.spacing(80))
                                    .padding(8)
                                    .nostiaCard(in: RoundedRectangle(cornerRadius: 12))
                                    .foregroundColor(Color.nostiaTextPrimary)
                                    .scrollContentBackground(.hidden)
                            }
                            HStack {
                                Spacer()
                                Text("\(editBio.count)/100")
                                    .font(.caption)
                                    .foregroundColor(editBio.count > 100 ? Color.nostriaDanger : Color.nostiaTextMuted)
                            }
                        }
                        .padding(.horizontal, responsive.spacing(20))
                    } else {
                        let bioText = u.bio?.isEmpty == false ? u.bio! : nil
                        Text(bioText ?? "No bio yet")
                            .font(.body)
                            .foregroundColor(bioText != nil ? Color.nostiaTextPrimary : Color.nostiaTextMuted)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, responsive.spacing(24))
                    }

                    // Follower count
                    Text("\(u.followersCount ?? 0) Followers")
                        .font(.subheadline.bold())
                        .foregroundColor(Color.nostiaTextSecond)

                    if let err = errorMessage {
                        Text(err)
                            .font(.caption)
                            .foregroundColor(Color.nostriaDanger)
                            .padding(.horizontal, responsive.spacing(24))
                    }

                    Divider()
                        .background(Color.nostiaDivider)
                        .padding(.horizontal, responsive.spacing(20))

                    // Buttons
                    if isEditing {
                        HStack(spacing: 12) {
                            Button {
                                isEditing = false
                                editBio = u.bio ?? ""
                                editImageData = u.profilePictureUrl
                                errorMessage = nil
                            } label: {
                                Text("Cancel")
                                    .foregroundColor(Color.nostiaTextSecond)
                                    .frame(maxWidth: .infinity)
                                    .padding(responsive.spacing(16))
                                    .nostiaCard(in: RoundedRectangle(cornerRadius: 14))
                            }
                            .buttonStyle(.plain)

                            Button {
                                Task { await saveProfile() }
                            } label: {
                                HStack {
                                    if isSaving {
                                        ProgressView().tint(.white).scaleEffect(0.8)
                                    } else {
                                        Text("Save").fontWeight(.bold)
                                    }
                                }
                                .frame(maxWidth: .infinity)
                                .padding(responsive.spacing(16))
                                .background(editBio.count > 100 ? Color.nostiaTextMuted : Color.nostiaAccent)
                                .foregroundColor(.white)
                                .cornerRadius(14)
                            }
                            .disabled(isSaving || editBio.count > 100)
                        }
                        .padding(.horizontal, responsive.spacing(20))
                    } else {
                        VStack(spacing: responsive.spacing(12)) {
                            Button {
                                editBio = u.bio ?? ""
                                editImageData = u.profilePictureUrl
                                isEditing = true
                            } label: {
                                Label("Edit Profile", systemImage: "pencil")
                                    .font(.subheadline.bold())
                                    .foregroundColor(Color.nostiaTextPrimary)
                                    .frame(maxWidth: .infinity)
                                    .padding(responsive.spacing(16))
                                    .nostiaCard(in: RoundedRectangle(cornerRadius: 14))
                            }
                            .buttonStyle(.plain)
                            .padding(.horizontal, responsive.spacing(20))

                            Button {
                                activeSheet = .createPost
                            } label: {
                                Label("Post", systemImage: "plus.square")
                                    .font(.subheadline.bold())
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(responsive.spacing(16))
                                    .background(Color.nostiaAccent)
                                    .cornerRadius(14)
                            }
                            .buttonStyle(.plain)
                            .padding(.horizontal, responsive.spacing(20))

                            Button {
                                activeSheet = .organizations
                            } label: {
                                Label("Organizations", systemImage: "building.2")
                                    .font(.subheadline.bold())
                                    .foregroundColor(Color.nostiaTextPrimary)
                                    .frame(maxWidth: .infinity)
                                    .padding(responsive.spacing(16))
                                    .nostiaCard(in: RoundedRectangle(cornerRadius: 14))
                            }
                            .buttonStyle(.plain)
                            .padding(.horizontal, responsive.spacing(20))

                            Button {
                                activeSheet = .settings
                            } label: {
                                Label("Settings", systemImage: "gear")
                                    .font(.subheadline)
                                    .foregroundColor(Color.nostiaTextSecond)
                                    .frame(maxWidth: .infinity)
                                    .padding(responsive.spacing(16))
                                    .nostiaCard(in: RoundedRectangle(cornerRadius: 14))
                            }
                            .buttonStyle(.plain)
                            .padding(.horizontal, responsive.spacing(20))
                        }
                    }

                    // Posts / Visited tab switcher (D6)
                    Divider()
                        .background(Color.nostiaDivider)
                        .padding(.horizontal, responsive.spacing(20))

                    Picker("", selection: $profileTab) {
                        Text("Posts").tag(ProfileTab.posts)
                        Text("Visited").tag(ProfileTab.visited)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, responsive.spacing(20))
                    .onChange(of: profileTab) { _, _ in Haptics.select() }

                    if profileTab == .posts {
                        if feedVM.isLoading {
                            ProgressView().tint(Color.nostiaAccent).padding(.vertical, 12)
                        } else if feedVM.posts.isEmpty {
                            Text("No posts yet.")
                                .font(.subheadline)
                                .foregroundColor(Color.nostiaTextMuted)
                                .padding(.vertical, 12)
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
                                    onComment: { activeSheet = .comments(post) }
                                )
                                .padding(.horizontal, responsive.spacing(16))
                            }
                        }
                    } else {
                        // Owner-only visibility control for the Visited tab (D6 / Q-C).
                        visitedVisibilityControl
                        VisitedExperiencesView(userId: authManager.currentUserId ?? 0)
                    }
                }
            }
            .padding(.bottom, 40)
            .frame(maxWidth: responsive.contentMaxWidth)
            .frame(maxWidth: .infinity)
        }
        .background(.clear)
        .task {
            await loadProfile()
            await feedVM.loadUserPosts(userId: authManager.currentUserId ?? 0)
        }
        .onChange(of: selectedPhoto) { _, item in
            Task {
                guard let item else { return }
                if let data = try? await item.loadTransferable(type: Data.self),
                   let img = UIImage(data: data) {
                    imageToCrop = img
                    showCrop = true
                }
                selectedPhoto = nil
            }
        }
        .fullScreenCover(isPresented: $showCrop) {
            if let img = imageToCrop {
                ProfileCropView(image: img) { cropped in
                    showCrop = false
                    imageToCrop = nil
                    if let compressed = cropped.jpegData(compressionQuality: 0.75) {
                        editImageData = compressed.base64EncodedString()
                    }
                } onCancel: {
                    showCrop = false
                    imageToCrop = nil
                }
            }
        }
        // A single enum-driven sheet. Stacking many `.sheet(isPresented:)` modifiers on
        // one view is unreliable in SwiftUI (later modifiers shadow earlier ones, which is
        // why the Organizations button silently did nothing) — one `.sheet(item:)` is the
        // robust pattern and matches HomeView.
        .sheet(item: $activeSheet, onDismiss: {
            Task { await feedVM.loadUserPosts(userId: authManager.currentUserId ?? 0) }
        }) { sheet in
            switch sheet {
            case .settings:
                NavigationStack {
                    PrivacyView()
                        .navigationTitle("Settings")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .topBarLeading) {
                                Button("Close") { activeSheet = nil }
                                    .foregroundColor(Color.nostiaAccent)
                            }
                            if user?.isAdmin == true {
                                ToolbarItem(placement: .topBarTrailing) {
                                    Button("Analytics") { activeSheet = .analytics }
                                        .foregroundColor(Color.nostiaAccent)
                                }
                            }
                        }
                        .toolbarBackground(.hidden, for: .navigationBar)
                }
                .presentationBackground(Color.nostiaBackground)
            case .organizations:
                OrganizationsHubView()
            case .analytics:
                NavigationStack {
                    AnalyticsView()
                        .navigationTitle("Analytics")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .topBarLeading) {
                                Button("Close") { activeSheet = nil }
                                    .foregroundColor(Color.nostiaAccent)
                            }
                        }
                        .toolbarBackground(.hidden, for: .navigationBar)
                }
                .presentationBackground(Color.nostiaBackground)
            case .createPost:
                CreatePostSheet(vm: feedVM)
            case .editPost(let post):
                EditPostSheet(post: post, feedVM: feedVM)
            case .comments(let post):
                CommentsSheet(postId: post.id, vm: feedVM)
                    .onAppear { Task { await feedVM.loadComments(for: post) } }
            }
        }
        .alert("Error", isPresented: Binding(
            get: { feedVM.errorMessage != nil },
            set: { if !$0 { feedVM.errorMessage = nil } }
        )) {
            Button("OK") { feedVM.errorMessage = nil }
        } message: {
            Text(feedVM.errorMessage ?? "")
        }
    }

    // MARK: - Visited tab visibility control (owner only)

    private var visitedVisibilityControl: some View {
        VStack(alignment: .leading, spacing: responsive.spacing(8)) {
            HStack(spacing: 6) {
                Text("Who can see your Visited tab")
                    .font(.caption).foregroundColor(Color.nostiaTextSecond)
                if isUpdatingVisibility {
                    ProgressView().tint(Color.nostiaAccent).scaleEffect(0.7)
                }
            }
            HStack(spacing: 8) {
                ForEach(visitedVisibilityOptions, id: \.self) { opt in
                    FilterChip(title: visibilityLabel(opt), isActive: visitedVisibility == opt) {
                        guard visitedVisibility != opt else { return }
                        Task { await updateVisitedVisibility(opt) }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, responsive.spacing(20))
        .padding(.top, 4)
    }

    private let visitedVisibilityOptions = ["public", "followers", "private"]

    private func visibilityLabel(_ value: String) -> String {
        switch value {
        case "public": return "Public"
        case "private": return "Private"
        default: return "Followers"
        }
    }

    private func updateVisitedVisibility(_ value: String) async {
        let previous = visitedVisibility
        visitedVisibility = value
        isUpdatingVisibility = true
        do {
            let updated = try await ProfileAPI.shared.setVisitedVisibility(value)
            user = updated
            visitedVisibility = updated.visitedTabVisibility
        } catch {
            visitedVisibility = previous
        }
        isUpdatingVisibility = false
    }

    private func loadProfile() async {
        isLoading = true
        user = try? await AuthAPI.shared.getMe()
        visitedVisibility = user?.visitedTabVisibility ?? "followers"
        isLoading = false
    }

    private func saveProfile() async {
        isSaving = true
        errorMessage = nil
        let trimmed = editBio.trimmingCharacters(in: .whitespacesAndNewlines)
        do {
            let updated = try await ProfileAPI.shared.updateProfile(bio: trimmed, profilePictureData: editImageData)
            user = updated
            isEditing = false
            NotificationCenter.default.post(name: .profileUpdated, object: nil)
        } catch {
            errorMessage = error.localizedDescription
        }
        isSaving = false
    }
}

// MARK: - Profile Crop View

struct ProfileCropView: View {
    let image: UIImage
    let onConfirm: (UIImage) -> Void
    let onCancel: () -> Void

    private let cropSize: CGFloat = 280

    @State private var scale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @GestureState private var gestureScale: CGFloat = 1.0
    @GestureState private var gestureDrag: CGSize = .zero

    private var baseScale: CGFloat {
        max(cropSize / image.size.width, cropSize / image.size.height)
    }

    private var displaySize: CGSize {
        CGSize(
            width: image.size.width * baseScale * scale,
            height: image.size.height * baseScale * scale
        )
    }

    private var maxOffset: CGSize {
        CGSize(
            width: max(0, (displaySize.width - cropSize) / 2),
            height: max(0, (displaySize.height - cropSize) / 2)
        )
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .scaleEffect(scale * gestureScale, anchor: .center)
                .offset(
                    x: offset.width + gestureDrag.width,
                    y: offset.height + gestureDrag.height
                )
                .frame(width: cropSize, height: cropSize)
                .clipShape(Circle())
                .gesture(
                    DragGesture()
                        .updating($gestureDrag) { v, state, _ in state = v.translation }
                        .onEnded { v in
                            let proposed = CGSize(
                                width: offset.width + v.translation.width,
                                height: offset.height + v.translation.height
                            )
                            offset = clamped(proposed)
                        }
                )
                .simultaneousGesture(
                    MagnificationGesture()
                        .updating($gestureScale) { v, state, _ in state = v }
                        .onEnded { v in
                            scale = max(1.0, min(5.0, scale * v))
                            offset = clamped(offset)
                        }
                )

            ZStack {
                Rectangle()
                    .fill(Color.black.opacity(0.55))
                    .ignoresSafeArea()
                Circle()
                    .frame(width: cropSize, height: cropSize)
                    .blendMode(.destinationOut)
            }
            .compositingGroup()
            .ignoresSafeArea()
            .allowsHitTesting(false)

            Circle()
                .stroke(Color.white.opacity(0.6), lineWidth: 1.5)
                .frame(width: cropSize, height: cropSize)
                .allowsHitTesting(false)

            VStack {
                HStack {
                    Button("Cancel") { onCancel() }
                        .font(.body.weight(.medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 20).padding(.vertical, 12)
                    Spacer()
                }
                .padding(.top, 8)

                Spacer()

                Button {
                    onConfirm(renderCrop())
                } label: {
                    Text("Use Photo")
                        .font(.headline).foregroundColor(.white)
                        .frame(maxWidth: .infinity).padding(16)
                        .background(Color.nostiaAccent).cornerRadius(14)
                }
                .padding(.horizontal, 24).padding(.bottom, 40)
            }
        }
    }

    private func clamped(_ proposed: CGSize) -> CGSize {
        let m = maxOffset
        return CGSize(
            width: proposed.width.clamped(to: -m.width...m.width),
            height: proposed.height.clamped(to: -m.height...m.height)
        )
    }

    private func renderCrop() -> UIImage {
        let outputSize = CGSize(width: cropSize, height: cropSize)
        let renderer = UIGraphicsImageRenderer(size: outputSize)
        return renderer.image { _ in
            let dW = image.size.width * baseScale * scale
            let dH = image.size.height * baseScale * scale
            let x = (cropSize - dW) / 2 + offset.width
            let y = (cropSize - dH) / 2 + offset.height
            UIBezierPath(ovalIn: CGRect(origin: .zero, size: outputSize)).addClip()
            image.draw(in: CGRect(x: x, y: y, width: dW, height: dH))
        }
    }
}

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}

// Profile tab switcher (spec §4): Posts | Visited.
enum ProfileTab: Hashable {
    case posts
    case visited
}

// Every modal the Profile screen can present, driven through one `.sheet(item:)`.
enum ProfileSheet: Identifiable {
    case settings
    case organizations
    case analytics
    case createPost
    case editPost(FeedPost)
    case comments(FeedPost)

    var id: String {
        switch self {
        case .settings:           return "settings"
        case .organizations:      return "organizations"
        case .analytics:          return "analytics"
        case .createPost:         return "createPost"
        case .editPost(let post): return "editPost-\(post.id)"
        case .comments(let post): return "comments-\(post.id)"
        }
    }
}

extension Notification.Name {
    static let profileUpdated = Notification.Name("com.nostia.profileUpdated")
}
