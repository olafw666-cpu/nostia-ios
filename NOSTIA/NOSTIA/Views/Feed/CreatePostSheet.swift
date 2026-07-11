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

                    // Photo preview — shown in full (no cropping) so the user sees exactly
                    // what will appear in the post.
                    if let imgData = vm.newPostImageData,
                       let data = Data(base64Encoded: imgData),
                       let uiImage = UIImage(data: data) {
                        ZStack(alignment: .topTrailing) {
                            Image(uiImage: uiImage)
                                .resizable().scaledToFit()
                                .frame(maxWidth: .infinity)
                                .frame(maxHeight: responsive.spacing(360))
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
                            // Landscape photos let the user choose crop vs. scale-to-fit.
                            // Portrait / square photos already display in full, so use them as-is.
                            if img.size.width > img.size.height {
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
