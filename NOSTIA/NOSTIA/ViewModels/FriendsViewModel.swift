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

    var sentFriendIds: Set<Int> {
        Set(sentRequests.compactMap(\.friendId))
    }

    func loadAll() async {
        isLoading = true
        do {
            friends = try await FriendsAPI.shared.getAll()
        } catch {
            if !isCancelledError(error) { errorMessage = error.localizedDescription }
        }
        do {
            let r = try await FriendsAPI.shared.getRequests()
            receivedRequests = r.received
            sentRequests = r.sent
        } catch {
            if !isCancelledError(error) { errorMessage = error.localizedDescription }
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
            if !isCancelledError(error) { errorMessage = error.localizedDescription }
        }
        isSearching = false
    }

    private func isCancelledError(_ error: Error) -> Bool {
        if error is CancellationError { return true }
        if let urlErr = error as? URLError, urlErr.code == .cancelled { return true }
        return false
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
            return
        }
        successMessage = "Friend request accepted!"
        do {
            friends = try await FriendsAPI.shared.getAll()
        } catch {
            errorMessage = "Accept succeeded but failed to refresh friends: \(error.localizedDescription)"
        }
        do {
            let r = try await FriendsAPI.shared.getRequests()
            receivedRequests = r.received
            sentRequests = r.sent
        } catch { }
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
