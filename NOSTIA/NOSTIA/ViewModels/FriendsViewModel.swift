import Combine
import Foundation

@MainActor
final class FriendsViewModel: ObservableObject {
    @Published var followers: [FollowUser] = []
    @Published var following: [FollowUser] = []
    @Published var searchResults: [UserSearchResult] = []
    @Published var searchQuery = ""
    @Published var searchPerformed = false
    @Published var activeTab: FollowTab = .followers
    @Published var isLoading = false
    @Published var isSearching = false
    @Published var errorMessage: String?

    enum FollowTab { case followers, following }

    var followingIds: Set<Int> { Set(following.map(\.id)) }
    var followerIds: Set<Int> { Set(followers.map(\.id)) }

    func loadAll() async {
        isLoading = true
        async let followersData = FriendsAPI.shared.getFollowers()
        async let followingData = FriendsAPI.shared.getFollowing()
        do {
            let (flrs, flng) = try await (followersData, followingData)
            followers = flrs
            following = flng
        } catch is CancellationError {
            isLoading = false; return
        } catch let urlErr as URLError where urlErr.code == .cancelled {
            isLoading = false; return
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func search() async {
        guard !searchQuery.trimmingCharacters(in: .whitespaces).isEmpty else {
            searchResults = []; searchPerformed = false; return
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
        searchQuery = ""; searchResults = []; searchPerformed = false
    }

    func follow(userId: Int) async -> Bool {
        do {
            try await FriendsAPI.shared.follow(userId: userId)
            clearSearch()
            await loadAll()
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func unfollow(userId: Int) async {
        do {
            try await FriendsAPI.shared.unfollow(userId: userId)
            await loadAll()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
