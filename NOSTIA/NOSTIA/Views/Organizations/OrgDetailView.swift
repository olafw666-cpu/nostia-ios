import SwiftUI
import CoreLocation

// Org page (Section 4) and member home. Non-members see the profile + a Join button
// (with the location gate when required). Members see org-only posts and events.
struct OrgDetailView: View {
    let orgId: Int
    var onChanged: (() -> Void)? = nil

    @EnvironmentObject private var locationManager: LocationManager
    @EnvironmentObject private var authManager: AuthManager
    @Environment(\.dismiss) private var dismiss

    @State private var org: Organization?
    @State private var isLoading = true
    @State private var segment = 0            // 0 = Posts, 1 = Events
    @State private var isJoining = false
    @State private var pendingJoin = false    // waiting on a fresh GPS fix to join
    @State private var alertMessage: String?
    @State private var showLeaveConfirm = false
    @State private var showDevDeleteConfirm = false

    private var myRole: String? { org?.myRole }

    var body: some View {
        Group {
            if let org {
                content(org)
            } else if isLoading {
                LoadingView()
            } else {
                EmptyStateView(icon: "building.2", text: "Organization not found", sub: "")
            }
        }
        // Pushed inside the org hub's NavigationStack — themed canvas doesn't inherit.
        .background(Color.nostiaBackground.ignoresSafeArea())
        .navigationTitle(org?.name ?? "Organization")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar {
            if let org {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    if org.canManage {
                        NavigationLink {
                            OrgManageView(orgId: org.id, onChanged: { Task { await load() }; onChanged?() })
                        } label: {
                            Image(systemName: "gearshape").foregroundColor(Color.nostiaTextPrimary)
                        }
                    }
                    // Dev accounts may delete ANY org (owner already has delete via Manage);
                    // plain members get their Leave action here.
                    if org.myRole == "member" || (authManager.isDev && !org.isOwner) {
                        Menu {
                            if org.myRole == "member" {
                                Button(role: .destructive) { showLeaveConfirm = true } label: {
                                    Label("Leave organization", systemImage: "rectangle.portrait.and.arrow.right")
                                }
                            }
                            if authManager.isDev && !org.isOwner {
                                Button(role: .destructive) { showDevDeleteConfirm = true } label: {
                                    Label("Delete Organization (Dev)", systemImage: "trash")
                                }
                            }
                        } label: {
                            Image(systemName: "ellipsis").foregroundColor(Color.nostiaTextPrimary)
                        }
                    }
                }
            }
        }
        .task { await load() }
        .onChange(of: locationManager.location) { _, loc in
            if pendingJoin, let loc {
                pendingJoin = false
                Task { await doJoin(lat: loc.coordinate.latitude, lng: loc.coordinate.longitude) }
            }
        }
        .onChange(of: locationManager.permissionDenied) { _, denied in
            if denied && pendingJoin {
                pendingJoin = false
                alertMessage = "Location access is required to join this organization. Enable it in Settings and try again."
            }
        }
        .confirmationDialog("Leave this organization?", isPresented: $showLeaveConfirm, titleVisibility: .visible) {
            Button("Leave", role: .destructive) { Task { await leave() } }
            Button("Cancel", role: .cancel) {}
        }
        .confirmationDialog("Delete this organization?", isPresented: $showDevDeleteConfirm, titleVisibility: .visible) {
            Button("Delete Organization", role: .destructive) { Task { await devDeleteOrg() } }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Dev action: all posts, experiences and membership records will be permanently deleted. This cannot be undone.")
        }
        .alert("Organization", isPresented: Binding(
            get: { alertMessage != nil }, set: { if !$0 { alertMessage = nil } }
        )) { Button("OK") { alertMessage = nil } } message: { Text(alertMessage ?? "") }
    }

    @ViewBuilder
    private func content(_ org: Organization) -> some View {
        if org.isMember {
            VStack(spacing: 0) {
                Picker("", selection: $segment) {
                    Text("Posts").tag(0)
                    Text("Experiences").tag(1)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16).padding(.top, 12)

                if segment == 0 {
                    OrgPostsView(org: org)
                } else {
                    OrgEventsView(org: org)
                }
            }
        } else {
            ScrollView {
                VStack(spacing: 18) {
                    header(org)
                    joinCard(org)
                    if let rules = org.rulesText, !rules.isEmpty {
                        infoBlock(title: "Rules & Guidelines", text: rules)
                    }
                }
                .padding(20)
            }
            .background(.clear)
        }
    }

    private func header(_ org: Organization) -> some View {
        VStack(spacing: 12) {
            UserAvatarView(imageData: org.imageUrl, initial: org.initial, color: Color.nostriaPurple, size: 96)
            Text(org.name).font(.nostiaDisplay(22, weight: .heavy)).foregroundColor(Color.nostiaTextPrimary)
            HStack(spacing: 12) {
                Label("\(org.memberCount) member\(org.memberCount == 1 ? "" : "s")", systemImage: "person.2")
                Label(org.privacy.capitalized, systemImage: org.privacy == "private" ? "lock" : "globe")
                if org.locationVerificationEnabled {
                    Label("Location-gated", systemImage: "mappin.and.ellipse")
                }
            }
            .font(.caption).foregroundColor(Color.nostiaTextSecond)
            if let desc = org.description, !desc.isEmpty {
                Text(desc).font(.subheadline).foregroundColor(Color.nostiaTextSecond)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .nostiaCard(in: RoundedRectangle(cornerRadius: 20))
    }

    private func joinCard(_ org: Organization) -> some View {
        VStack(spacing: 10) {
            // Devs can always join directly (server bypasses the gates), even with a
            // pending request outstanding — the direct join consumes it.
            if org.hasPendingRequest && !authManager.isDev {
                Label("Request pending approval", systemImage: "clock")
                    .font(.subheadline.bold()).foregroundColor(Color.nostiaWarning)
            } else {
                if authManager.isDev {
                    Text("Dev account: location and approval requirements are bypassed.")
                        .font(.caption).foregroundColor(Color.nostiaTextMuted)
                        .multilineTextAlignment(.center)
                } else {
                    if org.locationVerificationEnabled {
                        Text("You must be within the organization's allowed area to \(org.privacy == "private" ? "request to join" : "join").")
                            .font(.caption).foregroundColor(Color.nostiaTextMuted)
                            .multilineTextAlignment(.center)
                    }
                    if org.privacy == "private" {
                        Text("This is a private organization. Your request will be reviewed.")
                            .font(.caption).foregroundColor(Color.nostiaTextMuted)
                            .multilineTextAlignment(.center)
                    }
                }
                Button {
                    Task { await attemptJoin() }
                } label: {
                    HStack {
                        if isJoining || pendingJoin { ProgressView().tint(.white) }
                        else {
                            Text(org.privacy == "private" && !authManager.isDev ? "Request to Join" : "Join")
                                .fontWeight(.bold)
                        }
                    }
                    .frame(maxWidth: .infinity).padding()
                    .background(LinearGradient(colors: [Color.nostiaAccent, Color.nostriaPurple],
                                               startPoint: .leading, endPoint: .trailing))
                    .foregroundColor(.white).cornerRadius(14)
                }
                .disabled(isJoining || pendingJoin)
            }
        }
        .padding(16)
        .nostiaCard(in: RoundedRectangle(cornerRadius: 16))
    }

    private func infoBlock(title: String, text: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.headline).foregroundColor(Color.nostiaTextPrimary)
            Text(text).font(.subheadline).foregroundColor(Color.nostiaTextSecond)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .nostiaCard(in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Actions

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        org = try? await OrganizationsAPI.shared.get(id: orgId)
    }

    private func attemptJoin() async {
        guard let org else { return }
        // Dev accounts skip location gathering entirely — the server bypasses the zone
        // gate and the private approval queue for them.
        if authManager.isDev {
            await doJoin(lat: nil, lng: nil)
            return
        }
        // Zone-gated orgs need a live location for BOTH direct joins and private join
        // requests — the server rejects out-of-zone requests too (Section 10).
        if org.locationVerificationEnabled {
            if locationManager.permissionDenied {
                alertMessage = "Location access is required to join this organization. Enable it in Settings and try again."
                return
            }
            if let loc = locationManager.location {
                await doJoin(lat: loc.coordinate.latitude, lng: loc.coordinate.longitude)
            } else {
                pendingJoin = true
                locationManager.requestLocationOnce()
            }
        } else {
            await doJoin(lat: nil, lng: nil)
        }
    }

    private func doJoin(lat: Double?, lng: Double?) async {
        isJoining = true
        defer { isJoining = false }
        do {
            let result = try await OrganizationsAPI.shared.join(id: orgId, latitude: lat, longitude: lng)
            Haptics.success()
            if result.status == "pending" {
                alertMessage = "Your request to join has been sent for approval."
            }
            org = result.org
            onChanged?()
        } catch {
            alertMessage = error.localizedDescription
        }
    }

    private func leave() async {
        do {
            try await OrganizationsAPI.shared.leave(id: orgId)
            Haptics.success()
            onChanged?()
            dismiss()
        } catch {
            alertMessage = error.localizedDescription
        }
    }

    private func devDeleteOrg() async {
        do {
            try await OrganizationsAPI.shared.delete(id: orgId)
            Haptics.success()
            onChanged?()
            dismiss()
        } catch {
            alertMessage = error.localizedDescription
        }
    }
}
