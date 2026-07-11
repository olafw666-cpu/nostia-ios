import SwiftUI

// Entry point for Organizations (triggered from the home page, Section 2). Lists the
// user's orgs, lets them search/discover others, and create one (one per user).
struct OrganizationsHubView: View {
    @StateObject private var vm = OrganizationsViewModel()
    @State private var showCreate = false
    @State private var searchTask: Task<Void, Never>?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    searchField

                    if !vm.searchQuery.trimmingCharacters(in: .whitespaces).isEmpty {
                        searchResultsSection
                    } else {
                        myOrgsSection
                    }
                }
                .padding(16)
            }
            .background(.clear)
            .navigationTitle("Organizations")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .navigationDestination(for: Int.self) { id in
                OrgDetailView(orgId: id, onChanged: { Task { await vm.loadMine() } })
            }
            .toolbar {
                if !vm.ownsAnOrg {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button { showCreate = true } label: {
                            Image(systemName: "plus").foregroundColor(Color.nostiaAccent)
                        }
                        .accessibilityLabel("Create organization")
                    }
                }
            }
        }
        .sheet(isPresented: $showCreate) {
            CreateOrganizationView { _ in Task { await vm.loadMine() } }
        }
        .task { await vm.loadMine() }
    }

    private var searchField: some View {
        HStack {
            Image(systemName: "magnifyingglass").foregroundColor(Color.nostiaTextMuted)
            TextField("Find organizations", text: $vm.searchQuery)
                .foregroundColor(Color.nostiaTextPrimary)
                .autocorrectionDisabled()
                .onChange(of: vm.searchQuery) { _, _ in
                    searchTask?.cancel()
                    searchTask = Task {
                        try? await Task.sleep(nanoseconds: 300_000_000)
                        if !Task.isCancelled { await vm.runSearch() }
                    }
                }
            if !vm.searchQuery.isEmpty {
                Button { vm.searchQuery = ""; vm.searchResults = [] } label: {
                    Image(systemName: "xmark.circle.fill").foregroundColor(Color.nostiaTextMuted)
                        .frame(width: 36, height: 36)
                }
                .buttonStyle(.nostiaTap)
                .accessibilityLabel("Clear search")
            }
        }
        .padding(12)
        .nostiaWarmCard(in: RoundedRectangle(cornerRadius: 12))
    }

    @ViewBuilder
    private var searchResultsSection: some View {
        if vm.isSearching {
            ProgressView().tint(Color.nostiaAccent).frame(maxWidth: .infinity).padding()
        } else if vm.searchResults.isEmpty {
            EmptyStateView(icon: "magnifyingglass", text: "No organizations found", sub: "Try a different name")
        } else {
            ForEach(vm.searchResults) { org in
                NavigationLink(value: org.id) { OrgRow(org: org) }.buttonStyle(.nostiaTap)
            }
        }
    }

    @ViewBuilder
    private var myOrgsSection: some View {
        Text("Your Organizations").font(.headline).foregroundColor(Color.nostiaTextPrimary)
        if vm.isLoading && vm.myOrgs.isEmpty {
            ProgressView().tint(Color.nostiaAccent).frame(maxWidth: .infinity).padding()
        } else if vm.myOrgs.isEmpty {
            EmptyStateView(icon: "building.2",
                           text: "You're not in any organizations yet",
                           sub: "Search to find one, or create your own")
        } else {
            ForEach(vm.myOrgs) { org in
                NavigationLink(value: org.id) { OrgRow(org: org) }.buttonStyle(.nostiaTap)
            }
        }
    }
}

// MARK: - Row

struct OrgRow: View {
    let org: Organization
    var body: some View {
        HStack(spacing: 12) {
            UserAvatarView(imageData: org.imageUrl, initial: org.initial, color: Color.nostriaPurple, size: 48)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(org.name).font(.nostiaBody(16, weight: .semibold)).foregroundColor(Color.nostiaTextPrimary)
                    if let role = org.myRole {
                        Text(role.capitalized)
                            .font(.nostiaBody(10, weight: .bold))
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(role == "owner" ? Color.nostiaAccent : Color.nostiaTextSecond)
                            .foregroundColor(.white).cornerRadius(6)
                    }
                }
                HStack(spacing: 8) {
                    Text("\(org.memberCount) member\(org.memberCount == 1 ? "" : "s")")
                    if org.privacy == "private" { Label("Private", systemImage: "lock") }
                    if org.locationVerificationEnabled { Image(systemName: "mappin.and.ellipse") }
                }
                .font(.caption).foregroundColor(Color.nostiaTextMuted)
            }
            Spacer()
            Image(systemName: "chevron.right").foregroundColor(Color.nostiaTextMuted)
        }
        .padding(12)
        .nostiaCard(in: RoundedRectangle(cornerRadius: 14))
    }
}
