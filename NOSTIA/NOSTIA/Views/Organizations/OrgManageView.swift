import SwiftUI
import PhotosUI

// Org management view (Section 6). Accessed by owner/admin. Capabilities are gated per
// Section 5: role assignment, transfer and delete are owner-only.
struct OrgManageView: View {
    let orgId: Int
    var onChanged: (() -> Void)? = nil

    @Environment(\.dismiss) private var dismiss

    @State private var org: Organization?
    @State private var zones: [ZoneDraft] = []

    @State private var name = ""
    @State private var description = ""
    @State private var rulesText = ""
    @State private var postPermission = "members"
    @State private var privacy = "public"
    @State private var locationEnabled = false
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var imageData: String?

    @State private var isSaving = false
    @State private var statusMessage: String?
    @State private var showDeleteConfirm1 = false
    @State private var showDeleteConfirm2 = false

    private var isOwner: Bool { org?.isOwner ?? false }

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                profileSection
                settingsSection
                membersSection
                dangerSection
                if let statusMessage {
                    Text(statusMessage).font(.footnote).foregroundColor(Color.nostiaSuccess)
                }
            }
            .padding(16)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Color.nostiaBackground.ignoresSafeArea())
        .navigationTitle("Manage")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar {
            // Give the description/rules TextEditors an explicit keyboard dismiss (Return
            // only inserts a newline). Matches CreateOrganizationView / CreateExpenseSheet.
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                }
                .foregroundColor(Color.nostiaAccent)
            }
        }
        .task { await load() }
        .onChange(of: selectedPhoto) { _, item in
            Task {
                if let data = try? await item?.loadTransferable(type: Data.self),
                   let img = UIImage(data: data),
                   let compressed = img.resizedForUpload().jpegData(compressionQuality: 0.4) {
                    imageData = compressed.base64EncodedString()
                }
            }
        }
        .confirmationDialog("Delete this organization?", isPresented: $showDeleteConfirm1, titleVisibility: .visible) {
            Button("Continue", role: .destructive) { showDeleteConfirm2 = true }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("All posts, experiences and membership records will be permanently deleted.")
        }
        .confirmationDialog("This cannot be undone. Delete permanently?", isPresented: $showDeleteConfirm2, titleVisibility: .visible) {
            Button("Delete Organization", role: .destructive) { Task { await deleteOrg() } }
            Button("Cancel", role: .cancel) {}
        }
    }

    // MARK: - Sections

    private var profileSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Profile").font(.headline).foregroundColor(Color.nostiaTextPrimary)

            HStack {
                Spacer()
                ZStack(alignment: .bottomTrailing) {
                    UserAvatarView(imageData: imageData ?? org?.imageUrl,
                                   initial: name.isEmpty ? "O" : String(name.prefix(1)).uppercased(),
                                   color: Color.nostriaPurple, size: 84)
                    PhotosPicker(selection: $selectedPhoto, matching: .images) {
                        Image(systemName: "camera.fill").font(.nostiaBody(12)).foregroundColor(.white)
                            .frame(width: 28, height: 28).background(Color.nostiaAccent).clipShape(Circle())
                    }
                    .offset(x: 4, y: 4)
                }
                Spacer()
            }

            NostiaTextField(label: "Name", placeholder: "Organization name", text: $name)

            VStack(alignment: .leading, spacing: 6) {
                Text("Description").font(.nostiaBody(14, weight: .semibold)).foregroundColor(Color.nostiaTextSecond)
                TextEditor(text: $description).frame(minHeight: 70).padding(8)
                    .nostiaCard(in: RoundedRectangle(cornerRadius: 12))
                    .foregroundColor(Color.nostiaTextPrimary).scrollContentBackground(.hidden)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Rules & Guidelines").font(.nostiaBody(14, weight: .semibold)).foregroundColor(Color.nostiaTextSecond)
                TextEditor(text: $rulesText).frame(minHeight: 60).padding(8)
                    .nostiaCard(in: RoundedRectangle(cornerRadius: 12))
                    .foregroundColor(Color.nostiaTextPrimary).scrollContentBackground(.hidden)
            }

            Button { Task { await saveProfile() } } label: {
                HStack {
                    if isSaving { ProgressView().tint(.white) } else { Text("Save Profile").fontWeight(.bold) }
                }
                .frame(maxWidth: .infinity).padding()
                .background(Color.nostiaAccent).foregroundColor(.white).cornerRadius(12)
            }
            .disabled(isSaving)
        }
        .padding(16)
        .nostiaCard(in: RoundedRectangle(cornerRadius: 18))
    }

    private var settingsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Settings").font(.headline).foregroundColor(Color.nostiaTextPrimary)

            VStack(alignment: .leading, spacing: 6) {
                Text("Who can post").font(.caption).foregroundColor(Color.nostiaTextSecond)
                Picker("", selection: $postPermission) {
                    Text("All members").tag("members")
                    Text("Admins only").tag("locked")
                }
                .pickerStyle(.segmented)
                .onChange(of: postPermission) { _, v in
                    guard v != org?.postPermission else { return }   // ignore the value set during load
                    Task { await patch(["postPermission": v]) }
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Privacy").font(.caption).foregroundColor(Color.nostiaTextSecond)
                Picker("", selection: $privacy) {
                    Text("Public").tag("public")
                    Text("Private").tag("private")
                }
                .pickerStyle(.segmented)
                .onChange(of: privacy) { _, v in
                    guard v != org?.privacy else { return }
                    Task { await patch(["privacy": v]) }
                }
            }

            Toggle(isOn: $locationEnabled) {
                Text("Location Verification").foregroundColor(Color.nostiaTextPrimary)
            }
            .tint(Color.nostiaAccent)
            .onChange(of: locationEnabled) { _, v in
                guard v != (org?.locationVerificationEnabled ?? false) else { return }
                Task { await patch(["locationVerificationEnabled": v]) }
            }

            NavigationLink {
                ZoneEditorView(zones: $zones, onDone: { Task { await saveZones() } })
            } label: {
                HStack {
                    Image(systemName: "map.circle.fill").foregroundColor(Color.nostiaAccent)
                    Text(zones.isEmpty ? "Define verification zones" : "\(zones.count) zone\(zones.count == 1 ? "" : "s")")
                        .foregroundColor(Color.nostiaTextPrimary)
                    Spacer()
                    Image(systemName: "chevron.right").foregroundColor(Color.nostiaTextMuted)
                }
                .padding(14).nostiaCard(in: RoundedRectangle(cornerRadius: 12))
            }
        }
        .padding(16)
        .nostiaCard(in: RoundedRectangle(cornerRadius: 18))
    }

    private var membersSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Members").font(.headline).foregroundColor(Color.nostiaTextPrimary)
            if let org {
                NavigationLink {
                    OrgMembersView(org: org, onChanged: { Task { await load() }; onChanged?() })
                } label: {
                    HStack {
                        Image(systemName: "person.2.fill").foregroundColor(Color.nostiaAccent)
                        Text("Manage members & requests").foregroundColor(Color.nostiaTextPrimary)
                        Spacer()
                        Image(systemName: "chevron.right").foregroundColor(Color.nostiaTextMuted)
                    }
                    .padding(14).nostiaCard(in: RoundedRectangle(cornerRadius: 12))
                }
            }
        }
        .padding(16)
        .nostiaCard(in: RoundedRectangle(cornerRadius: 18))
    }

    @ViewBuilder
    private var dangerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            if isOwner {
                Button(role: .destructive) { showDeleteConfirm1 = true } label: {
                    Label("Delete Organization", systemImage: "trash")
                        .frame(maxWidth: .infinity).padding()
                        .background(Color.nostriaDanger.opacity(0.15)).foregroundColor(Color.nostriaDanger)
                        .cornerRadius(12)
                }
            } else {
                // Admins may leave directly (Section 5). Owners must transfer first.
                Button(role: .destructive) { Task { await leave() } } label: {
                    Label("Leave Organization", systemImage: "rectangle.portrait.and.arrow.right")
                        .frame(maxWidth: .infinity).padding()
                        .background(Color.nostriaDanger.opacity(0.15)).foregroundColor(Color.nostriaDanger)
                        .cornerRadius(12)
                }
            }
        }
    }

    // MARK: - Actions

    private func load() async {
        guard let fresh = try? await OrganizationsAPI.shared.get(id: orgId) else { return }
        org = fresh
        name = fresh.name
        description = fresh.description ?? ""
        rulesText = fresh.rulesText ?? ""
        postPermission = fresh.postPermission
        privacy = fresh.privacy
        locationEnabled = fresh.locationVerificationEnabled
        if let serverZones = try? await OrganizationsAPI.shared.getZones(id: orgId) {
            zones = serverZones.map { ZoneDraft.from($0) }
        }
    }

    private func saveProfile() async {
        isSaving = true
        defer { isSaving = false }
        var fields: [String: Any] = [
            "name": name.trimmingCharacters(in: .whitespaces),
            "description": description,
            "rulesText": rulesText
        ]
        if let imageData { fields["imageData"] = imageData }
        await patch(fields, message: "Profile saved")
    }

    private func patch(_ fields: [String: Any], message: String? = nil) async {
        do {
            org = try await OrganizationsAPI.shared.update(id: orgId, fields: fields)
            statusMessage = message
            onChanged?()
        } catch {
            statusMessage = nil
        }
    }

    private func saveZones() async {
        _ = try? await OrganizationsAPI.shared.setZones(id: orgId, zones: zones)
        onChanged?()
    }

    private func deleteOrg() async {
        do {
            try await OrganizationsAPI.shared.delete(id: orgId)
            Haptics.success()
            onChanged?()
            dismiss()
        } catch { statusMessage = nil }
    }

    private func leave() async {
        do {
            try await OrganizationsAPI.shared.leave(id: orgId)
            Haptics.success()
            onChanged?()
            dismiss()
        } catch { statusMessage = nil }
    }
}
