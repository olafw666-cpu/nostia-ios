import Foundation

/// Feed, the follow graph, direct messages, notifications and moderation.
///
/// Every mutation here writes to `DemoStore`, so a post really appears in the feed and a
/// sent message really lands in the thread — for this device, and only this device.
extension DemoBackend {

    static func routeSocial(_ r: Request) async throws -> Data? {
        let store = DemoStore.shared
        switch (r.method, r.segments) {

        // MARK: Feed

        case ("GET", ["feed"]):
            return try send(await store.read { Array($0.posts.prefix(r.limit)) })

        case ("POST", ["feed"]):
            let post = await store.write { s -> FeedPost in
                s.nextId += 1
                var dict: [String: Any] = [
                    "id": s.nextId, "userId": s.me.id, "username": s.me.username,
                    "name": s.me.name, "isDev": s.me.isDev,
                    "likeCount": 0, "dislikeCount": 0, "commentCount": 0,
                    "isLiked": false, "isDisliked": false,
                    "createdAt": DemoJSON.iso(Date())
                ]
                if let content = r.str("content") { dict["content"] = content }
                if let image = r.str("imageData") { dict["imageData"] = image }
                if let orgId = r.int("orgId") {
                    dict["orgId"] = orgId
                    dict["orgName"] = s.organizations.first { $0.id == orgId }?.name ?? "Organization"
                    dict["visibility"] = "org"
                }
                let post = DemoJSON.make(FeedPost.self, dict)
                s.posts.insert(post, at: 0)
                return post
            }
            return try send(post)

        case ("PUT", ["feed", _]):
            guard let id = r.id(1) else { return nil }
            let updated = await store.write { s -> FeedPost? in
                guard let i = s.posts.firstIndex(where: { $0.id == id }) else { return nil }
                if let content = r.str("content") { s.posts[i].content = content }
                return s.posts[i]
            }
            guard let post = updated else { throw fail("Post not found", 404) }
            return try send(post)

        case ("DELETE", ["feed", _]), ("DELETE", ["admin", "posts", _]):
            guard let id = r.id(r.segments.count - 1) else { return nil }
            await store.write { s in
                s.posts.removeAll { $0.id == id }
                s.postComments[id] = nil
            }
            return try ok()

        case ("POST", ["feed", _, "like"]), ("DELETE", ["feed", _, "like"]),
             ("POST", ["feed", _, "dislike"]), ("DELETE", ["feed", _, "dislike"]):
            guard let id = r.id(1) else { return nil }
            let adding = r.method == "POST"
            let isLike = r.segments[2] == "like"
            await store.write { s in
                guard let i = s.posts.firstIndex(where: { $0.id == id }) else { return }
                if isLike {
                    s.posts[i].isLiked = adding
                    s.posts[i].likeCount = max(0, s.posts[i].likeCount + (adding ? 1 : -1))
                    // Liking clears an opposing dislike, matching the server.
                    if adding, s.posts[i].isDisliked == true {
                        s.posts[i].isDisliked = false
                        s.posts[i].dislikeCount = max(0, s.posts[i].dislikeCount - 1)
                    }
                } else {
                    s.posts[i].isDisliked = adding
                    s.posts[i].dislikeCount = max(0, s.posts[i].dislikeCount + (adding ? 1 : -1))
                    if adding, s.posts[i].isLiked == true {
                        s.posts[i].isLiked = false
                        s.posts[i].likeCount = max(0, s.posts[i].likeCount - 1)
                    }
                }
            }
            return try ok()

        case ("GET", ["feed", _, "comments"]):
            guard let id = r.id(1) else { return nil }
            return try send(await store.read { $0.postComments[id] ?? [] })

        case ("POST", ["feed", _, "comments"]):
            guard let id = r.id(1) else { return nil }
            let comment = await store.write { s -> FeedComment in
                s.nextId += 1
                let c = DemoJSON.make(FeedComment.self, [
                    "id": s.nextId, "userId": s.me.id, "username": s.me.username,
                    "name": s.me.name, "isDev": s.me.isDev,
                    "content": r.str("content") ?? "",
                    "createdAt": DemoJSON.iso(Date())
                ])
                s.postComments[id, default: []].append(c)
                if let i = s.posts.firstIndex(where: { $0.id == id }) {
                    s.posts[i].commentCount += 1
                }
                return c
            }
            return try send(comment)

        case ("DELETE", ["feed", "comments", _]):
            guard let id = r.id(2) else { return nil }
            await store.write { s in
                for (postId, list) in s.postComments where list.contains(where: { $0.id == id }) {
                    s.postComments[postId] = list.filter { $0.id != id }
                    if let i = s.posts.firstIndex(where: { $0.id == postId }) {
                        s.posts[i].commentCount = max(0, s.posts[i].commentCount - 1)
                    }
                }
            }
            return try ok()

        // MARK: Follow graph

        case ("GET", ["followers"]):
            return try send(await store.read { $0.followers })

        case ("GET", ["following"]):
            return try send(await store.read { $0.following })

        case ("GET", ["follow", "suggestions"]):
            return try send(await store.read { $0.suggestions })

        case ("GET", ["follow", "locations"]):
            let locations = await store.read { s in
                s.people.compactMap { p -> [String: Any]? in
                    guard let lat = p.latitude, let lng = p.longitude else { return nil }
                    return ["id": p.id, "name": p.name, "username": p.username,
                            "latitude": lat, "longitude": lng, "isDev": p.isDev]
                }
            }
            return try send(locations)

        case ("GET", ["follow", "status", _]):
            guard let uid = r.id(2) else { return nil }
            let following = await store.read { s in s.following.contains { $0.id == uid } }
            return try send(["isFollowing": following, "isFollowedBy": true, "isMutual": following])

        case ("POST", ["follow"]):
            guard let uid = r.int("userId") ?? r.int("followeeId") else { throw fail("userId is required") }
            await store.write { s in
                guard !s.following.contains(where: { $0.id == uid }) else { return }
                let person = s.people.first { $0.id == uid }
                let suggestion = s.suggestions.first { $0.id == uid }
                let name = person?.name ?? suggestion?.name
                let username = person?.username ?? suggestion?.username
                guard let name, let username else { return }
                s.following.append(DemoJSON.make(FollowUser.self, [
                    "id": uid, "username": username, "name": name,
                    "homeStatus": person?.homeStatus ?? "closed", "isDev": person?.isDev ?? false
                ]))
                s.suggestions.removeAll { $0.id == uid }
            }
            return try ok()

        case ("DELETE", ["follow", _]):
            guard let uid = r.id(1) else { return nil }
            await store.write { s in s.following.removeAll { $0.id == uid } }
            return try ok()

        // Contacts never leave the device in this build; nothing matches, so the
        // picker falls through to its invite list.
        case ("POST", ["contacts", "lookup"]):
            return try send([String: Any]())

        case ("GET", ["contacts", "invites"]):
            return try send([] as [Any])

        case ("POST", ["contacts", "invite"]):
            return try send([
                "token": UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased(),
                "status": "pending",
                "expiresAt": DemoJSON.iso(DemoJSON.ahead(days: 7))
            ])

        // MARK: Messages

        case ("GET", ["conversations"]):
            return try send(await store.read { $0.conversations })

        case ("POST", ["conversations"]):
            guard let uid = r.int("userId") ?? r.int("otherUserId") else { throw fail("userId is required") }
            let convo = await store.write { s -> Conversation in
                if let existing = s.conversations.first(where: { $0.otherUserId == uid }) { return existing }
                s.nextId += 1
                let person = s.people.first { $0.id == uid }
                let c = DemoJSON.make(Conversation.self, [
                    "id": s.nextId, "otherUserId": uid,
                    "otherUserName": person?.name ?? "Member",
                    "otherUserUsername": person?.username ?? "member",
                    "unreadCount": 0, "updatedAt": DemoJSON.iso(Date())
                ])
                s.conversations.insert(c, at: 0)
                s.messages[c.id] = []
                return c
            }
            return try send(convo)

        case ("GET", ["conversations", _, "messages"]):
            guard let id = r.id(1) else { return nil }
            return try send(await store.read { $0.messages[id] ?? [] })

        case ("POST", ["conversations", _, "messages"]):
            guard let id = r.id(1) else { return nil }
            let message = await store.write { s -> Message in
                s.nextId += 1
                let m = DemoJSON.make(Message.self, [
                    "id": s.nextId, "conversationId": id, "senderId": s.me.id,
                    "senderName": s.me.name, "senderUsername": s.me.username,
                    "content": r.str("content") ?? "", "read": true,
                    "createdAt": DemoJSON.iso(Date())
                ])
                s.messages[id, default: []].append(m)
                if let i = s.conversations.firstIndex(where: { $0.id == id }) {
                    s.conversations[i].lastMessage = m.content
                    s.conversations[i].updatedAt = m.createdAt
                }
                return m
            }
            return try send(message)

        case ("PUT", ["conversations", _, "read"]):
            guard let id = r.id(1) else { return nil }
            await store.write { s in
                if let i = s.conversations.firstIndex(where: { $0.id == id }) {
                    s.conversations[i].unreadCount = 0
                }
            }
            return try ok()

        case ("GET", ["messages", "unread-count"]):
            let count = await store.read { s in s.conversations.reduce(0) { $0 + ($1.unreadCount ?? 0) } }
            return try send(["unreadCount": count])

        // MARK: Notifications

        case ("GET", ["notifications"]):
            return try send(await store.read { Array($0.notifications.prefix(r.limit)) })

        case ("GET", ["notifications", "unread-count"]):
            let count = await store.read { s in s.notifications.filter { !$0.read }.count }
            return try send(["unreadCount": count])

        case ("PUT", ["notifications", "read-all"]):
            await store.write { s in
                for i in s.notifications.indices { s.notifications[i].read = true }
            }
            return try ok()

        case ("PUT", ["notifications", _, "read"]):
            guard let id = r.id(1) else { return nil }
            await store.write { s in
                if let i = s.notifications.firstIndex(where: { $0.id == id }) {
                    s.notifications[i].read = true
                }
            }
            return try ok()

        case ("DELETE", ["notifications"]):
            await store.write { $0.notifications = [] }
            return try ok()

        case ("DELETE", ["notifications", _]):
            guard let id = r.id(1) else { return nil }
            await store.write { s in s.notifications.removeAll { $0.id == id } }
            return try ok()

        // MARK: Moderation

        case ("GET", ["blocks"]):
            return try send(await store.read { $0.blocked })

        case ("POST", ["blocks"]):
            guard let uid = r.int("userId") ?? r.int("blockedId") else { throw fail("userId is required") }
            await store.write { s in
                guard !s.blocked.contains(where: { $0.id == uid }),
                      let person = s.people.first(where: { $0.id == uid }) else { return }
                s.blocked.append(DemoJSON.make(BlockedUser.self, [
                    "id": person.id, "username": person.username, "name": person.name,
                    "blockedAt": DemoJSON.iso(Date())
                ]))
                // Blocking is mutual severance on the server; mirror that here or the
                // person stays in the follow lists and the block looks like it failed.
                s.following.removeAll { $0.id == uid }
                s.followers.removeAll { $0.id == uid }
                s.posts.removeAll { $0.userId == uid }
            }
            return try ok()

        case ("DELETE", ["blocks", _]):
            guard let uid = r.id(1) else { return nil }
            await store.write { s in s.blocked.removeAll { $0.id == uid } }
            return try ok()

        case ("POST", ["reports"]):
            // Accepted and dropped. There is no moderation queue to reach, and the
            // report sheet only needs a success to show its confirmation.
            return try ok()

        case ("DELETE", ["admin", "users", _]), ("DELETE", ["admin", "experiences", _]):
            guard let id = r.id(2) else { return nil }
            await store.write { s in
                s.people.removeAll { $0.id == id }
                s.experiences.removeAll { $0.id == id }
            }
            return try ok()

        default:
            return nil
        }
    }
}
