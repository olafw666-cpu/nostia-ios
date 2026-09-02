import Foundation

/// The demo build's entire world, held in memory and mirrored to a single JSON file.
///
/// This is deliberately more than a bag of canned responses. Every mutation the app
/// makes lands here and is read back by the next request, so sending a message really
/// does put it in the thread, adding an expense really does move the balances, and all
/// of it survives a force-quit. That read-your-writes behaviour is the whole difference
/// between an app that looks alive and one that looks like a screenshot.
///
/// What it is NOT is a server: nothing here is shared with anyone. Actions taken in the
/// demo reach this device's disk and stop there.
actor DemoStore {
    static let shared = DemoStore()

    /// Everything that persists, in one Codable value. A single snapshot file keeps
    /// save and load trivial, and makes `reset()` a delete.
    struct Snapshot: Codable {
        var version: Int = 1
        var me: User
        var people: [User]
        var posts: [FeedPost]
        var postComments: [Int: [FeedComment]]
        var followers: [FollowUser]
        var following: [FollowUser]
        var suggestions: [SuggestedUser]
        var blocked: [BlockedUser]
        var conversations: [Conversation]
        var messages: [Int: [Message]]
        var notifications: [NostiaNotification]
        var trips: [Trip]
        var entries: [Int: [VaultEntry]]
        var tripChat: [Int: [TripChatMessage]]
        var tripTasks: [Int: [TripTask]]
        var tripDates: [Int: [TripDateOption]]
        var experiences: [Experience]
        var experienceComments: [Int: [FeedComment]]
        var organizations: [Organization]
        var crashPads: [FriendCrashPad]
        var myCrashPad: MyCrashPad?
        var crashPadIncoming: [CrashPadRequest]
        var crashPadOutgoing: [CrashPadRequest]
        var dailyAdventure: DailyAdventure?
        var pointsBalance: Int
        var cosmetics: [CosmeticItem]
        var plan: AdventurePlan?
        var pushEnabled: Bool = true
        /// When I claimed a split as paid, keyed by split id. The demo plays the other
        /// person's part a few seconds later; see `ripenMyClaims`.
        var claimedAt: [Int: Date] = [:]
        var nextId: Int = 10_000
    }

    private var snapshot: Snapshot!

    private static let fileURL: URL = {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return dir.appendingPathComponent("demo-state.json")
    }()

    // MARK: - Lifecycle

    /// Returns the saved world, building a fresh one from `DemoSeed` on first launch.
    /// A snapshot written by an older build is discarded rather than migrated: this is
    /// demo data, and a half-decoded world is worse than a clean one.
    private func loaded() -> Snapshot {
        if let s = snapshot { return s }
        if let data = try? Data(contentsOf: Self.fileURL),
           let restored = try? DemoJSON.decoder.decode(Snapshot.self, from: data),
           restored.version == 1 {
            snapshot = restored
        } else {
            snapshot = DemoSeed.build()
            persist()
        }
        return snapshot
    }

    /// Reads some part of the world.
    func read<T>(_ body: (Snapshot) -> T) -> T {
        body(loaded())
    }

    /// Changes the world, then writes it to disk.
    @discardableResult
    func write<T>(_ body: (inout Snapshot) -> T) -> T {
        var s = loaded()
        let result = body(&s)
        snapshot = s
        persist()
        return result
    }

    /// Allocates an id that cannot collide with a seeded one.
    func nextId() -> Int {
        write { s in
            s.nextId += 1
            return s.nextId
        }
    }

    /// Restores the pristine seeded world, behind "Reset demo data" in Settings.
    func reset() {
        try? FileManager.default.removeItem(at: Self.fileURL)
        snapshot = DemoSeed.build()
        persist()
    }

    private func persist() {
        guard let s = snapshot, let data = try? DemoJSON.encoder.encode(s) else { return }
        // Atomic so a crash mid-write cannot leave a truncated file, which would throw
        // the next launch back to the seed and silently drop the demo's history.
        try? data.write(to: Self.fileURL, options: .atomic)
    }

    // MARK: - Derived reads
    //
    // The vault summary is computed, not stored. Balances have to agree with the
    // expenses they come from, and recomputing on read is cheaper than keeping two
    // versions of the truth in step through every mutation.

    func vaultSummary(tripId: Int) -> VaultSummary {
        read { s in
            let entries = s.entries[tripId] ?? []
            let members = s.trips.first(where: { $0.id == tripId })?.activeParticipants ?? []
            let me = s.me.id

            var paid: [Int: Double] = [:]
            var owes: [Int: Double] = [:]
            for entry in entries {
                paid[entry.paidById ?? 0, default: 0] += entry.amount
                for split in entry.splits ?? [] where !split.paid {
                    owes[split.userId, default: 0] += split.amount
                }
            }

            let balances: [VaultBalance] = members.map { member in
                let p = paid[member.id] ?? 0
                let o = owes[member.id] ?? 0
                return VaultBalance(
                    id: member.id,
                    name: member.name ?? member.username ?? "Member",
                    username: member.username,
                    paid: p,
                    owes: o,
                    balance: p - o
                )
            }

            // What I still owe other people, which is what the Settle Up sheet lists.
            let unpaid: [UnpaidSplit] = entries.flatMap { entry -> [UnpaidSplit] in
                (entry.splits ?? [])
                    .filter { $0.userId == me && !$0.paid && entry.paidById != me }
                    .map { split in
                        UnpaidSplit(
                            id: split.id,
                            vaultEntryId: entry.id,
                            userId: split.userId,
                            amount: split.amount,
                            paid: split.paid,
                            description: entry.description,
                            date: entry.date,
                            currency: entry.currency,
                            cashPending: split.cashPending,
                            paidByUsername: entry.paidByUsername
                        )
                    }
            }

            return VaultSummary(
                entries: entries.sorted { $0.id > $1.id },
                balances: balances,
                totalAmount: entries.reduce(0) { $0 + $1.amount },
                vaultLeaderId: s.trips.first(where: { $0.id == tripId })?.vaultLeaderId,
                currentUserId: me,
                unpaidSplits: unpaid
            )
        }
    }

    /// Finds a split and the expense it belongs to, across every vault.
    func locateSplit(_ splitId: Int) -> (tripId: Int, entry: VaultEntry, split: VaultSplit)? {
        read { s in
            for (tripId, entries) in s.entries {
                for entry in entries {
                    if let split = (entry.splits ?? []).first(where: { $0.id == splitId }) {
                        return (tripId, entry, split)
                    }
                }
            }
            return nil
        }
    }

    /// Applies a change to one split, wherever it lives.
    func mutateSplit(_ splitId: Int, _ change: (inout VaultSplit) -> Void) {
        write { s in
            for (tripId, var entries) in s.entries {
                var touched = false
                for i in entries.indices {
                    guard var splits = entries[i].splits,
                          let j = splits.firstIndex(where: { $0.id == splitId }) else { continue }
                    change(&splits[j])
                    entries[i].splits = splits
                    touched = true
                }
                if touched { s.entries[tripId] = entries }
            }
        }
    }
}
