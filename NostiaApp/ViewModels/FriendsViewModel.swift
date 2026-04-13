import Foundation

@MainActor
final class FriendsViewModel: ObservableObject {
    @Published var friends: [Friend] = []
    @Published var receivedRequests: [FriendRequest] = []
    @Published var sentRequests: [FriendRequest] = []
    @Published var searchResults: [UserSearchResult] = []
    @Published var searchQuery = ""
    @Published var searchPerformed = false
    @Published var activeTab: FriendTab = .friends
    @Published var isLoading = false
    @Published var isSearching = false
    @Published var errorMessage: String?

    enum FriendTab { case friends, requests }

    func loadAll() async {
        isLoading = true
        async let friendsData = FriendsAPI.shared.getAll()
        async let requestsData = FriendsAPI.shared.getRequests()
        do {
            let (f, r) = try await (friendsData, requestsData)
            friends = f
            receivedRequests = r.received
            sentRequests = r.sent
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func search() async {
        guard !searchQuery.trimmingCharacters(in: .whitespaces).isEmpty else {
            searchResults = []
            searchPerformed = false
            return
        }
        isSearching = true
        do {
            searchResults = try await FriendsAPI.shared.searchUsers(searchQuery)
            searchPerformed = true
        } catch {
            searchPerformed = false
            errorMessage = error.localizedDescription
        }
        isSearching = false
    }

    func clearSearch() {
        searchQuery = ""
        searchResults = []
        searchPerformed = false
    }

    func sendRequest(to userId: Int) async -> Bool {
        do {
            try await FriendsAPI.shared.sendRequest(to: userId)
            clearSearch()
            await loadAll()
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func acceptRequest(_ requestId: Int) async {
        do {
            try await FriendsAPI.shared.acceptRequest(requestId)
            await loadAll()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func rejectRequest(_ requestId: Int) async {
        do {
            try await FriendsAPI.shared.rejectRequest(requestId)
            await loadAll()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
