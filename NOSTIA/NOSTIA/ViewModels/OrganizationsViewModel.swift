import Foundation
import Combine

@MainActor
final class OrganizationsViewModel: ObservableObject {
    @Published var myOrgs: [Organization] = []
    @Published var searchResults: [Organization] = []
    @Published var searchQuery = ""
    @Published var isLoading = false
    @Published var isSearching = false
    @Published var errorMessage: String?

    private let api = OrganizationsAPI.shared

    // True once the user already owns an org — the create flow is then hidden (Section 2,
    // one org per user). Server enforces this regardless.
    var ownsAnOrg: Bool { myOrgs.contains { $0.isOwner } }

    func loadMine() async {
        isLoading = true
        defer { isLoading = false }
        do { myOrgs = try await api.mine() }
        catch { errorMessage = error.localizedDescription }
    }

    func runSearch() async {
        let q = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { searchResults = []; return }
        isSearching = true
        defer { isSearching = false }
        do { searchResults = try await api.search(query: q) }
        catch { searchResults = [] }
    }
}
