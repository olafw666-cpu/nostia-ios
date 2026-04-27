import Combine
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
    @Published var successMessage: String?

    enum FriendTab { case friends, requests }

    private var loadVersion = 0

    var sentFriendIds: Set<Int> {
        Set(sentRequests.compactMap(\.friendId))
    }

    func loadAll() async {
        loadVersion += 1
        let myVersion = loadVersion
        isLoading = true
        do {
            let f = try await FriendsAPI.shared.getAll()
            guard loadVersion == myVersion else { isLoading = false; return }
            friends = f
        } catch {
            errorMessage = error.localizedDescription
        }
        guard loadVersion == myVersion else { isLoading = false; return }
        do {
            let r = try await FriendsAPI.shared.getRequests()
            guard loadVersion == myVersion else { isLoading = false; return }
            receivedRequests = r.received
            sentRequests = r.sent
        } catch {
            errorMessage = error.localizedDescription
        }
        if loadVersion == myVersion { isLoading = false }
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
            successMessage = "Friend request sent!"
            clearSearch()
            await loadAll()
            activeTab = .requests
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func acceptRequest(_ requestId: Int) async {
        do {
            try await FriendsAPI.shared.acceptRequest(requestId)
        } catch {
            errorMessage = error.localizedDescription
            await loadAll()
            return
        }
        successMessage = "Friend request accepted!"
        await loadAll()
        activeTab = .friends
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
