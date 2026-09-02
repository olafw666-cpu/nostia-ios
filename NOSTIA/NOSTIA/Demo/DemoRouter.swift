import Foundation

/// The on-device stand-in for `api.nostia.io`.
///
/// `APIClient` hands every request here when `AppConfig.isDemoMode` is on, and gets back
/// the same `Data` a real response would carry. Nothing above this line changes: the API
/// service classes, the view models, the caches, the skeleton views and the error alerts
/// all behave exactly as they do against the live backend.
///
/// Routing is a `switch` over path segments, split across three files by area
/// (this one plus `DemoRouter+Vault` and `DemoRouter+Adventure`) because one switch over
/// ~160 endpoints is unreadable.
nonisolated enum DemoBackend {

    static var decoder: JSONDecoder { DemoJSON.decoder }

    /// A request the demo backend does not implement.
    ///
    /// Logged conspicuously in DEBUG, because walking every screen with the console open
    /// is how the last gaps get found and a silent 404 just looks like an empty screen.
    /// Deliberately not an `assertionFailure`: a missing route should degrade to the
    /// error state each screen already handles, not take the app down in front of
    /// whoever is being shown it.
    static func unhandled(_ method: String, _ path: String) -> APIError {
        NostiaLog.error("Demo", "▲ NO ROUTE — \(method) \(path)")
        return APIError.httpError(statusCode: 404, message: "Not available in this build.")
    }

    // MARK: - Entry point

    static func respond(path: String, method: String, body: [String: Any]?) async throws -> Data {
        let req = Request(path: path, method: method.uppercased(), body: body ?? [:])

        // A little latency so the app behaves the way it does against a real server:
        // skeletons flash, spinners appear, buttons show their in-flight state. Returning
        // instantly is the single biggest tell that nothing is really happening.
        try? await Task.sleep(nanoseconds: UInt64.random(in: 120_000_000...340_000_000))

        if let data = try await routeAccount(req) { return data }
        if let data = try await routeSocial(req) { return data }
        if let data = try await routeVault(req) { return data }
        if let data = try await routeAdventure(req) { return data }
        throw unhandled(req.method, path)
    }

    // MARK: - Request

    /// A parsed request: path segments with the query stripped off, plus typed accessors
    /// for the query items and the JSON body.
    struct Request {
        let method: String
        let segments: [String]
        let query: [String: String]
        let body: [String: Any]

        init(path: String, method: String, body: [String: Any]) {
            self.method = method
            self.body = body
            let parts = path.split(separator: "?", maxSplits: 1, omittingEmptySubsequences: false)
            self.segments = parts[0].split(separator: "/").map(String.init)
            var q: [String: String] = [:]
            if parts.count > 1 {
                for pair in parts[1].split(separator: "&") {
                    let kv = pair.split(separator: "=", maxSplits: 1)
                    guard let key = kv.first else { continue }
                    let raw = kv.count > 1 ? String(kv[1]) : ""
                    q[String(key)] = raw.removingPercentEncoding ?? raw
                }
            }
            self.query = q
        }

        /// Path segment as an Int, e.g. `id(1)` of `/trips/101/chat` is 101.
        func id(_ index: Int) -> Int? {
            guard segments.indices.contains(index) else { return nil }
            return Int(segments[index])
        }
        func str(_ key: String) -> String? { body[key] as? String }
        func int(_ key: String) -> Int? {
            if let i = body[key] as? Int { return i }
            if let s = body[key] as? String { return Int(s) }
            return nil
        }
        func dbl(_ key: String) -> Double? {
            if let d = body[key] as? Double { return d }
            if let i = body[key] as? Int { return Double(i) }
            return nil
        }
        func bool(_ key: String) -> Bool? { body[key] as? Bool }
        func ints(_ key: String) -> [Int]? { body[key] as? [Int] }
        var limit: Int { Int(query["limit"] ?? "") ?? 50 }
    }

    // MARK: - Small helpers

    static func ok() throws -> Data { DemoJSON.empty }
    static func send<T: Encodable>(_ value: T) throws -> Data { try DemoJSON.body(value) }
    static func send(_ object: Any) throws -> Data { try DemoJSON.body(object: object) }

    static func fail(_ message: String, _ code: Int = 400) -> APIError {
        APIError.httpError(statusCode: code, message: message)
    }

    /// The token the demo hands out. `AuthManager` decodes the middle segment for an
    /// integer `id`, which is the only claim it reads, and never verifies the signature.
    static let token: String = {
        func b64(_ object: [String: Any]) -> String {
            let data = (try? JSONSerialization.data(withJSONObject: object)) ?? Data()
            return data.base64EncodedString()
                .replacingOccurrences(of: "+", with: "-")
                .replacingOccurrences(of: "/", with: "_")
                .replacingOccurrences(of: "=", with: "")
        }
        let header = b64(["alg": "none", "typ": "JWT"])
        let payload = b64(["id": DemoSeed.meId, "username": "olaf"])
        return "\(header).\(payload).demo"
    }()

    // MARK: - Account, auth, profile, settings

    private static func routeAccount(_ r: Request) async throws -> Data? {
        let store = DemoStore.shared
        switch (r.method, r.segments) {

        // Any credentials work. There is nothing to authenticate against, and being
        // able to sign out and back in keeps the whole onboarding flow demonstrable.
        case ("POST", ["auth", "login"]),
             ("POST", ["auth", "register"]),
             ("POST", ["auth", "apple"]):
            let me = await store.read { $0.me }
            return try send(["token": token, "refreshToken": token,
                             "user": try meDict(me), "created": false])

        case ("POST", ["auth", "refresh"]):
            return try send(["token": token, "refreshToken": token])

        case ("GET", ["users", "me"]):
            return try send(await store.read { $0.me })

        case ("PUT", ["users", "me"]), ("PATCH", ["profile"]):
            let updated = await store.write { s -> User in
                s.me = applyProfileEdits(to: s.me, from: r.body)
                return s.me
            }
            return try send(updated)

        case ("DELETE", ["users", "me"]):
            await store.reset()
            return try ok()

        // Must precede /users/:id — "search" is not an Int, so the id case would bail
        // out and let the request fall through to a 404.
        case ("GET", ["users", "search"]):
            let q = (r.query["query"] ?? "").lowercased()
            let results = await store.read { s in
                s.people
                    .filter { q.isEmpty || $0.username.lowercased().contains(q) || $0.name.lowercased().contains(q) }
                    .map { ["id": $0.id, "username": $0.username, "name": $0.name, "isDev": $0.isDev] as [String: Any] }
            }
            return try send(results)

        case ("GET", ["users", _]):
            guard let uid = r.id(1) else { return nil }
            let found = await store.read { s -> User? in
                uid == s.me.id ? s.me : s.people.first { $0.id == uid }
            }
            guard let user = found else { throw fail("User not found", 404) }
            return try send(user)

        case ("GET", ["users", _, "posts"]):
            guard let uid = r.id(1) else { return nil }
            return try send(await store.read { $0.posts.filter { $0.userId == uid } })

        case ("GET", ["users", _, "visited"]):
            guard let uid = r.id(1) else { return nil }
            // Only the demo user has a visited history worth showing.
            let visited = await store.read { s in
                uid == s.me.id ? s.experiences.filter { $0.myStatus == "visited" } : []
            }
            return try send(visited)

        // Consent is stored as SQLite 0/1 integers, not booleans.
        case ("GET", ["consent"]):
            return try send(["consent": ["locationConsent": 1, "dataCollectionConsent": 1]])

        case ("POST", ["privacy", "data-request"]), ("POST", ["privacy", "delete-data"]):
            return try ok()

        // Push: nothing to register with, and no token to send anywhere.
        case ("POST", ["push-token"]), ("DELETE", ["push-token"]):
            return try ok()

        case ("GET", ["notifications", "settings"]):
            return try send(["pushEnabled": await store.read { $0.pushEnabled }])

        case ("PUT", ["notifications", "settings"]):
            let enabled = r.bool("pushEnabled") ?? true
            await store.write { $0.pushEnabled = enabled }
            return try ok()

        // Passkeys need a relying party, which is the backend. Reporting "not enrolled"
        // keeps the settings screen honest and stops any OS passkey sheet from opening.
        case ("GET", ["passkey", "status"]):
            return try send(["enabled": false, "credentials": [] as [Any]])

        case ("POST", ["passkey", _]), ("POST", ["passkey", _, _]),
             ("POST", ["auth", "recovery", "passkey", _]):
            throw fail("Passkeys are not available in this build.")

        case ("GET", ["analytics", "dashboard"]):
            return try send(analyticsDashboard(await store.read { $0 }))

        case ("GET", ["analytics", "subscription"]):
            return try send(["hasAccess": true, "plan": "demo"])

        case ("GET", ["analytics", "funnels"]), ("GET", ["analytics", "retention"]):
            return try send([] as [Any])

        default:
            return nil
        }
    }

    // MARK: - Account helpers

    /// `User` keeps three private stored properties, so edits go through a wire-shaped
    /// dictionary and back out through the model's own decoder.
    private static func applyProfileEdits(to user: User, from body: [String: Any]) -> User {
        var dict = (try? JSONSerialization.jsonObject(with: DemoJSON.encoder.encode(user)) as? [String: Any]) ?? [:]
        for (key, value) in body { dict[key] = value }
        // The client sends camelCase for some fields the server stores snake_case.
        if let pic = body["profilePictureUrl"] { dict["profile_picture_url"] = pic }
        if let v = body["visitedVisibility"] { dict["visited_visibility"] = v }
        return DemoJSON.make(User.self, dict)
    }

    private static func meDict(_ me: User) throws -> [String: Any] {
        let data = try DemoJSON.encoder.encode(me)
        return (try JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
    }

    private static func analyticsDashboard(_ s: DemoStore.Snapshot) -> [String: Any] {
        [
            "metrics": [
                "totalUsers": s.people.count + 1,
                "activeUsers": s.people.count,
                "totalTrips": s.trips.count,
                "totalPosts": s.posts.count,
                "totalFriendships": s.following.count,
                "newUsersToday": 1,
                "newUsersThisWeek": 3
            ]
        ]
    }
}
