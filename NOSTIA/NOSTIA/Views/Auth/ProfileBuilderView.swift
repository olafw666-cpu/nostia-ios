import SwiftUI
import PhotosUI

struct ProfileBuilderView: View {
    let onComplete: () -> Void

    @State private var username = ""
    @State private var bio = ""
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var profileImageData: String?
    @State private var isSaving = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {
                    // Profile picture picker
                    ZStack(alignment: .bottomTrailing) {
                        UserAvatarView(
                            imageData: profileImageData,
                            initial: username.isEmpty ? "U" : String(username.prefix(1)).uppercased(),
                            color: Color.nostiaAccent,
                            size: 100
                        )
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
                    .padding(.top, 12)

                    // Read-only username display
                    if !username.isEmpty {
                        Text("@\(username)")
                            .font(.title3.bold())
                            .foregroundColor(.white)
                    }

                    // Bio field
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Bio")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white.opacity(0.7))
                        ZStack(alignment: .topLeading) {
                            if bio.isEmpty {
                                Text("Write a short bio...")
                                    .foregroundColor(Color.nostiaTextMuted)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 14)
                            }
                            TextEditor(text: $bio)
                                .frame(minHeight: 88)
                                .padding(8)
                                .foregroundColor(.white)
                                .scrollContentBackground(.hidden)
                        }
                        .glassEffect(in: RoundedRectangle(cornerRadius: 12))

                        HStack {
                            Spacer()
                            Text("\(bio.count)/100")
                                .font(.caption)
                                .foregroundColor(bio.count > 100 ? Color.nostriaDanger : Color.nostiaTextMuted)
                        }
                    }

                    Button {
                        Task { await save() }
                    } label: {
                        HStack {
                            if isSaving {
                                ProgressView().tint(.white)
                            } else {
                                Text("Continue").fontWeight(.bold)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            bio.count > 100
                                ? AnyShapeStyle(Color.nostiaInput)
                                : AnyShapeStyle(LinearGradient(
                                    colors: [Color.nostiaAccent, Color.nostriaPurple],
                                    startPoint: .leading, endPoint: .trailing
                                ))
                        )
                        .foregroundColor(.white)
                        .cornerRadius(14)
                    }
                    .disabled(isSaving || bio.count > 100)
                }
                .padding(24)
            }
            .background(.clear)
            .navigationTitle("Build Your Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Skip") { onComplete() }
                        .foregroundColor(Color.nostiaTextSecond)
                }
            }
        }
        .presentationBackground(.ultraThinMaterial)
        .task { await loadUsername() }
        .onChange(of: selectedPhoto) { _, item in
            Task {
                if let data = try? await item?.loadTransferable(type: Data.self),
                   let img = UIImage(data: data),
                   let compressed = img.resizedForUpload().jpegData(compressionQuality: 0.4) {
                    profileImageData = compressed.base64EncodedString()
                }
            }
        }
    }

    private func loadUsername() async {
        username = (try? await AuthAPI.shared.getMe())?.username ?? ""
    }

    private func save() async {
        isSaving = true
        let trimmed = bio.trimmingCharacters(in: .whitespacesAndNewlines)
        _ = try? await ProfileAPI.shared.updateProfile(bio: trimmed, profilePictureData: profileImageData)
        isSaving = false
        onComplete()
    }
}
