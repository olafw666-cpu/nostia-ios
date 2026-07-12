import SwiftUI
import PhotosUI

struct CreatePostSheet: View {
    @ObservedObject var vm: FeedViewModel
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var editorImage: EditableImage?
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var responsive: ResponsiveLayoutManager

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: responsive.spacing(16)) {
                    // Text input
                    TextField("What's on your mind?", text: $vm.newPostContent, axis: .vertical)
                        .lineLimit(4...10)
                        .padding(responsive.spacing(14))
                        .nostiaCard(in: RoundedRectangle(cornerRadius: 14))
                        .foregroundColor(Color.nostiaTextPrimary)

                    // Photo preview — rendered with the same clamped aspect ratio as
                    // PostCard (1.91:1 … 3:4) so the user sees exactly what will appear
                    // in the feed, including any center-crop of extreme ratios.
                    if let imgData = vm.newPostImageData,
                       let data = Data(base64Encoded: imgData),
                       let uiImage = UIImage(data: data), uiImage.size.height > 0 {
                        let displayRatio = min(max(uiImage.size.width / uiImage.size.height, 3.0 / 4.0), 1.91)
                        ZStack(alignment: .topTrailing) {
                            Color.clear
                                .aspectRatio(displayRatio, contentMode: .fit)
                                .frame(maxWidth: .infinity)
                                .overlay(
                                    Image(uiImage: uiImage)
                                        .resizable()
                                        .scaledToFill()
                                        .allowsHitTesting(false)
                                )
                                .clipped()
                                .cornerRadius(14)
                            Button {
                                vm.newPostImageData = nil
                                selectedPhoto = nil
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.title2).foregroundColor(.white)
                                    .shadow(radius: 3)
                                    .frame(width: 44, height: 44)
                            }
                            .buttonStyle(.nostiaTap)
                            .accessibilityLabel("Remove photo")
                        }
                    }

                    // Photo picker
                    PhotosPicker(selection: $selectedPhoto, matching: .images) {
                        Label("Add Photo", systemImage: "photo.on.rectangle")
                            .foregroundColor(Color.nostiaAccent)
                            .frame(maxWidth: .infinity)
                            .padding(responsive.spacing(14))
                            .nostiaCard(in: RoundedRectangle(cornerRadius: 14))
                    }
                    .onChange(of: selectedPhoto) { _, item in
                        Task {
                            guard let item,
                                  let data = try? await item.loadTransferable(type: Data.self),
                                  let img = UIImage(data: data) else { return }
                            // The feed shows photos between 1.91:1 and 3:4 in full.
                            // Landscape photos keep the fit-vs-crop choice; photos taller
                            // than 3:4 (e.g. 9:16 screenshots) would be auto-cropped, so
                            // the editor lets the user pick what's kept. Portrait/square
                            // photos inside the range display in full — attach as-is.
                            let ratio = img.size.height > 0 ? img.size.width / img.size.height : 1
                            if img.size.width > img.size.height || ratio < 3.0 / 4.0 {
                                editorImage = EditableImage(image: img)
                            } else {
                                attach(img)
                            }
                        }
                    }
                }
                .padding(responsive.spacing(16))
                .frame(maxWidth: responsive.sheetMaxWidth)
                .frame(maxWidth: .infinity)
            }
            .background(.clear)
            .navigationTitle("New Post")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        vm.newPostContent = ""
                        vm.newPostImageData = nil
                        selectedPhoto = nil
                        vm.showCreateSheet = false
                        dismiss()
                    }
                    .foregroundColor(Color.nostiaTextSecond)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task {
                            await vm.createPost()
                            if vm.errorMessage == nil { dismiss() }
                        }
                    } label: {
                        if vm.isSubmitting {
                            ProgressView().tint(.white)
                        } else {
                            Text("Post").fontWeight(.semibold).foregroundColor(Color.nostiaAccent)
                        }
                    }
                    .disabled(vm.isSubmitting || (vm.newPostContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && vm.newPostImageData == nil))
                }
            }
        }
        .presentationBackground(Color.nostiaBackground)
        .fullScreenCover(item: $editorImage) { wrapper in
            PostImageEditor(image: wrapper.image) { finalImage in
                attach(finalImage)
                editorImage = nil
                selectedPhoto = nil
            } onCancel: {
                editorImage = nil
                selectedPhoto = nil
            }
        }
    }

    /// Compresses the chosen image and stores it on the view model for upload.
    private func attach(_ image: UIImage) {
        if let compressed = image.resizedForUpload().jpegData(compressionQuality: 0.4) {
            vm.newPostImageData = compressed.base64EncodedString()
        }
    }
}

/// Identifiable wrapper so a picked `UIImage` can drive a `.fullScreenCover(item:)`.
struct EditableImage: Identifiable {
    let id = UUID()
    let image: UIImage
}
