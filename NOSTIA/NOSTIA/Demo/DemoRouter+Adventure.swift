import Foundation

/// The Adventure half of the app: tonight's plan and its stops, the daily adventure and
/// its points economy, the cosmetic store, experiences and the map, and organizations.
///
/// Note the wire convention flips here. `AdventurePlan`, `PlanStop`, `PlanMember`,
/// `PlacePin` and the `DailyAdventure` envelopes are snake_case; experiences and orgs
/// are camelCase. Because fixtures are decoded through each model's own `CodingKeys`,
/// that difference is handled for us rather than being something to remember.
extension DemoBackend {

    static func routeAdventure(_ r: Request) async throws -> Data? {
        let store = DemoStore.shared
        switch (r.method, r.segments) {

        // MARK: Tonight's plan

        case ("GET", ["plans", "current"]):
            let plan = await store.read { $0.plan }
            return try send(PlanResponse(plan: plan, reason: nil, code: nil, anywhere: nil))

        case ("POST", ["plans", "generate"]), ("POST", ["plans", _, "reroll"]):
            let vibe = r.str("vibe")
            let plan = await store.write { s -> AdventurePlan in
                let built = composePlan(from: s, vibe: vibe, rerollCount: (s.plan?.rerollCount ?? -1) + 1)
                s.plan = built
                return built
            }
            return try send(PlanResponse(plan: plan, reason: nil, code: nil, anywhere: nil))

        case ("POST", ["plans", _, "accept"]):
            let plan = await store.write { s -> AdventurePlan? in
                guard let current = s.plan, var dict = try? encodeToObject(current) else { return nil }
                dict["state"] = "provisional"
                s.plan = DemoJSON.make(AdventurePlan.self, dict)
                return s.plan
            }
            return try send(PlanResponse(plan: plan, reason: nil, code: nil, anywhere: nil))

        // Arriving at a stop and staying put. There is no geofence to satisfy here, so
        // the dwell simply counts and the stop flips to completed.
        case ("POST", ["plans", _, "stops", _, "dwell"]):
            guard let stopId = r.id(3) else { return nil }
            let (done, total) = await store.write { s -> (Int, Int) in
                guard let plan = s.plan, var dict = try? encodeToObject(plan),
                      var stops = dict["stops"] as? [[String: Any]] else { return (0, 0) }
                for i in stops.indices where (stops[i]["id"] as? Int) == stopId {
                    stops[i]["status"] = "completed"
                    stops[i]["completed_by_me"] = true
                    stops[i]["completions"] = ((stops[i]["completions"] as? Int) ?? 0) + 1
                }
                dict["stops"] = stops
                s.plan = DemoJSON.make(AdventurePlan.self, dict)
                let completed = stops.filter { ($0["status"] as? String) == "completed" }.count
                return (completed, stops.count)
            }
            return try send([
                "completion": ["id": stopId, "stop_id": stopId, "method": "dwell",
                               "dwell_seconds": 420, "corroborated": true],
                "stops_completed": done, "stops_total": total
            ])

        case ("POST", ["plans", _, "stops", _, "capture-token"]):
            return try send(["nonce": UUID().uuidString])

        case ("POST", ["plans", _, "stops", _, "recompose"]):
            guard let stopId = r.id(3) else { return nil }
            let plan = await store.write { s -> AdventurePlan? in
                guard let current = s.plan, var dict = try? encodeToObject(current),
                      var stops = dict["stops"] as? [[String: Any]] else { return nil }
                let pool = s.experiences.shuffled()
                for i in stops.indices where (stops[i]["id"] as? Int) == stopId {
                    if let swap = pool.first(where: { exp in
                        !stops.contains { ($0["name"] as? String) == exp.title }
                    }) {
                        stops[i]["name"] = swap.title
                        stops[i]["lat"] = swap.latitude ?? 40.73
                        stops[i]["lng"] = swap.longitude ?? -73.99
                    }
                }
                dict["stops"] = stops
                s.plan = DemoJSON.make(AdventurePlan.self, dict)
                return s.plan
            }
            guard let p = plan else { throw fail("No plan to recompose") }
            return try send(["plan": try encodeToObject(p), "swapped": true])

        case ("POST", ["plans", _, "rate"]):
            return try ok()

        // "Turn this into a vault" — makes a real trip out of the plan, which is one of
        // the nicer things to show because the new vault then behaves like any other.
        case ("POST", ["plans", _, "vault"]):
            let tripId = await store.write { s -> Int in
                s.nextId += 1
                let id = s.nextId
                let title = s.plan?.title ?? "Tonight"
                s.trips.insert(DemoJSON.make(Trip.self, [
                    "id": id, "title": title,
                    "description": s.plan?.description ?? "",
                    "vaultLeaderId": s.me.id, "vaultTotal": 0,
                    "createdAt": DemoJSON.stamp(Date()),
                    "participants": [[
                        "id": s.me.id, "name": s.me.name, "username": s.me.username,
                        "role": "creator", "status": "active"
                    ]]
                ]), at: 0)
                s.entries[id] = []; s.tripChat[id] = []; s.tripTasks[id] = []; s.tripDates[id] = []
                return id
            }
            return try send(["trip_id": tripId, "created": true])

        case ("GET", ["plans", _, "invite-suggestions"]):
            let people = await store.read { $0.people }
            return try send(["suggestions": people.prefix(5).map {
                ["id": $0.id, "username": $0.username, "name": $0.name, "isDev": $0.isDev]
            }])

        case ("POST", ["plans", _, "invite"]):
            let plan = await store.read { $0.plan }
            guard let p = plan else { throw fail("No plan to invite to") }
            return try send(["plan": try encodeToObject(p)])

        case ("POST", ["plans", _, "invite-link"]):
            let token = UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased()
            return try send(["token": token, "url": "\(AppConfig.experienceInviteBaseURL)/plan/\(token)"])

        case ("POST", ["plans", "invites", _, "redeem"]):
            let plan = await store.read { $0.plan }
            return try send(PlanResponse(plan: plan, reason: nil, code: nil, anywhere: nil))

        // MARK: Places on the map

        case ("GET", ["places", "map"]):
            let pins = await store.read { s in
                s.experiences.prefix(40).enumerated().map { i, e -> [String: Any] in
                    [
                        "place_id": e.id, "name": e.title,
                        "lat": e.latitude ?? 40.73, "lng": e.longitude ?? -73.99,
                        "pin_class": i % 3 == 0 ? "verified" : "suggested",
                        "verified_completions": (e.visitedCount ?? 0) / 4,
                        "distinct_users": max(1, (e.visitedCount ?? 0) / 6),
                        "category": e.tags?.first ?? "culture"
                    ]
                }
            }
            return try send([
                "pins": pins,
                "verified_count": pins.filter { ($0["pin_class"] as? String) == "verified" }.count,
                "suggested_count": pins.filter { ($0["pin_class"] as? String) == "suggested" }.count
            ])

        case ("POST", ["places", _, "report"]):
            return try ok()

        // MARK: Daily adventure and points

        // The pre-Experiences discovery endpoints. Nothing in the current app calls
        // them, but they are still declared in ExperiencesAPI, so they are answered
        // here rather than left to trip the unhandled-route assertion if anything ever
        // reaches them again.
        case ("GET", ["adventures"]):
            return try send([] as [Any])

        case ("POST", ["adventures"]):
            throw fail("Adventures were replaced by experiences.")

        case ("GET", ["adventures", "current"]):
            let payload = await store.read { s -> [String: Any] in
                var out: [String: Any] = ["points_balance": s.pointsBalance]
                if let a = s.dailyAdventure, let obj = try? encodeToObject(a) { out["adventure"] = obj }
                return out
            }
            return try send(payload)

        case ("POST", ["adventures", "generate"]):
            let adventure = await store.write { s -> DailyAdventure in
                let fresh = DemoSeed.dailyAdventure()
                s.dailyAdventure = fresh
                return fresh
            }
            return try send(["adventure": try encodeToObject(adventure)])

        case ("POST", ["adventures", _, "progress"]):
            let adventure = await store.write { s -> DailyAdventure? in
                guard let a = s.dailyAdventure, var dict = try? encodeToObject(a) else { return nil }
                dict["steps_progress"] = r.int("steps") ?? a.stepsProgress
                dict["distance_progress_m"] = r.int("distanceM") ?? a.distanceProgressM
                let steps = (dict["steps_progress"] as? Int) ?? 0
                let dist = (dict["distance_progress_m"] as? Int) ?? 0
                dict["targets_met"] = steps >= (a.stepsTarget ?? 0) && dist >= (a.distanceTargetM ?? 0)
                s.dailyAdventure = DemoJSON.make(DailyAdventure.self, dict)
                return s.dailyAdventure
            }
            guard let a = adventure else { throw fail("No adventure in progress") }
            return try send(["adventure": try encodeToObject(a)])

        case ("POST", ["adventures", _, "complete"]):
            let result = await store.write { s -> (DailyAdventure, Int, Int)? in
                guard let a = s.dailyAdventure, var dict = try? encodeToObject(a) else { return nil }
                dict["status"] = "completed"
                dict["completed_at"] = DemoJSON.iso(Date())
                dict["targets_met"] = true
                let done = DemoJSON.make(DailyAdventure.self, dict)
                s.dailyAdventure = done
                s.pointsBalance += a.points
                return (done, a.points, s.pointsBalance)
            }
            guard let (a, awarded, balance) = result else { throw fail("No adventure in progress") }
            return try send(["adventure": try encodeToObject(a),
                             "points_awarded": awarded, "points_balance": balance])

        case ("POST", ["adventures", _, "discard"]):
            await store.write { $0.dailyAdventure = nil }
            return try ok()

        case ("GET", ["cosmetics"]):
            let payload = await store.read { s -> [String: Any] in
                ["points_balance": s.pointsBalance,
                 "items": (try? encodeToArray(s.cosmetics)) ?? []]
            }
            return try send(payload)

        case ("POST", ["cosmetics", _, "purchase"]):
            guard let itemId = r.id(1) else { return nil }
            let result = await store.write { s -> (String, Int)? in
                guard let i = s.cosmetics.firstIndex(where: { $0.id == itemId }) else { return nil }
                let item = s.cosmetics[i]
                guard !item.owned else { return (item.key, s.pointsBalance) }
                guard s.pointsBalance >= item.price else { return nil }
                s.pointsBalance -= item.price
                if var dict = try? encodeToObject(item) {
                    dict["owned"] = true
                    s.cosmetics[i] = DemoJSON.make(CosmeticItem.self, dict)
                }
                return (item.key, s.pointsBalance)
            }
            guard let (key, balance) = result else { throw fail("Not enough points for that yet.") }
            return try send(["unlocked": key, "points_balance": balance])

        // MARK: Experiences

        case ("GET", ["experiences"]), ("GET", ["experiences", "nearby"]),
             ("GET", ["experiences", "for-you"]), ("GET", ["experiences", "map"]),
             ("GET", ["experiences", "upcoming"]):
            let all = await store.read { $0.experiences }
            return try send(Array(all.prefix(r.limit)))

        case ("GET", ["experiences", "mine"]):
            return try send(await store.read { s in s.experiences.filter { $0.createdBy == s.me.id } })

        case ("GET", ["experiences", "heatmap"]):
            let cells = await store.read { s in
                s.experiences.map { e -> [String: Any] in
                    ["lat": e.latitude ?? 40.73, "lng": e.longitude ?? -73.99,
                     "intensity": min(1.0, Double(e.visitedCount ?? 1) / 40.0)]
                }
            }
            return try send(["cells": cells, "total": cells.count])

        case ("GET", ["experiences", _]):
            guard let id = r.id(1) else { return nil }
            guard let exp = await store.read({ s in s.experiences.first { $0.id == id } })
            else { throw fail("Experience not found", 404) }
            return try send(exp)

        case ("POST", ["experiences"]):
            let exp = await store.write { s -> Experience in
                s.nextId += 1
                var dict: [String: Any] = [
                    "id": s.nextId,
                    "title": r.str("title") ?? "New experience",
                    "visibility": r.str("visibility") ?? "public",
                    "createdBy": s.me.id, "creatorName": s.me.name,
                    "visitedCount": 0, "visitingCount": 0, "ratingCount": 0,
                    "createdAt": DemoJSON.stamp(Date())
                ]
                if let d = r.str("description") { dict["description"] = d }
                if let l = r.str("location") { dict["location"] = l }
                if let lat = r.dbl("latitude") { dict["latitude"] = lat }
                if let lng = r.dbl("longitude") { dict["longitude"] = lng }
                if let tags = r.body["tags"] as? [String] { dict["tags"] = tags }
                if let flyer = r.str("flyerImage") { dict["flyerImage"] = flyer }
                if let date = r.str("eventDate") { dict["eventDate"] = date }
                let e = DemoJSON.make(Experience.self, dict)
                s.experiences.insert(e, at: 0)
                return e
            }
            return try send(exp)

        case ("PUT", ["experiences", _]):
            guard let id = r.id(1) else { return nil }
            let updated = await store.write { s -> Experience? in
                guard let i = s.experiences.firstIndex(where: { $0.id == id }) else { return nil }
                if let t = r.str("title") { s.experiences[i].title = t }
                if let d = r.str("description") { s.experiences[i].description = d }
                if let l = r.str("location") { s.experiences[i].location = l }
                if let tags = r.body["tags"] as? [String] { s.experiences[i].tags = tags }
                return s.experiences[i]
            }
            guard let e = updated else { throw fail("Experience not found", 404) }
            return try send(e)

        case ("DELETE", ["experiences", _]):
            guard let id = r.id(1) else { return nil }
            await store.write { s in s.experiences.removeAll { $0.id == id } }
            return try ok()

        case ("POST", ["experiences", _, "status"]):
            guard let id = r.id(1) else { return nil }
            let status = r.str("status")
            let updated = await store.write { s -> Experience? in
                guard let i = s.experiences.firstIndex(where: { $0.id == id }) else { return nil }
                let previous = s.experiences[i].myStatus
                s.experiences[i].myStatus = status
                // Keep the counters honest as the status moves between the two buckets.
                if previous == "visited" { s.experiences[i].visitedCount = max(0, (s.experiences[i].visitedCount ?? 1) - 1) }
                if previous == "visiting" { s.experiences[i].visitingCount = max(0, (s.experiences[i].visitingCount ?? 1) - 1) }
                if status == "visited" { s.experiences[i].visitedCount = (s.experiences[i].visitedCount ?? 0) + 1 }
                if status == "visiting" { s.experiences[i].visitingCount = (s.experiences[i].visitingCount ?? 0) + 1 }
                return s.experiences[i]
            }
            guard let e = updated else { throw fail("Experience not found", 404) }
            return try send(e)

        case ("POST", ["experiences", _, "rating"]):
            guard let id = r.id(1) else { return nil }
            let rating = r.dbl("rating") ?? 0
            let updated = await store.write { s -> Experience? in
                guard let i = s.experiences.firstIndex(where: { $0.id == id }) else { return nil }
                let count = s.experiences[i].ratingCount ?? 0
                let avg = s.experiences[i].avgRating ?? rating
                let hadMine = s.experiences[i].myRating != nil
                let newCount = hadMine ? count : count + 1
                s.experiences[i].myRating = rating
                s.experiences[i].ratingCount = newCount
                s.experiences[i].avgRating = ((avg * Double(count)) + rating) / Double(max(1, newCount))
                return s.experiences[i]
            }
            guard let e = updated else { throw fail("Experience not found", 404) }
            return try send(e)

        case ("GET", ["experiences", _, "comments"]):
            guard let id = r.id(1) else { return nil }
            return try send(await store.read { $0.experienceComments[id] ?? [] })

        case ("POST", ["experiences", _, "comments"]):
            guard let id = r.id(1) else { return nil }
            let comment = await store.write { s -> FeedComment in
                s.nextId += 1
                let c = DemoJSON.make(FeedComment.self, [
                    "id": s.nextId, "userId": s.me.id, "username": s.me.username,
                    "name": s.me.name, "isDev": s.me.isDev,
                    "content": r.str("content") ?? "",
                    "createdAt": DemoJSON.iso(Date())
                ])
                s.experienceComments[id, default: []].append(c)
                return c
            }
            return try send(comment)

        case ("GET", ["experiences", _, "invite"]):
            return try send(["invitedUserIds": [] as [Int]])

        case ("POST", ["experiences", _, "invite"]):
            let ids = r.ints("userIds") ?? []
            return try send(["invited": ids, "alreadyInvited": [] as [Int], "skipped": [] as [Int]])

        // MARK: Organizations

        case ("GET", ["orgs", "mine"]):
            return try send(await store.read { s in s.organizations.filter { $0.isMember } })

        case ("GET", ["orgs", "search"]):
            let q = (r.query["query"] ?? "").lowercased()
            return try send(await store.read { s in
                s.organizations.filter { q.isEmpty || $0.name.lowercased().contains(q) }
            })

        case ("GET", ["orgs", _]):
            guard let id = r.id(1) else { return nil }
            guard let org = await store.read({ s in s.organizations.first { $0.id == id } })
            else { throw fail("Organization not found", 404) }
            return try send(org)

        case ("POST", ["orgs"]):
            let org = await store.write { s -> Organization in
                s.nextId += 1
                let o = DemoJSON.make(Organization.self, [
                    "id": s.nextId, "ownerId": s.me.id, "ownerName": s.me.name,
                    "name": r.str("name") ?? "New organization",
                    "description": r.str("description") ?? "",
                    "locationVerificationEnabled": r.bool("locationVerificationEnabled") ?? true,
                    "postPermission": r.str("postPermission") ?? "members",
                    "privacy": r.str("privacy") ?? "public",
                    "memberCount": 1, "zoneCount": 0,
                    "isMember": true, "hasPendingRequest": false, "canPost": true,
                    "myRole": "owner",
                    "createdAt": DemoJSON.stamp(Date())
                ])
                s.organizations.append(o)
                return o
            }
            return try send(org)

        case ("PUT", ["orgs", _]):
            guard let id = r.id(1) else { return nil }
            let updated = await store.write { s -> Organization? in
                guard let i = s.organizations.firstIndex(where: { $0.id == id }),
                      var dict = try? encodeToObject(s.organizations[i]) else { return nil }
                for key in ["name", "description", "rulesText", "postPermission", "privacy"] {
                    if let v = r.str(key) { dict[key] = v }
                }
                if let v = r.bool("locationVerificationEnabled") { dict["locationVerificationEnabled"] = v }
                s.organizations[i] = DemoJSON.make(Organization.self, dict)
                return s.organizations[i]
            }
            guard let o = updated else { throw fail("Organization not found", 404) }
            return try send(o)

        case ("DELETE", ["orgs", _]):
            guard let id = r.id(1) else { return nil }
            await store.write { s in s.organizations.removeAll { $0.id == id } }
            return try ok()

        case ("POST", ["orgs", _, "join"]), ("POST", ["orgs", _, "leave"]):
            guard let id = r.id(1) else { return nil }
            let joining = r.segments[2] == "join"
            let org = await store.write { s -> Organization? in
                guard let i = s.organizations.firstIndex(where: { $0.id == id }),
                      var dict = try? encodeToObject(s.organizations[i]) else { return nil }
                dict["isMember"] = joining
                dict["canPost"] = joining
                dict["memberCount"] = max(0, s.organizations[i].memberCount + (joining ? 1 : -1))
                if joining { dict["myRole"] = "member" } else { dict.removeValue(forKey: "myRole") }
                s.organizations[i] = DemoJSON.make(Organization.self, dict)
                return s.organizations[i]
            }
            guard let o = org else { throw fail("Organization not found", 404) }
            return joining ? try send(["status": "joined", "org": try encodeToObject(o)]) : try ok()

        case ("GET", ["orgs", _, "members"]):
            let members = await store.read { s in
                ([s.me] + s.people.prefix(4)).map { u -> [String: Any] in
                    ["userId": u.id, "role": u.id == s.me.id ? "owner" : "member",
                     "username": u.username, "name": u.name,
                     "joinedAt": DemoJSON.stamp(DemoJSON.ago(days: 30))]
                }
            }
            return try send(members)

        case ("DELETE", ["orgs", _, "members", _]),
             ("PUT", ["orgs", _, "members", _, "role"]),
             ("POST", ["orgs", _, "requests", _]):
            return try ok()

        case ("GET", ["orgs", _, "requests"]):
            return try send([] as [Any])

        case ("GET", ["orgs", _, "posts"]):
            guard let id = r.id(1) else { return nil }
            return try send(await store.read { s in s.posts.filter { $0.orgId == id } })

        case ("POST", ["orgs", _, "posts"]):
            // Org posts are ordinary feed posts carrying an org id; hand it to the feed
            // route rather than keeping a second, subtly different implementation.
            var body = r.body
            body["orgId"] = r.id(1)
            let forwarded = Request(path: "/feed", method: "POST", body: body)
            return try await routeSocial(forwarded)

        case ("GET", ["orgs", _, "events"]):
            guard let id = r.id(1) else { return nil }
            return try send(await store.read { s in s.experiences.filter { $0.orgId == id } })

        case ("POST", ["orgs", _, "events"]):
            var body = r.body
            body["orgId"] = r.id(1)
            let forwarded = Request(path: "/experiences", method: "POST", body: body)
            return try await routeAdventure(forwarded)

        case ("GET", ["orgs", _, "zones"]), ("PUT", ["orgs", _, "zones"]):
            return try send([] as [Any])

        case ("POST", ["orgs", _, "transfer"]):
            guard let id = r.id(1) else { return nil }
            guard let org = await store.read({ s in s.organizations.first { $0.id == id } })
            else { throw fail("Organization not found", 404) }
            return try send(org)

        default:
            return nil
        }
    }

    // MARK: - Plan composition

    /// Builds tonight's plan out of the seeded landmarks.
    ///
    /// Real composition picks POIs near the user from the places layer and walks a route
    /// between them. This keeps the shape — ordered stops, dwell minutes, walking legs,
    /// a title and a window — using landmarks that actually sit near each other, so the
    /// map draws something plausible rather than a line across three states.
    private static func composePlan(from s: DemoStore.Snapshot, vibe: String?, rerollCount: Int) -> AdventurePlan {
        let anchorLat = s.me.latitude ?? 40.7306
        let anchorLng = s.me.longitude ?? -73.9866

        // Nearest first, then a slice offset by the reroll count so "try another" gives
        // a genuinely different outing instead of reshuffling the same three places.
        let nearby = s.experiences
            .filter { $0.latitude != nil && $0.longitude != nil }
            .sorted { a, b in
                let da = pow((a.latitude ?? 0) - anchorLat, 2) + pow((a.longitude ?? 0) - anchorLng, 2)
                let db = pow((b.latitude ?? 0) - anchorLat, 2) + pow((b.longitude ?? 0) - anchorLng, 2)
                return da < db
            }
        let offset = (rerollCount * 3) % max(1, max(0, nearby.count - 3))
        let chosen = Array(nearby.dropFirst(offset).prefix(3))
        let categories = ["coffee", "scenic", "food", "bar", "culture", "park"]

        var stops: [[String: Any]] = []
        for (i, exp) in chosen.enumerated() {
            stops.append([
                "id": 5_000 + rerollCount * 10 + i,
                "ord": i,
                "name": exp.title,
                "lat": exp.latitude ?? anchorLat,
                "lng": exp.longitude ?? anchorLng,
                "category": exp.tags?.first.flatMap { categories.contains($0) ? $0 : nil } ?? categories[i % categories.count],
                "dwell_minutes": [25, 40, 35][i % 3],
                "leg_meters": i == 0 ? 0 : [650, 900, 1200][i % 3],
                "leg_walk_minutes": i == 0 ? 0 : [8, 11, 15][i % 3],
                "status": "planned",
                "planned_arrival": DemoJSON.stamp(DemoJSON.ahead(minutes: 20 + i * 55)),
                "completions": 0,
                "completed_by_me": false
            ])
        }

        let titles = ["The Long Way Round", "Three Stops, One Evening", "Out Past Dark",
                      "Somewhere You Haven't Been", "The Slow Route"]
        return DemoJSON.make(AdventurePlan.self, [
            "id": 3_000 + rerollCount,
            "title": titles[rerollCount % titles.count],
            "description": chosen.isEmpty
                ? "A short walk, wherever you are."
                : "Start at \(chosen[0].title), finish wherever the last one leaves you.",
            "state": "generated",
            "vibe": vibe ?? "chill",
            "window_minutes": 180,
            "reroll_count": rerollCount,
            "window_start": DemoJSON.stamp(Date()),
            "created_at": DemoJSON.stamp(Date()),
            "expires_at": DemoJSON.stamp(DemoJSON.ahead(hours: 6)),
            "stops": stops,
            "members": [[
                "user_id": s.me.id, "username": s.me.username,
                "name": s.me.name, "role": "owner"
            ]]
        ])
    }
}
