import Combine
import Foundation

@MainActor
final class FriendsViewModel: ObservableObject {
    @Published var followers: [FollowUser] = []
    @Published var following: [FollowUser] = []
    @Published var suggestions: [SuggestedUser] = []
    @Published var searchResults: [UserSearchResult] = []
    @Published var searchQuery = ""
    @Published var searchPerformed = false
    @Published var activeTab: FollowTab = .followers
    @Published var isLoading = false
    @Published var isSearching = false
    @Published var errorMessage: String?

    enum FollowTab { case followers, following }

    var followingIds: Set<Int> { Set(following.map(\.id)) }

    func loadAll() async {
        let cachedFollowers: [FollowUser]? = await CacheManager.shared.get(CacheKey.followersList)
        let cachedFollowing: [FollowUser]? = await CacheManager.shared.get(CacheKey.followingList)
        if let f = cachedFollowers, let g = cachedFollowing {
            followers = f; following = g
        } else {
            isLoading = true
        }
        async let followersData = FriendsAPI.shared.getFollowers()
        async let followingData = FriendsAPI.shared.getFollowing()
        // Suggestions are best-effort decoration — a failure never blocks the lists.
        async let suggestionsData = try? FriendsAPI.shared.getSuggestions()
        do {
            let (flrs, flng) = try await (followersData, followingData)
            followers = flrs; following = flng
            await CacheManager.shared.set(CacheKey.followersList, value: flrs)
            await CacheManager.shared.set(CacheKey.followingList, value: flng)
        } catch is CancellationError {
            isLoading = false; return
        } catch let urlErr as URLError where urlErr.code == .cancelled {
            isLoading = false; return
        } catch {
            if followers.isEmpty { errorMessage = error.localizedDescription }
        }
        if let sugg = await suggestionsData { suggestions = sugg }
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
            suggestions.removeAll { $0.id == userId }   // drop instantly; loadAll refreshes the rest
            await CacheManager.shared.invalidate(CacheKey.followersList)
            await CacheManager.shared.invalidate(CacheKey.followingList)
            await CacheManager.shared.invalidate(CacheKey.homeFeed)
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
            await CacheManager.shared.invalidate(CacheKey.followersList)
            await CacheManager.shared.invalidate(CacheKey.followingList)
            await CacheManager.shared.invalidate(CacheKey.homeFeed)
            await loadAll()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func adminDeleteUser(id: Int) async {
        do {
            try await ExperiencesAPI.shared.adminDeleteUser(id: id)
            followers.removeAll { $0.id == id }
            following.removeAll { $0.id == id }
            suggestions.removeAll { $0.id == id }
            searchResults.removeAll { $0.id == id }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
