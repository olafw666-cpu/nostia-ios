import SwiftUI
import PhotosUI

struct ProfileView: View {
    @EnvironmentObject var authManager: AuthManager
    @State private var user: User?
    @State private var isLoading = true
    @State private var isEditing = false
    @State private var showSettings = false
    @State private var showAnalytics = false
    @State private var editBio = ""
    @State private var editImageData: String?
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var isSaving = false
    @State private var errorMessage: String?

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                if isLoading {
                    ProgressView().tint(Color.nostiaAccent).padding(60)
                } else if let u = user {
                    // Profile picture
                    ZStack(alignment: .bottomTrailing) {
                        UserAvatarView(
                            imageData: isEditing ? editImageData : u.profilePictureUrl,
                            initial: u.initial,
                            color: Color.nostiaAccent,
                            size: 100
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
                    .padding(.top, 8)

                    // Username (read-only)
                    Text("@\(u.username)")
                        .font(.title2.bold())
                        .foregroundColor(.white)

                    // Bio
                    if isEditing {
                        VStack(alignment: .leading, spacing: 4) {
                            ZStack(alignment: .topLeading) {
                                if editBio.isEmpty {
                                    Text("Write a short bio...")
                                        .foregroundColor(Color.nostiaTextMuted)
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 14)
                                }
                                TextEditor(text: $editBio)
                                    .frame(minHeight: 80)
                                    .padding(8)
                                    .glassEffect(in: RoundedRectangle(cornerRadius: 12))
                                    .foregroundColor(.white)
                                    .scrollContentBackground(.hidden)
                            }
                            HStack {
                                Spacer()
                                Text("\(editBio.count)/100")
                                    .font(.caption)
                                    .foregroundColor(editBio.count > 100 ? Color.nostriaDanger : Color.nostiaTextMuted)
                            }
                        }
                        .padding(.horizontal, 20)
                    } else {
                        let bioText = u.bio?.isEmpty == false ? u.bio! : nil
                        Text(bioText ?? "No bio yet")
                            .font(.body)
                            .foregroundColor(bioText != nil ? .white : Color.nostiaTextMuted)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                    }

                    // Friends count
                    Text("\(u.friendsCount ?? 0) Friends")
                        .font(.subheadline.bold())
                        .foregroundColor(Color.nostiaTextSecond)

                    if let err = errorMessage {
                        Text(err)
                            .font(.caption)
                            .foregroundColor(Color.nostriaDanger)
                            .padding(.horizontal, 24)
                    }

                    Divider()
                        .background(Color.white.opacity(0.15))
                        .padding(.horizontal, 20)

                    // Buttons
                    if isEditing {
                        HStack(spacing: 12) {
                            Button("Cancel") {
                                isEditing = false
                                editBio = u.bio ?? ""
                                editImageData = u.profilePictureUrl
                                errorMessage = nil
                            }
                            .foregroundColor(Color.nostiaTextSecond)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .glassEffect(in: RoundedRectangle(cornerRadius: 14))

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
                                .padding()
                                .background(editBio.count > 100 ? Color.nostiaInput : Color.nostiaAccent)
                                .foregroundColor(.white)
                                .cornerRadius(14)
                            }
                            .disabled(isSaving || editBio.count > 100)
                        }
                        .padding(.horizontal, 20)
                    } else {
                        VStack(spacing: 12) {
                            Button {
                                editBio = u.bio ?? ""
                                editImageData = u.profilePictureUrl
                                isEditing = true
                            } label: {
                                Label("Edit Profile", systemImage: "pencil")
                                    .font(.subheadline.bold())
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .glassEffect(in: RoundedRectangle(cornerRadius: 14))
                            }
                            .padding(.horizontal, 20)

                            Button {
                                showSettings = true
                            } label: {
                                Label("Settings", systemImage: "gear")
                                    .font(.subheadline)
                                    .foregroundColor(Color.nostiaTextSecond)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .glassEffect(in: RoundedRectangle(cornerRadius: 14))
                            }
                            .padding(.horizontal, 20)
                        }
                    }
                }
            }
            .padding(.bottom, 40)
        }
        .background(.clear)
        .task { await loadProfile() }
        .onChange(of: selectedPhoto) { _, item in
            Task {
                if let data = try? await item?.loadTransferable(type: Data.self),
                   let img = UIImage(data: data),
                   let compressed = img.resizedForUpload().jpegData(compressionQuality: 0.4) {
                    editImageData = compressed.base64EncodedString()
                }
            }
        }
        .sheet(isPresented: $showSettings) {
            NavigationStack {
                PrivacyView()
                    .navigationTitle("Settings")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            Button("Close") { showSettings = false }
                                .foregroundColor(Color.nostiaAccent)
                        }
                        if user?.isAdmin == true {
                            ToolbarItem(placement: .topBarTrailing) {
                                Button("Analytics") { showAnalytics = true }
                                    .foregroundColor(Color.nostiaAccent)
                            }
                        }
                    }
                    .toolbarBackground(.hidden, for: .navigationBar)
            }
            .presentationBackground(.ultraThinMaterial)
        }
        .sheet(isPresented: $showAnalytics) {
            NavigationStack {
                AnalyticsView()
                    .navigationTitle("Analytics")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            Button("Close") { showAnalytics = false }
                                .foregroundColor(Color.nostiaAccent)
                        }
                    }
                    .toolbarBackground(.hidden, for: .navigationBar)
            }
            .presentationBackground(.ultraThinMaterial)
        }
    }

    private func loadProfile() async {
        isLoading = true
        user = try? await AuthAPI.shared.getMe()
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
        } catch {
            errorMessage = error.localizedDescription
        }
        isSaving = false
    }
}
