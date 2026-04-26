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

    // Track in-flight load so accept/send can cancel it before refreshing
    private var loadTask: Task<Void, Never>?

    var sentFriendIds: Set<Int> {
        Set(sentRequests.compactMap(\.friendId))
    }

    func loadAll() async {
        loadTask?.cancel()
        let task = Task {
            isLoading = true
            do {
                let f = try await FriendsAPI.shared.getAll()
                if !Task.isCancelled { friends = f }
            } catch {
                if !isCancelledError(error) { errorMessage = error.localizedDescription }
            }
            guard !Task.isCancelled else { isLoading = false; return }
            do {
                let r = try await FriendsAPI.shared.getRequests()
                if !Task.isCancelled {
                    receivedRequests = r.received
                    sentRequests = r.sent
                }
            } catch {
                if !isCancelledError(error) { errorMessage = error.localizedDescription }
            }
            isLoading = false
        }
        loadTask = task
        await task.value
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
            loadTask?.cancel()
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
        // Cancel any in-flight stale loadAll so it can't overwrite the fresh data
        loadTask?.cancel()
        successMessage = "Friend request accepted!"
        await loadAll()
        activeTab = .friends
    }

    func rejectRequest(_ requestId: Int) async {
        do {
            try await FriendsAPI.shared.rejectRequest(requestId)
            loadTask?.cancel()
            await loadAll()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
