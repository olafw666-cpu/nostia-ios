import Foundation

/// Vaults: the trip list, membership, vault chat, the trip plan, expenses and the
/// settle-up loop. Crash pads live here too, being the other "arrange something with
/// people you know" surface.
extension DemoBackend {

    /// How long a claim I have made sits before the other side confirms it.
    ///
    /// On the real backend a cash claim waits for a person to tap Verify. Here there is
    /// no other person, so a claim would sit in "Awaiting verification" forever and read
    /// as broken. Claims *I* make ripen on the next read; claims made against me are
    /// left alone, because confirming those is the half of the loop the demo is meant to
    /// show off.
    private static let claimRipenSeconds: TimeInterval = 4

    static func routeVault(_ r: Request) async throws -> Data? {
        let store = DemoStore.shared
        switch (r.method, r.segments) {

        // MARK: Trips

        case ("GET", ["trips"]):
            await ripenMyClaims()
            return try send(await store.read { s in s.trips.map { withVaultTotal($0, in: s) } })

        case ("POST", ["trips"]):
            let trip = await store.write { s -> Trip in
                s.nextId += 1
                let id = s.nextId
                let t = DemoJSON.make(Trip.self, [
                    "id": id,
                    "title": r.str("title") ?? "New Vault",
                    "description": r.str("description") ?? "",
                    "vaultLeaderId": s.me.id,
                    "vaultTotal": 0,
                    "createdAt": DemoJSON.stamp(Date()),
                    "participants": [[
                        "id": s.me.id, "name": s.me.name, "username": s.me.username,
                        "role": "creator", "status": "active"
                    ]]
                ])
                s.trips.insert(t, at: 0)
                s.entries[id] = []
                s.tripChat[id] = []
                s.tripTasks[id] = []
                s.tripDates[id] = []
                return t
            }
            return try send(trip)

        case ("GET", ["trips", _]):
            guard let id = r.id(1) else { return nil }
            let found = await store.read { s -> Trip? in
                guard let t = s.trips.first(where: { $0.id == id }) else { return nil }
                return withVaultTotal(t, in: s)
            }
            guard let trip = found else { throw fail("Trip not found", 404) }
            return try send(trip)

        case ("PUT", ["trips", _]):
            guard let id = r.id(1) else { return nil }
            let updated = await store.write { s -> Trip? in
                guard let i = s.trips.firstIndex(where: { $0.id == id }) else { return nil }
                if let title = r.str("title") { s.trips[i].title = title }
                if let desc = r.str("description") { s.trips[i].description = desc }
                return s.trips[i]
            }
            guard let trip = updated else { throw fail("Trip not found", 404) }
            return try send(trip)

        case ("DELETE", ["trips", _]):
            guard let id = r.id(1) else { return nil }
            await store.write { s in
                s.trips.removeAll { $0.id == id }
                s.entries[id] = nil
                s.tripChat[id] = nil
                s.tripTasks[id] = nil
                s.tripDates[id] = nil
            }
            return try ok()

        case ("POST", ["trips", _, "participants"]),
             ("POST", ["trips", _, "vault-add-members"]):
            guard let id = r.id(1) else { return nil }
            let ids = r.ints("userIds") ?? [r.int("userId")].compactMap { $0 }
            let trip = await store.write { s -> Trip? in
                guard let i = s.trips.firstIndex(where: { $0.id == id }) else { return nil }
                var members = s.trips[i].participants ?? []
                for uid in ids {
                    guard !members.contains(where: { $0.id == uid }),
                          let person = s.people.first(where: { $0.id == uid }) else { continue }
                    members.append(DemoJSON.make(TripParticipant.self, [
                        "id": person.id, "name": person.name, "username": person.username,
                        "role": "participant", "status": "active"
                    ]))
                }
                s.trips[i].participants = members
                return s.trips[i]
            }
            guard let t = trip else { throw fail("Trip not found", 404) }
            return try send(t)

        case ("DELETE", ["trips", _, "participants", _]):
            guard let id = r.id(1), let uid = r.id(3) else { return nil }
            let trip = await store.write { s -> Trip? in
                guard let i = s.trips.firstIndex(where: { $0.id == id }) else { return nil }
                s.trips[i].participants?.removeAll { $0.id == uid }
                return s.trips[i]
            }
            guard let t = trip else { throw fail("Trip not found", 404) }
            return try send(t)

        case ("POST", ["trips", _, "kick", _]):
            guard let id = r.id(1), let uid = r.id(3) else { return nil }
            let trip = await store.write { s -> Trip? in
                guard let i = s.trips.firstIndex(where: { $0.id == id }),
                      var members = s.trips[i].participants,
                      let j = members.firstIndex(where: { $0.id == uid }) else { return nil }
                members[j].status = "kicked"
                s.trips[i].participants = members
                return s.trips[i]
            }
            guard let t = trip else { throw fail("Trip not found", 404) }
            return try send(t)

        case ("POST", ["trips", _, "vault-leader"]):
            guard let id = r.id(1), let newLeader = r.int("newLeaderId") else { return nil }
            let trip = await store.write { s -> Trip? in
                guard let i = s.trips.firstIndex(where: { $0.id == id }) else { return nil }
                // Same rule the server enforces: leadership can only go to an active
                // member, or the vault ends up with a leader who cannot administer it.
                let active = (s.trips[i].participants ?? []).contains { $0.id == newLeader && !$0.isKicked }
                guard active else { return nil }
                s.trips[i].vaultLeaderId = newLeader
                return s.trips[i]
            }
            guard let t = trip else { throw fail("New leader must be an active vault member.") }
            return try send(t)

        // MARK: Vault chat

        case ("GET", ["trips", _, "chat"]):
            guard let id = r.id(1) else { return nil }
            return try send(await store.read { $0.tripChat[id] ?? [] })

        case ("POST", ["trips", _, "chat"]):
            guard let id = r.id(1) else { return nil }
            let message = await store.write { s -> TripChatMessage in
                s.nextId += 1
                let m = DemoJSON.make(TripChatMessage.self, [
                    "id": s.nextId, "tripId": id, "senderId": s.me.id,
                    "senderName": s.me.name, "senderUsername": s.me.username,
                    "content": r.str("content") ?? "", "isSystem": false,
                    "createdAt": DemoJSON.stamp(Date())
                ])
                s.tripChat[id, default: []].append(m)
                return m
            }
            return try send(message)

        // MARK: Invites

        case ("GET", ["trips", _, "invite-token"]):
            guard let id = r.id(1) else { return nil }
            return try send(["token": String(format: "%032x", abs(id &* 2_654_435_761))])

        case ("POST", ["invite", "redeem"]):
            guard let trip = await store.read({ s in s.trips.first }) else { throw fail("Invalid invite token") }
            return try send(["trip": try encodeToObject(trip), "alreadyMember": true,
                             "friendsAdded": 0, "vaultName": trip.title])

        // MARK: Trip plan

        case ("GET", ["trips", _, "plan"]):
            guard let id = r.id(1) else { return nil }
            return try send(await store.read { s in
                TripPlanResponse(tasks: s.tripTasks[id] ?? [], dateOptions: s.tripDates[id] ?? [])
            })

        case ("POST", ["trips", _, "plan", "tasks"]):
            guard let id = r.id(1) else { return nil }
            let task = await store.write { s -> TripTask in
                s.nextId += 1
                let t = DemoJSON.make(TripTask.self, [
                    "id": s.nextId, "tripId": id, "title": r.str("title") ?? "Task",
                    "createdBy": s.me.id, "done": false,
                    "creatorName": s.me.name,
                    "createdAt": DemoJSON.stamp(Date())
                ])
                s.tripTasks[id, default: []].append(t)
                return t
            }
            return try send(task)

        case ("POST", ["trips", _, "plan", "tasks", _, "claim"]),
             ("POST", ["trips", _, "plan", "tasks", _, "done"]):
            guard let id = r.id(1), let taskId = r.id(4) else { return nil }
            let claiming = r.segments[5] == "claim"
            // TripTask is entirely immutable, so a toggle means rebuilding it through
            // its own coder rather than assigning a field.
            let task = await store.write { s -> TripTask? in
                guard var tasks = s.tripTasks[id],
                      let i = tasks.firstIndex(where: { $0.id == taskId }),
                      var dict = try? encodeToObject(tasks[i]) else { return nil }
                if claiming {
                    let mine = tasks[i].claimedBy == s.me.id
                    if mine {
                        // Releasing: the keys have to go, not be set to a null — an
                        // Optional stored as Any is not something JSONSerialization
                        // will accept.
                        dict.removeValue(forKey: "claimedBy")
                        dict.removeValue(forKey: "claimerName")
                        dict.removeValue(forKey: "claimerUsername")
                    } else {
                        dict["claimedBy"] = s.me.id
                        dict["claimerName"] = s.me.name
                        dict["claimerUsername"] = s.me.username
                        appendSystemLine(&s, id, "\(s.me.name) claimed \"\(tasks[i].title)\"")
                    }
                } else {
                    let nowDone = !tasks[i].done
                    dict["done"] = nowDone
                    if nowDone { appendSystemLine(&s, id, "\(s.me.name) completed \"\(tasks[i].title)\"") }
                }
                tasks[i] = DemoJSON.make(TripTask.self, dict)
                s.tripTasks[id] = tasks
                return tasks[i]
            }
            guard let t = task else { throw fail("Task not found", 404) }
            return try send(t)

        case ("DELETE", ["trips", _, "plan", "tasks", _]):
            guard let id = r.id(1), let taskId = r.id(4) else { return nil }
            await store.write { s in s.tripTasks[id]?.removeAll { $0.id == taskId } }
            return try ok()

        case ("POST", ["trips", _, "plan", "dates"]):
            guard let id = r.id(1) else { return nil }
            let options = await store.write { s -> [TripDateOption] in
                s.nextId += 1
                let o = DemoJSON.make(TripDateOption.self, [
                    "id": s.nextId, "tripId": id, "date": r.str("date") ?? DemoJSON.day(Date()),
                    "createdBy": s.me.id, "votes": 1, "voted": true
                ])
                s.tripDates[id, default: []].append(o)
                s.tripDates[id]?.sort { $0.date < $1.date }
                return s.tripDates[id] ?? []
            }
            return try send(options)

        case ("POST", ["trips", _, "plan", "dates", _, "vote"]):
            guard let id = r.id(1), let optionId = r.id(4) else { return nil }
            let options = await store.write { s -> [TripDateOption] in
                guard var opts = s.tripDates[id],
                      let i = opts.firstIndex(where: { $0.id == optionId }),
                      var dict = try? encodeToObject(opts[i]) else { return s.tripDates[id] ?? [] }
                let wasVoted = opts[i].voted
                dict["voted"] = !wasVoted
                dict["votes"] = max(0, opts[i].votes + (wasVoted ? -1 : 1))
                opts[i] = DemoJSON.make(TripDateOption.self, dict)
                s.tripDates[id] = opts
                return opts
            }
            return try send(options)

        case ("DELETE", ["trips", _, "plan", "dates", _]):
            guard let id = r.id(1), let optionId = r.id(4) else { return nil }
            await store.write { s in s.tripDates[id]?.removeAll { $0.id == optionId } }
            return try ok()

        // MARK: Vault money

        case ("GET", ["vault", "trip", _]):
            guard let id = r.id(2) else { return nil }
            await ripenMyClaims()
            return try send(await store.vaultSummary(tripId: id))

        case ("POST", ["vault"]):
            guard let tripId = r.int("tripId") else { throw fail("tripId is required") }
            try await addExpense(r, tripId: tripId)
            return try ok()

        case ("DELETE", ["vault", _]):
            guard let id = r.id(1) else { return nil }
            await store.write { s in
                for (tripId, entries) in s.entries {
                    s.entries[tripId] = entries.filter { $0.id != id }
                }
            }
            return try ok()

        // I say I have paid my share. On the server this raises a claim the other person
        // confirms; here it does the same, and `ripenMyClaims` plays their part shortly.
        case ("PUT", ["vault", "splits", _, "paid"]):
            guard let splitId = r.id(2) else { return nil }
            guard let found = await store.locateSplit(splitId) else { throw fail("Split not found", 404) }
            if found.entry.paidById == DemoSeed.meId {
                // Nothing to confirm when I fronted the expense myself.
                await store.mutateSplit(splitId) { $0.paid = true; $0.cashPending = false }
            } else {
                await store.mutateSplit(splitId) { $0.cashPending = true }
                await store.write { $0.claimedAt[splitId] = Date() }
            }
            return try ok()

        // Someone claimed they paid me and I am confirming it.
        case ("POST", ["vault", "splits", _, "cash-verify"]):
            guard let splitId = r.id(2) else { return nil }
            guard let found = await store.locateSplit(splitId) else { throw fail("Split not found", 404) }
            await store.mutateSplit(splitId) { $0.paid = true; $0.cashPending = false; $0.paidAt = DemoJSON.stamp(Date()) }
            await store.write { s in
                let who = found.split.userUsername.map { "@\($0)" } ?? found.split.userName ?? "A member"
                let toWhom = s.me.username
                appendSystemLine(&s, found.tripId,
                                 String(format: "%@ paid $%.2f to @%@ in cash (verified)", who, found.split.amount, toWhom))
                s.claimedAt[splitId] = nil
            }
            return try ok()

        case ("POST", ["vault", "splits", _, "cash-decline"]):
            guard let splitId = r.id(2) else { return nil }
            await store.mutateSplit(splitId) { $0.cashPending = false }
            await store.write { $0.claimedAt[splitId] = nil }
            return try ok()

        case ("POST", ["vault", "remind"]):
            return try ok()

        // MARK: Crash pads

        case ("GET", ["crashpads"]):
            return try send(await store.read { $0.crashPads })

        case ("GET", ["crashpads", "mine"]):
            let payload = await store.read { s -> [String: Any] in
                var out: [String: Any] = [
                    "incoming": (try? encodeToArray(s.crashPadIncoming)) ?? [],
                    "outgoing": (try? encodeToArray(s.crashPadOutgoing)) ?? []
                ]
                if let pad = s.myCrashPad, let obj = try? encodeToObject(pad) { out["pad"] = obj }
                return out
            }
            return try send(payload)

        case ("PUT", ["crashpads", "mine"]):
            let pad = await store.write { s -> MyCrashPad in
                s.nextId += 1
                let p = DemoJSON.make(MyCrashPad.self, [
                    "id": s.myCrashPad?.id ?? s.nextId, "userId": s.me.id,
                    "title": r.str("title") ?? "My place",
                    "capacity": r.int("capacity") ?? 1,
                    "description": r.str("description") ?? "",
                    "area": r.str("area") ?? "",
                    "isActive": r.bool("isActive") ?? true,
                    "createdAt": DemoJSON.stamp(Date()),
                    "updatedAt": DemoJSON.stamp(Date())
                ])
                s.myCrashPad = p
                return p
            }
            return try send(pad)

        case ("DELETE", ["crashpads", "mine"]):
            await store.write { $0.myCrashPad = nil }
            return try ok()

        case ("POST", ["crashpads", _, "request"]):
            guard let padId = r.id(1) else { return nil }
            let request = await store.write { s -> CrashPadRequest in
                s.nextId += 1
                let pad = s.crashPads.first { $0.id == padId }
                let req = DemoJSON.make(CrashPadRequest.self, [
                    "id": s.nextId, "padId": padId, "requesterId": s.me.id,
                    "status": "pending",
                    "startDate": r.str("startDate") ?? DemoJSON.day(DemoJSON.ahead(days: 14)),
                    "endDate": r.str("endDate") ?? DemoJSON.day(DemoJSON.ahead(days: 16)),
                    "message": r.str("message") ?? "",
                    "padTitle": pad?.title ?? "Crash pad",
                    "padArea": pad?.area ?? "",
                    "hostName": pad?.hostName ?? "Host",
                    "hostUsername": pad?.hostUsername ?? "host",
                    "requesterName": s.me.name, "requesterUsername": s.me.username,
                    "createdAt": DemoJSON.stamp(Date())
                ])
                s.crashPadOutgoing.append(req)
                return req
            }
            return try send(request)

        case ("POST", ["crashpads", "requests", _, "respond"]):
            guard let reqId = r.id(2) else { return nil }
            let accept = r.bool("accept") ?? true
            let updated = await store.write { s -> CrashPadRequest? in
                guard let i = s.crashPadIncoming.firstIndex(where: { $0.id == reqId }),
                      var dict = try? encodeToObject(s.crashPadIncoming[i]) else { return nil }
                dict["status"] = accept ? "accepted" : "declined"
                s.crashPadIncoming[i] = DemoJSON.make(CrashPadRequest.self, dict)
                return s.crashPadIncoming[i]
            }
            guard let req = updated else { throw fail("Request not found", 404) }
            return try send(req)

        case ("DELETE", ["crashpads", "requests", _]):
            guard let reqId = r.id(2) else { return nil }
            await store.write { s in
                s.crashPadIncoming.removeAll { $0.id == reqId }
                s.crashPadOutgoing.removeAll { $0.id == reqId }
            }
            return try ok()

        default:
            return nil
        }
    }

    // MARK: - Expenses

    private static func addExpense(_ r: Request, tripId: Int) async throws {
        let store = DemoStore.shared
        let amount = r.dbl("amount") ?? 0
        guard amount > 0 else { throw fail("Expense amount must be a positive number.") }
        let description = (r.str("description") ?? "").trimmingCharacters(in: .whitespaces)
        guard !description.isEmpty else { throw fail("A description is required.") }

        await store.write { s in
            s.nextId += 1
            let entryId = s.nextId
            let payerId = r.int("paidBy") ?? s.me.id
            let members = s.trips.first { $0.id == tripId }?.activeParticipants ?? []

            // Client-provided splits when present, otherwise an even split across the
            // active roster with the rounding remainder on the last member — the same
            // arithmetic the server uses, so the balances agree with what people expect.
            var splitPairs: [(userId: Int, amount: Double)] = []
            if let provided = r.body["splits"] as? [[String: Any]], !provided.isEmpty {
                splitPairs = provided.compactMap { item in
                    guard let uid = item["userId"] as? Int else { return nil }
                    let amt = (item["amount"] as? Double) ?? Double((item["amount"] as? Int) ?? 0)
                    return (uid, amt)
                }
            } else if !members.isEmpty {
                let each = (amount / Double(members.count) * 100).rounded(.down) / 100
                let last = ((amount - each * Double(members.count - 1)) * 100).rounded() / 100
                splitPairs = members.enumerated().map { i, m in
                    (m.id, i == members.count - 1 ? last : each)
                }
            }

            let splits: [[String: Any]] = splitPairs.map { pair in
                let member = members.first { $0.id == pair.userId }
                s.nextId += 1
                return [
                    "id": s.nextId, "userId": pair.userId,
                    "userName": member?.name ?? "Member",
                    "userUsername": member?.username ?? "member",
                    "amount": pair.amount,
                    "paid": pair.userId == payerId,
                    "cashPending": false
                ]
            }

            let payer = payerId == s.me.id ? (name: s.me.name, username: s.me.username)
                                           : (name: members.first { $0.id == payerId }?.name ?? "Member",
                                              username: members.first { $0.id == payerId }?.username ?? "member")

            var dict: [String: Any] = [
                "id": entryId, "description": description, "amount": amount,
                "currency": "USD",
                "date": r.str("date") ?? DemoJSON.day(Date()),
                "paidBy": payerId, "paidByName": payer.name, "paidByUsername": payer.username,
                "splits": splits
            ]
            if let category = r.str("category"), !category.isEmpty { dict["category"] = category }
            s.entries[tripId, default: []].append(DemoJSON.make(VaultEntry.self, dict))
        }
    }

    // MARK: - The other half of the settle-up loop

    /// Confirms claims I have made once they are a few seconds old.
    ///
    /// Only claims where I am the debtor: a claim against me is mine to Verify or
    /// Decline, and auto-confirming those would delete the most interesting thing on the
    /// screen. Each confirmation posts the same system line into the vault chat that the
    /// server posts, so the loop closes visibly rather than just going quiet.
    private static func ripenMyClaims() async {
        let store = DemoStore.shared
        let due: [(splitId: Int, tripId: Int, amount: Double, payer: String)] = await store.read { s in
            var out: [(splitId: Int, tripId: Int, amount: Double, payer: String)] = []
            for (tripId, entries) in s.entries {
                for entry in entries where entry.paidById != s.me.id {
                    for split in entry.splits ?? []
                    where split.userId == s.me.id && split.isCashPending {
                        let claimed = s.claimedAt[split.id] ?? Date.distantPast
                        guard Date().timeIntervalSince(claimed) >= claimRipenSeconds else { continue }
                        out.append((split.id, tripId, split.amount, entry.paidByUsername ?? "them"))
                    }
                }
            }
            return out
        }
        guard !due.isEmpty else { return }

        for item in due {
            await store.mutateSplit(item.splitId) {
                $0.paid = true; $0.cashPending = false; $0.paidAt = DemoJSON.stamp(Date())
            }
            await store.write { s in
                appendSystemLine(&s, item.tripId,
                                 String(format: "@%@ paid $%.2f to @%@ in cash (verified)",
                                        s.me.username, item.amount, item.payer))
                s.claimedAt[item.splitId] = nil
            }
        }
    }

    // MARK: - Helpers

    private static func appendSystemLine(_ s: inout DemoStore.Snapshot, _ tripId: Int, _ text: String) {
        s.nextId += 1
        s.tripChat[tripId, default: []].append(DemoJSON.make(TripChatMessage.self, [
            "id": s.nextId, "tripId": tripId, "senderId": s.me.id,
            "senderName": s.me.name, "senderUsername": s.me.username,
            "content": text, "isSystem": true,
            "createdAt": DemoJSON.stamp(Date())
        ]))
    }

    /// The trip list card shows a running total, which has to follow the expenses.
    private static func withVaultTotal(_ trip: Trip, in s: DemoStore.Snapshot) -> Trip {
        var copy = trip
        copy.vaultTotal = (s.entries[trip.id] ?? []).reduce(0) { $0 + $1.amount }
        return copy
    }

    static func encodeToObject<T: Encodable>(_ value: T) throws -> [String: Any] {
        let data = try DemoJSON.encoder.encode(value)
        return (try JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
    }

    static func encodeToArray<T: Encodable>(_ value: [T]) throws -> [Any] {
        let data = try DemoJSON.encoder.encode(value)
        return (try JSONSerialization.jsonObject(with: data) as? [Any]) ?? []
    }
}
