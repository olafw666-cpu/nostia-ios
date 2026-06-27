import SwiftUI
import PhotosUI

// Organization creation screen (Section 2). Mirrors the profile builder, adapted for an
// org: image, name (required), description, location-verification toggle → zone editor,
// post-permission and privacy settings.
struct CreateOrganizationView: View {
    var onCreated: (Organization) -> Void

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var responsive: ResponsiveLayoutManager

    @State private var name = ""
    @State private var description = ""
    @State private var rulesText = ""
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var imageData: String?

    @State private var locationEnabled = false
    @State private var zones: [ZoneDraft] = []

    @State private var postPermission = "members"   // "members" | "locked"
    @State private var privacy = "public"           // "public" | "private"

    @State private var isSaving = false
    @State private var errorMessage: String?

    private var canCreate: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty &&
        (!locationEnabled || !zones.isEmpty)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    imagePicker

                    NostiaTextField(label: "Organization Name *",
                                    placeholder: "How members find you", text: $name)

                    descriptionField

                    locationSection

                    postPermissionSection

                    privacySection

                    rulesField

                    if let err = errorMessage {
                        Text(err).font(.footnote).foregroundColor(Color.nostriaDanger)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(12)
                            .nostiaCard(in: RoundedRectangle(cornerRadius: 8))
                    }

                    createButton
                }
                .padding(20)
                .frame(maxWidth: responsive.sheetMaxWidth)
                .frame(maxWidth: .infinity)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(.clear)
            .navigationTitle("New Organization")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }.foregroundColor(Color.nostiaTextSecond)
                }
                // TextEditor inserts a newline on Return, so without an explicit dismiss the
                // keyboard can trap the user in the description/rules fields. Mirrors the
                // keyboard toolbar used in CreateExpenseSheet.
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    }
                    .foregroundColor(Color.nostiaAccent)
                }
            }
            .onChange(of: selectedPhoto) { _, item in
                Task {
                    if let data = try? await item?.loadTransferable(type: Data.self),
                       let img = UIImage(data: data),
                       let compressed = img.resizedForUpload().jpegData(compressionQuality: 0.4) {
                        imageData = compressed.base64EncodedString()
                    }
                }
            }
        }
        .presentationBackground(Color.nostiaBackground)
    }

    // MARK: - Sections

    private var imagePicker: some View {
        ZStack(alignment: .bottomTrailing) {
            UserAvatarView(imageData: imageData,
                           initial: name.isEmpty ? "O" : String(name.prefix(1)).uppercased(),
                           color: Color.nostriaPurple, size: 100)
            PhotosPicker(selection: $selectedPhoto, matching: .images) {
                Image(systemName: "camera.fill")
                    .font(.system(size: 14)).foregroundColor(.white)
                    .frame(width: 32, height: 32)
                    .background(Color.nostiaAccent).clipShape(Circle())
                    .overlay(Circle().stroke(Color(hex: "1A0E35"), lineWidth: 2))
            }
            .offset(x: 4, y: 4)
        }
        .padding(.top, 8)
    }

    private var descriptionField: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Description")
                .font(.system(size: 14, weight: .semibold)).foregroundColor(Color.nostiaTextSecond)
            TextEditor(text: $description)
                .frame(minHeight: 80).padding(8)
                .foregroundColor(Color.nostiaTextPrimary).scrollContentBackground(.hidden)
                .nostiaCard(in: RoundedRectangle(cornerRadius: 12))
        }
    }

    private var locationSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Toggle(isOn: $locationEnabled) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Location Verification").font(.system(size: 15, weight: .semibold)).foregroundColor(Color.nostiaTextPrimary)
                    Text("Require members to be inside an allowed area to join")
                        .font(.caption).foregroundColor(Color.nostiaTextMuted)
                }
            }
            .tint(Color.nostiaAccent)

            if locationEnabled {
                NavigationLink {
                    ZoneEditorView(zones: $zones)
                } label: {
                    HStack {
                        Image(systemName: "map.circle.fill").foregroundColor(Color.nostiaAccent)
                        Text(zones.isEmpty ? "Define verification zones" : "\(zones.count) zone\(zones.count == 1 ? "" : "s") defined")
                            .foregroundColor(Color.nostiaTextPrimary)
                        Spacer()
                        Image(systemName: "chevron.right").foregroundColor(Color.nostiaTextMuted)
                    }
                    .padding(14)
                    .nostiaCard(in: RoundedRectangle(cornerRadius: 12))
                }
                if zones.isEmpty {
                    Text("At least one zone is required when verification is on.")
                        .font(.caption).foregroundColor(Color.nostiaWarning)
                }
            }
        }
        .padding(14)
        .nostiaCard(in: RoundedRectangle(cornerRadius: 14))
    }

    private var postPermissionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Who can post").font(.system(size: 14, weight: .semibold)).foregroundColor(Color.nostiaTextSecond)
            Picker("", selection: $postPermission) {
                Text("All members").tag("members")
                Text("Admins only").tag("locked")
            }
            .pickerStyle(.segmented)
            Text(postPermission == "members"
                 ? "Any member can create org posts and experiences."
                 : "Only admins and the owner can post.")
                .font(.caption).foregroundColor(Color.nostiaTextMuted)
        }
    }

    private var privacySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Privacy").font(.system(size: 14, weight: .semibold)).foregroundColor(Color.nostiaTextSecond)
            Picker("", selection: $privacy) {
                Text("Public").tag("public")
                Text("Private").tag("private")
            }
            .pickerStyle(.segmented)
            Text(privacy == "public"
                 ? "Appears in search; anyone can attempt to join."
                 : "Appears in search; join requests need approval.")
                .font(.caption).foregroundColor(Color.nostiaTextMuted)
        }
    }

    private var rulesField: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Rules / Guidelines (optional)")
                .font(.system(size: 14, weight: .semibold)).foregroundColor(Color.nostiaTextSecond)
            TextEditor(text: $rulesText)
                .frame(minHeight: 60).padding(8)
                .foregroundColor(Color.nostiaTextPrimary).scrollContentBackground(.hidden)
                .nostiaCard(in: RoundedRectangle(cornerRadius: 12))
        }
    }

    private var createButton: some View {
        Button {
            Task { await create() }
        } label: {
            HStack {
                if isSaving { ProgressView().tint(.white) }
                else { Text("Create Organization").fontWeight(.bold) }
            }
            .frame(maxWidth: .infinity).padding()
            .background(canCreate
                        ? AnyShapeStyle(LinearGradient(colors: [Color.nostiaAccent, Color.nostriaPurple],
                                                       startPoint: .leading, endPoint: .trailing))
                        : AnyShapeStyle(Color.nostiaInput))
            .foregroundColor(.white).cornerRadius(14)
        }
        .disabled(!canCreate || isSaving)
    }

    private func create() async {
        errorMessage = nil
        isSaving = true
        defer { isSaving = false }
        do {
            let org = try await OrganizationsAPI.shared.create(
                name: name.trimmingCharacters(in: .whitespaces),
                description: description.isEmpty ? nil : description,
                imageData: imageData,
                locationVerificationEnabled: locationEnabled,
                postPermission: postPermission,
                privacy: privacy,
                rulesText: rulesText.isEmpty ? nil : rulesText,
                zones: locationEnabled ? zones : []
            )
            Haptics.success()
            onCreated(org)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
