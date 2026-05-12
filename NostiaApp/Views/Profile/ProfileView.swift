import SwiftUI
import PhotosUI

// MARK: - Profile View

struct ProfileView: View {
    @EnvironmentObject var authManager: AuthManager
    @State private var user: User?
    @State private var isLoading = false
    @State private var isSaving = false
    @State private var pickerItem: PhotosPickerItem?
    @State private var imageToCrop: UIImage?
    @State private var showCrop = false
    @State private var errorMessage: String?

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 20) {
                if isLoading {
                    ProgressView().tint(Color.nostiaAccent).padding(40)
                } else {
                    // Profile header card
                    VStack(spacing: 16) {
                        ZStack(alignment: .bottomTrailing) {
                            ProfilePictureView(
                                urlString: user?.profilePictureUrl,
                                initial: user?.initial ?? "?",
                                size: 96
                            )
                            PhotosPicker(selection: $pickerItem, matching: .images, photoLibrary: .shared()) {
                                Image(systemName: "pencil.circle.fill")
                                    .font(.system(size: 26))
                                    .foregroundColor(Color.nostiaAccent)
                                    .background(
                                        Circle().fill(Color.nostiaBackground).padding(-3)
                                    )
                            }
                        }

                        if isSaving {
                            ProgressView().tint(Color.nostiaAccent)
                        }

                        if let u = user {
                            Text(u.name)
                                .font(.title2.bold()).foregroundColor(.white)
                            Text("@\(u.username)")
                                .font(.subheadline).foregroundColor(Color.nostiaTextSecond)
                            if let bio = u.bio, !bio.isEmpty {
                                Text(bio)
                                    .font(.body).foregroundColor(Color.nostiaTextSecond)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 8)
                            }
                        }
                    }
                    .padding(24)
                    .glassEffect(in: RoundedRectangle(cornerRadius: 20))

                    if let msg = errorMessage {
                        Text(msg)
                            .font(.footnote).foregroundColor(Color.nostriaDanger)
                            .padding(12)
                            .glassEffect(in: RoundedRectangle(cornerRadius: 10))
                    }
                }
            }
            .padding(16)
            .padding(.bottom, 40)
        }
        .background(.clear)
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.inline)
        .task { await loadUser() }
        .onChange(of: pickerItem) { _, item in
            Task {
                guard let item else { return }
                if let data = try? await item.loadTransferable(type: Data.self),
                   let img = UIImage(data: data) {
                    imageToCrop = img
                    showCrop = true
                }
                pickerItem = nil
            }
        }
        .fullScreenCover(isPresented: $showCrop) {
            if let img = imageToCrop {
                ProfileCropView(image: img) { cropped in
                    showCrop = false
                    imageToCrop = nil
                    Task { await uploadProfilePicture(cropped) }
                } onCancel: {
                    showCrop = false
                    imageToCrop = nil
                }
            }
        }
    }

    private func loadUser() async {
        isLoading = true
        user = try? await AuthAPI.shared.getMe()
        isLoading = false
    }

    private func uploadProfilePicture(_ image: UIImage) async {
        isSaving = true
        errorMessage = nil
        // Resize to max 400x400 for storage efficiency
        let targetSize = CGSize(width: 400, height: 400)
        let renderer = UIGraphicsImageRenderer(size: targetSize)
        let resized = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }
        guard let jpegData = resized.jpegData(compressionQuality: 0.75) else {
            isSaving = false
            return
        }
        let base64 = jpegData.base64EncodedString()
        let dataURL = "data:image/jpeg;base64,\(base64)"
        if let updated = try? await AuthAPI.shared.updateMe(["profile_picture_url": dataURL]) {
            user = updated
        } else {
            errorMessage = "Failed to save profile picture."
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

            // Image with pan/zoom gestures
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

            // Dimmed overlay with circle cutout
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

            // Circle guide stroke
            Circle()
                .stroke(Color.white.opacity(0.6), lineWidth: 1.5)
                .frame(width: cropSize, height: cropSize)
                .allowsHitTesting(false)

            // Controls
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

// MARK: - Comparable clamp helper

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
