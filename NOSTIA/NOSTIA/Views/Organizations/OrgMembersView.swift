import SwiftUI

// Member management (Section 5 / Section 6). Owner/admin only. Remove members, see join
// dates, approve/reject join requests. Role assignment and ownership transfer are
// owner-only.
struct OrgMembersView: View {
    let org: Organization
    var onChanged: (() -> Void)? = nil

    @State private var members: [OrgMember] = []
    @State private var requests: [OrgJoinRequest] = []
    @State private var isLoading = true
    @State private var transferTarget: OrgMember?

    private var isOwner: Bool { org.myRole == "owner" }
    private var myId: Int? { AuthManager.shared.currentUserId }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if !requests.isEmpty {
                    requestsSection
                }
                membersSection
            }
            .padding(16)
        }
        .background(Color.nostiaBackground.ignoresSafeArea())
        .navigationTitle("Members")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .task { await load() }
        .confirmationDialog(
            "Make \(transferTarget?.name ?? "this member") the owner? You'll become an admin.",
            isPresented: Binding(get: { transferTarget != nil }, set: { if !$0 { transferTarget = nil } }),
            titleVisibility: .visible
        ) {
            Button("Transfer Ownership", role: .destructive) {
                if let t = transferTarget { Task { await transfer(to: t) } }
            }
            Button("Cancel", role: .cancel) { transferTarget = nil }
        }
    }

    // MARK: - Requests (private orgs)

    private var requestsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Join Requests").font(.headline).foregroundColor(Color.nostiaTextPrimary)
            ForEach(requests) { req in
                HStack(spacing: 12) {
                    UserAvatarView(imageData: req.profilePictureUrl, initial: req.initial, color: Color.nostiaAccent, size: 40)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(req.name).font(.system(size: 15, weight: .semibold)).foregroundColor(Color.nostiaTextPrimary)
                        Text("@\(req.username)").font(.caption).foregroundColor(Color.nostiaTextMuted)
                    }
                    Spacer()
                    Button { Task { await act(req, approve: true) } } label: {
                        Image(systemName: "checkmark.circle.fill").font(.title3).foregroundColor(Color.nostiaSuccess)
                    }
                    Button { Task { await act(req, approve: false) } } label: {
                        Image(systemName: "xmark.circle.fill").font(.title3).foregroundColor(Color.nostriaDanger)
                    }
                }
                .padding(12).nostiaCard(in: RoundedRectangle(cornerRadius: 14))
            }
        }
    }

    // MARK: - Members

    private var membersSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Members (\(members.count))").font(.headline).foregroundColor(Color.nostiaTextPrimary)
            if isLoading && members.isEmpty {
                ProgressView().tint(Color.nostiaAccent).frame(maxWidth: .infinity).padding()
            } else {
                ForEach(members) { member in memberRow(member) }
            }
        }
    }

    private func memberRow(_ member: OrgMember) -> some View {
        HStack(spacing: 12) {
            UserAvatarView(imageData: member.profilePictureUrl, initial: member.initial, color: Color.nostriaPurple, size: 44)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(member.name).font(.system(size: 15, weight: .semibold)).foregroundColor(Color.nostiaTextPrimary)
                    Text(member.role.capitalized)
                        .font(.system(size: 10, weight: .bold))
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(member.role == "owner" ? Color.nostiaAccent : Color.nostiaTextSecond)
                        .foregroundColor(.white).cornerRadius(6)
                }
                Text("Joined \(shortDate(member.joinedAt))").font(.caption).foregroundColor(Color.nostiaTextMuted)
            }
            Spacer()
            rowMenu(member)
        }
        .padding(12).nostiaCard(in: RoundedRectangle(cornerRadius: 14))
    }

    @ViewBuilder
    private func rowMenu(_ member: OrgMember) -> some View {
        let isSelf = member.userId == myId
        let canRemove = (isOwner && member.role != "owner")
            || (org.myRole == "admin" && member.role == "member")
        let canAssign = isOwner && member.role != "owner"

        if !isSelf && (canRemove || canAssign) {
            Menu {
                if canAssign {
                    if member.role == "member" {
                        Button { Task { await setRole(member, role: "admin") } } label: {
                            Label("Promote to Admin", systemImage: "arrow.up.circle")
                        }
                    } else if member.role == "admin" {
                        Button { Task { await setRole(member, role: "member") } } label: {
                            Label("Demote to Member", systemImage: "arrow.down.circle")
                        }
                    }
                    Button { transferTarget = member } label: {
                        Label("Transfer Ownership", systemImage: "crown")
                    }
                }
                if canRemove {
                    Button(role: .destructive) { Task { await remove(member) } } label: {
                        Label("Remove from Org", systemImage: "person.badge.minus")
                    }
                }
            } label: {
                Image(systemName: "ellipsis.circle").font(.title3).foregroundColor(Color.nostiaTextSecond)
            }
        }
    }

    // MARK: - Actions

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        members = (try? await OrganizationsAPI.shared.getMembers(id: org.id)) ?? []
        if org.privacy == "private" {
            requests = (try? await OrganizationsAPI.shared.getRequests(id: org.id)) ?? []
        }
    }

    private func act(_ req: OrgJoinRequest, approve: Bool) async {
        do {
            try await OrganizationsAPI.shared.actOnRequest(id: org.id, userId: req.userId, approve: approve)
            Haptics.success()
            requests.removeAll { $0.userId == req.userId }
            if approve { await load() }
            onChanged?()
        } catch {}
    }

    private func setRole(_ member: OrgMember, role: String) async {
        do {
            try await OrganizationsAPI.shared.setRole(id: org.id, userId: member.userId, role: role)
            Haptics.success()
            await load()
            onChanged?()
        } catch {}
    }

    private func remove(_ member: OrgMember) async {
        do {
            try await OrganizationsAPI.shared.removeMember(id: org.id, userId: member.userId)
            Haptics.success()
            members.removeAll { $0.userId == member.userId }
            onChanged?()
        } catch {}
    }

    private func transfer(to member: OrgMember) async {
        transferTarget = nil
        do {
            _ = try await OrganizationsAPI.shared.transfer(id: org.id, newOwnerId: member.userId)
            Haptics.success()
            await load()
            onChanged?()
        } catch {}
    }

    private func shortDate(_ raw: String?) -> String {
        guard let raw else { return "—" }
        let inFmt = DateFormatter()
        inFmt.dateFormat = "yyyy-MM-dd HH:mm:ss"
        inFmt.locale = Locale(identifier: "en_US_POSIX")
        if let d = inFmt.date(from: raw) {
            let out = DateFormatter(); out.dateFormat = "MMM d, yyyy"
            return out.string(from: d)
        }
        return String(raw.prefix(10))
    }
}
