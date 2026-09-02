import Foundation

/// The world the demo starts in.
///
/// Fixtures are written as wire-shaped dictionaries and decoded through each model's
/// own decoder (`DemoJSON.make`) rather than built with memberwise initialisers. Three
/// reasons: `User` and `ConsentStatus` keep private stored properties so their
/// memberwise inits are private and unusable from here; `DailyAdventure` and
/// `NostiaNotification` declare `init(from:)` and therefore have no memberwise init at
/// all; and decoding proves every key name is right the first time the app launches,
/// loudly, instead of showing a blank card later.
///
/// Content is drawn from what the repo already had rather than invented: the 35
/// landmarks are the real seeded set documented in SEEDED_LANDMARKS.md, complete with
/// their coordinates and their tags from the app's own `experienceTags` vocabulary.
///
/// Timestamps are relative to first launch. A demo whose newest post is three weeks old
/// reads as abandoned no matter how good the rest looks.
nonisolated enum DemoSeed {

    static let meId = 1

    // MARK: - People

    private static func person(
        _ id: Int, _ username: String, _ name: String,
        bio: String? = nil, dev: Bool = false, lat: Double? = nil, lng: Double? = nil
    ) -> User {
        var dict: [String: Any] = [
            "id": id, "username": username, "name": name,
            "homeStatus": id % 3 == 0 ? "open" : "closed",
            "role": "user",
            "account_type": dev ? "dev" : "user",
            "isDev": dev,
            "followersCount": 40 + id * 17,
            "visited_visibility": "followers",
            "has_created_experience": 1,
            "createdAt": DemoJSON.stamp(DemoJSON.ago(days: 300 - id))
        ]
        if let bio { dict["bio"] = bio }
        if let lat { dict["latitude"] = lat }
        if let lng { dict["longitude"] = lng }
        return DemoJSON.make(User.self, dict)
    }

    /// Everyone who is not the demo user. Ids are stable; the router looks people up by id.
    static func people() -> [User] {
        [
            person(2, "maya", "Maya Chen", bio: "Chasing good coffee and better bridges.", lat: 40.7211, lng: -73.9878),
            person(3, "theo", "Theo Alvarez", bio: "Runs the long way round. Always.", dev: true, lat: 40.7484, lng: -73.9857),
            person(4, "priya", "Priya Raman", bio: "Museum hours are the best hours.", lat: 40.7794, lng: -73.9632),
            person(5, "sam", "Sam Okafor", bio: "Will drive. Will not navigate.", lat: 40.6782, lng: -73.9442),
            person(6, "nina", "Nina Berg", bio: "Cold water swimmer, warm apartment host.", lat: 42.3601, lng: -71.0589),
            person(7, "luca", "Luca Ferrari", bio: "Two things: pasta and public transit.", lat: 38.9072, lng: -77.0369)
        ]
    }

    static func me() -> User {
        DemoJSON.make(User.self, [
            "id": meId, "username": "olaf", "name": "Olaf Woodall",
            "email": "olaf@nostia.io",
            "bio": "Building Nostia. Mostly on foot.",
            "homeStatus": "open",
            "latitude": 40.7306, "longitude": -73.9866,
            "role": "user",
            "account_type": "dev",
            "isDev": true,
            "followersCount": 128,
            "data_not_sold": 0,
            "has_created_experience": 1,
            "visited_visibility": "followers",
            "createdAt": DemoJSON.stamp(DemoJSON.ago(days: 412))
        ])
    }

    // MARK: - Social graph

    private static func follow(_ u: User) -> FollowUser {
        DemoJSON.make(FollowUser.self, [
            "id": u.id, "username": u.username, "name": u.name,
            "homeStatus": u.homeStatus ?? "closed", "isDev": u.isDev
        ])
    }

    static func suggestions() -> [SuggestedUser] {
        [
            ["id": 8, "username": "arun", "name": "Arun Kapoor", "followerCount": 61, "isNearby": true],
            ["id": 9, "username": "jo", "name": "Jo Lindqvist", "followerCount": 34, "isNearby": true],
            ["id": 10, "username": "dee", "name": "Dee Washington", "followerCount": 118, "isNearby": false]
        ].map { DemoJSON.make(SuggestedUser.self, $0) }
    }

    // MARK: - Feed

    static func posts(_ people: [User]) -> [FeedPost] {
        let by: (Int) -> User = { id in people.first { $0.id == id } ?? people[0] }
        let specs: [(Int, Int, String, Int, Int, Int, Bool, Date)] = [
            (501, 2, "Walked the whole length of the Brooklyn Bridge at sunrise. Empty. Worth the alarm.", 14, 0, 3, true,  DemoJSON.ago(hours: 2)),
            (502, 5, "Nobody told me Green-Wood has parrots. There are parrots.", 9, 0, 2, false, DemoJSON.ago(hours: 6)),
            (503, 3, "Adventure said 'take the deliberately inefficient route'. Ended up in a bookshop I'd walked past for six years.", 22, 0, 5, true, DemoJSON.ago(hours: 11)),
            (504, 4, "The Met at opening time is a completely different museum.", 17, 1, 1, false, DemoJSON.ago(days: 1)),
            (505, 6, "Swan boats. I have no further comment.", 11, 0, 0, false, DemoJSON.ago(days: 1, hours: 5)),
            (506, 7, "Georgetown waterfront, 7pm, everyone out. Best hour in DC.", 8, 0, 2, false, DemoJSON.ago(days: 2))
        ]
        return specs.map { id, uid, content, likes, dislikes, comments, liked, when in
            let u = by(uid)
            return DemoJSON.make(FeedPost.self, [
                "id": id, "userId": u.id, "username": u.username, "name": u.name,
                "isDev": u.isDev, "content": content,
                "likeCount": likes, "dislikeCount": dislikes, "commentCount": comments,
                "isLiked": liked, "isDisliked": false,
                "createdAt": DemoJSON.iso(when)
            ])
        }
    }

    static func postComments(_ people: [User]) -> [Int: [FeedComment]] {
        func comment(_ id: Int, _ uid: Int, _ text: String, _ when: Date) -> FeedComment {
            let u = people.first { $0.id == uid } ?? people[0]
            return DemoJSON.make(FeedComment.self, [
                "id": id, "userId": u.id, "username": u.username, "name": u.name,
                "content": text, "isDev": u.isDev, "createdAt": DemoJSON.iso(when)
            ])
        }
        return [
            501: [comment(601, 5, "How early is sunrise these days?", DemoJSON.ago(hours: 1)),
                  comment(602, 4, "Doing this Saturday.", DemoJSON.ago(minutes: 40))],
            503: [comment(603, 2, "Which bookshop?", DemoJSON.ago(hours: 9))]
        ]
    }

    // MARK: - Messages

    static func conversations(_ people: [User]) -> ([Conversation], [Int: [Message]]) {
        func msg(_ id: Int, _ convo: Int, _ senderId: Int, _ text: String, _ when: Date) -> Message {
            let sender = senderId == meId ? me() : (people.first { $0.id == senderId } ?? people[0])
            return DemoJSON.make(Message.self, [
                "id": id, "conversationId": convo, "senderId": sender.id,
                "senderName": sender.name, "senderUsername": sender.username,
                "content": text, "read": true,
                // Strict ISO 8601: ChatView parses with a bare ISO8601DateFormatter and
                // renders an empty timestamp on anything else.
                "createdAt": DemoJSON.iso(when)
            ])
        }
        let convos: [Conversation] = [
            DemoJSON.make(Conversation.self, [
                "id": 301, "otherUserId": 2, "otherUserName": "Maya Chen", "otherUserUsername": "maya",
                "lastMessage": "Saturday works. I'll bring the thermos.", "unreadCount": 0,
                "updatedAt": DemoJSON.iso(DemoJSON.ago(minutes: 25))
            ]),
            DemoJSON.make(Conversation.self, [
                "id": 302, "otherUserId": 5, "otherUserName": "Sam Okafor", "otherUserUsername": "sam",
                "lastMessage": "Added the gas to the vault", "unreadCount": 1,
                "updatedAt": DemoJSON.iso(DemoJSON.ago(hours: 4))
            ]),
            DemoJSON.make(Conversation.self, [
                "id": 303, "otherUserId": 6, "otherUserName": "Nina Berg", "otherUserUsername": "nina",
                "lastMessage": "Spare room is yours whenever.", "unreadCount": 0,
                "updatedAt": DemoJSON.iso(DemoJSON.ago(days: 3))
            ])
        ]
        let messages: [Int: [Message]] = [
            301: [
                msg(401, 301, 2, "Are you doing the bridge walk this weekend?", DemoJSON.ago(hours: 3)),
                msg(402, 301, meId, "Planning on it. Early though — like 6.", DemoJSON.ago(hours: 2, minutes: 40)),
                msg(403, 301, 2, "Saturday works. I'll bring the thermos.", DemoJSON.ago(minutes: 25))
            ],
            302: [
                msg(404, 302, 5, "Filled up on the way back, was $52", DemoJSON.ago(hours: 5)),
                msg(405, 302, meId, "Nice, chuck it in the vault", DemoJSON.ago(hours: 4, minutes: 30)),
                msg(406, 302, 5, "Added the gas to the vault", DemoJSON.ago(hours: 4))
            ],
            303: [
                msg(407, 303, meId, "Might be in Boston next month", DemoJSON.ago(days: 3, hours: 1)),
                msg(408, 303, 6, "Spare room is yours whenever.", DemoJSON.ago(days: 3))
            ]
        ]
        return (convos, messages)
    }

    // MARK: - Notifications

    static func notifications() -> [NostiaNotification] {
        let specs: [(Int, String, String, String, [String: Any], Bool, Date)] = [
            (701, "vault_expense", "New expense in Catskills Weekend",
             "@sam added \"Gas — round trip\" ($52.40) with you in the split",
             ["tripId": 101], false, DemoJSON.ago(hours: 4)),
            (702, "new_follower", "Priya Raman started following you",
             "Tap to see their profile", ["userId": 4], false, DemoJSON.ago(hours: 9)),
            (703, "message", "Maya Chen sent you a message",
             "Saturday works. I'll bring the thermos.", ["conversationId": 301], true, DemoJSON.ago(minutes: 25)),
            (704, "vault_reminder", "You owe $26.20 in Catskills Weekend",
             "@sam is waiting on your share of \"Gas — round trip\"", ["tripId": 101], true, DemoJSON.ago(days: 1)),
            (705, "added_to_vault", "Nina Berg added you to Lisbon in October",
             "You're now a member of this vault", ["tripId": 102], true, DemoJSON.ago(days: 2))
        ]
        return specs.map { id, type, title, body, data, read, when in
            DemoJSON.make(NostiaNotification.self, [
                "id": id, "type": type, "title": title, "body": body,
                "data": data, "read": read,
                // Strict ISO 8601 — NostiaNotification.timeAgo has no fallback parser.
                "createdAt": DemoJSON.iso(when)
            ])
        }
    }

    // MARK: - Vaults

    static func trips() -> [Trip] {
        func participant(_ id: Int, _ name: String, _ username: String, _ role: String) -> [String: Any] {
            ["id": id, "name": name, "username": username, "role": role, "status": "active"]
        }
        return [
            DemoJSON.make(Trip.self, [
                "id": 101, "title": "Catskills Weekend",
                "destination": "Phoenicia, NY",
                "description": "Two nights, one very cold river.",
                "startDate": DemoJSON.day(DemoJSON.ago(days: 9)),
                "endDate": DemoJSON.day(DemoJSON.ago(days: 7)),
                "vaultLeaderId": meId,
                "vaultTotal": 611.40,
                "createdAt": DemoJSON.stamp(DemoJSON.ago(days: 21)),
                "participants": [
                    participant(meId, "Olaf Woodall", "olaf", "creator"),
                    participant(2, "Maya Chen", "maya", "participant"),
                    participant(5, "Sam Okafor", "sam", "participant"),
                    participant(4, "Priya Raman", "priya", "participant")
                ]
            ]),
            DemoJSON.make(Trip.self, [
                "id": 102, "title": "Lisbon in October",
                "destination": "Lisbon, Portugal",
                "description": "Still arguing about the dates.",
                "vaultLeaderId": 6,
                "vaultTotal": 240.00,
                "createdAt": DemoJSON.stamp(DemoJSON.ago(days: 5)),
                "participants": [
                    participant(6, "Nina Berg", "nina", "creator"),
                    participant(meId, "Olaf Woodall", "olaf", "participant"),
                    participant(7, "Luca Ferrari", "luca", "participant")
                ]
            ])
        ]
    }

    /// Expenses are arranged so both halves of the settle-up loop are visible the moment
    /// the vault opens: one expense I fronted with a claim waiting on my confirmation,
    /// and one someone else fronted where my share is still outstanding.
    static func entries() -> [Int: [VaultEntry]] {
        func split(_ id: Int, _ userId: Int, _ name: String, _ username: String,
                   _ amount: Double, paid: Bool, cashPending: Bool = false) -> [String: Any] {
            ["id": id, "userId": userId, "userName": name, "userUsername": username,
             "amount": amount, "paid": paid, "cashPending": cashPending]
        }
        let catskills: [VaultEntry] = [
            DemoJSON.make(VaultEntry.self, [
                "id": 201, "description": "Cabin — two nights", "amount": 420.00, "currency": "USD",
                "category": "Lodging", "date": DemoJSON.day(DemoJSON.ago(days: 9)),
                "paidBy": meId, "paidByName": "Olaf Woodall", "paidByUsername": "olaf",
                "splits": [
                    split(801, meId, "Olaf Woodall", "olaf", 105.00, paid: true),
                    // Maya says she has paid me back; this lands in Needs Your Approval.
                    split(802, 2, "Maya Chen", "maya", 105.00, paid: false, cashPending: true),
                    split(803, 5, "Sam Okafor", "sam", 105.00, paid: true),
                    split(804, 4, "Priya Raman", "priya", 105.00, paid: false)
                ]
            ]),
            DemoJSON.make(VaultEntry.self, [
                "id": 202, "description": "Gas — round trip", "amount": 52.40, "currency": "USD",
                "category": "Travel", "date": DemoJSON.day(DemoJSON.ago(days: 7)),
                "paidBy": 5, "paidByName": "Sam Okafor", "paidByUsername": "sam",
                "splits": [
                    split(805, meId, "Olaf Woodall", "olaf", 13.10, paid: false),
                    split(806, 2, "Maya Chen", "maya", 13.10, paid: true),
                    split(807, 5, "Sam Okafor", "sam", 13.10, paid: true),
                    split(808, 4, "Priya Raman", "priya", 13.10, paid: false)
                ]
            ]),
            DemoJSON.make(VaultEntry.self, [
                "id": 203, "description": "Groceries", "amount": 139.00, "currency": "USD",
                "category": "Food", "date": DemoJSON.day(DemoJSON.ago(days: 8)),
                "paidBy": 2, "paidByName": "Maya Chen", "paidByUsername": "maya",
                "splits": [
                    split(809, meId, "Olaf Woodall", "olaf", 34.75, paid: false),
                    split(810, 2, "Maya Chen", "maya", 34.75, paid: true),
                    split(811, 5, "Sam Okafor", "sam", 34.75, paid: true),
                    split(812, 4, "Priya Raman", "priya", 34.75, paid: true)
                ]
            ])
        ]
        let lisbon: [VaultEntry] = [
            DemoJSON.make(VaultEntry.self, [
                "id": 204, "description": "Flight deposit", "amount": 240.00, "currency": "USD",
                "category": "Travel", "date": DemoJSON.day(DemoJSON.ago(days: 4)),
                "paidBy": 6, "paidByName": "Nina Berg", "paidByUsername": "nina",
                "splits": [
                    split(813, 6, "Nina Berg", "nina", 80.00, paid: true),
                    split(814, meId, "Olaf Woodall", "olaf", 80.00, paid: false),
                    split(815, 7, "Luca Ferrari", "luca", 80.00, paid: false)
                ]
            ])
        ]
        return [101: catskills, 102: lisbon]
    }

    static func tripChat() -> [Int: [TripChatMessage]] {
        func line(_ id: Int, _ tripId: Int, _ senderId: Int, _ name: String, _ username: String,
                  _ text: String, _ when: Date, system: Bool = false) -> TripChatMessage {
            DemoJSON.make(TripChatMessage.self, [
                "id": id, "tripId": tripId, "senderId": senderId,
                "senderName": name, "senderUsername": username,
                "content": text, "isSystem": system,
                "createdAt": DemoJSON.stamp(when)
            ])
        }
        return [
            101: [
                line(901, 101, 5, "Sam Okafor", "sam", "Cabin was worth every cent", DemoJSON.ago(days: 7)),
                line(902, 101, 2, "Maya Chen", "maya", "Sent you the cabin money", DemoJSON.ago(days: 6)),
                line(903, 101, meId, "Olaf Woodall", "olaf", "Got it, confirming now", DemoJSON.ago(days: 6))
            ],
            102: [
                line(904, 102, 6, "Nina Berg", "nina", "Deposit is down, dates still open", DemoJSON.ago(days: 4))
            ]
        ]
    }

    static func tripTasks() -> [Int: [TripTask]] {
        func task(_ id: Int, _ tripId: Int, _ title: String, _ createdBy: Int,
                  claimedBy: Int? = nil, claimerName: String? = nil, done: Bool = false) -> TripTask {
            var d: [String: Any] = [
                "id": id, "tripId": tripId, "title": title, "createdBy": createdBy,
                "done": done, "createdAt": DemoJSON.stamp(DemoJSON.ago(days: 5))
            ]
            if let claimedBy { d["claimedBy"] = claimedBy }
            if let claimerName { d["claimerName"] = claimerName }
            return DemoJSON.make(TripTask.self, d)
        }
        return [
            102: [
                task(1001, 102, "Book the flights", 6, claimedBy: 6, claimerName: "Nina Berg"),
                task(1002, 102, "Find a place to stay", 6, claimedBy: meId, claimerName: "Olaf Woodall"),
                task(1003, 102, "Work out the trains", 7, done: true)
            ],
            101: []
        ]
    }

    static func tripDates() -> [Int: [TripDateOption]] {
        [
            102: [
                DemoJSON.make(TripDateOption.self, [
                    "id": 1101, "tripId": 102, "date": DemoJSON.day(DemoJSON.ahead(days: 40)),
                    "createdBy": 6, "votes": 2, "voted": true
                ]),
                DemoJSON.make(TripDateOption.self, [
                    "id": 1102, "tripId": 102, "date": DemoJSON.day(DemoJSON.ahead(days: 54)),
                    "createdBy": 7, "votes": 1, "voted": false
                ])
            ],
            101: []
        ]
    }

    // MARK: - Experiences
    //
    // The 35 landmarks seeded into production and documented in SEEDED_LANDMARKS.md —
    // real places, real coordinates, tags drawn from the app's own `experienceTags`.

    private static let landmarks: [(Int, String, String, Double, Double, [String])] = [
        (58, "Statue of Liberty", "NYC", 40.6892, -74.0445, ["culture", "water", "outdoors"]),
        (59, "Empire State Building", "NYC", 40.7484, -73.9857, ["culture", "social"]),
        (60, "Times Square", "NYC", 40.7580, -73.9855, ["nightlife", "social", "culture"]),
        (61, "Bethesda Terrace, Central Park", "NYC", 40.7740, -73.9711, ["outdoors", "nature", "art"]),
        (62, "Brooklyn Bridge Walk", "NYC", 40.7061, -73.9969, ["outdoors", "culture", "water"]),
        (63, "Top of the Rock", "NYC", 40.7593, -73.9794, ["culture", "social"]),
        (64, "The Metropolitan Museum of Art", "NYC", 40.7794, -73.9632, ["art", "culture"]),
        (65, "One World Observatory", "NYC", 40.7127, -74.0134, ["culture", "social"]),
        (66, "The High Line", "NYC", 40.7480, -74.0048, ["outdoors", "art", "nature"]),
        (67, "Grand Central Terminal", "NYC", 40.7527, -73.9772, ["culture", "social"]),
        (68, "Washington Square Park", "NYC", 40.7308, -73.9973, ["social", "outdoors", "music"]),
        (69, "Coney Island Boardwalk", "NYC", 40.5749, -73.9857, ["water", "outdoors", "social"]),
        (70, "Roosevelt Island Tramway", "NYC", 40.7614, -73.9537, ["outdoors", "water", "culture"]),
        (71, "Green-Wood Cemetery", "NYC", 40.6580, -73.9920, ["nature", "culture", "outdoors"]),
        (72, "Socrates Sculpture Park", "NYC", 40.7684, -73.9365, ["art", "outdoors", "water"]),
        (73, "Lincoln Memorial", "DC", 38.8893, -77.0502, ["culture", "outdoors"]),
        (74, "Washington Monument", "DC", 38.8895, -77.0353, ["culture", "outdoors"]),
        (75, "United States Capitol", "DC", 38.8899, -77.0091, ["culture"]),
        (76, "The White House", "DC", 38.8977, -77.0365, ["culture"]),
        (77, "National Air and Space Museum", "DC", 38.8882, -77.0199, ["culture", "art"]),
        (78, "Jefferson Memorial", "DC", 38.8814, -77.0365, ["culture", "water", "outdoors"]),
        (79, "Georgetown Waterfront Park", "DC", 38.9026, -77.0658, ["water", "outdoors", "social"]),
        (80, "Smithsonian National Zoo", "DC", 38.9296, -77.0497, ["nature", "outdoors", "social"]),
        (81, "Library of Congress", "DC", 38.8887, -77.0047, ["culture", "art"]),
        (82, "Arlington National Cemetery", "DC", 38.8783, -77.0687, ["culture", "nature"]),
        (83, "Fenway Park", "Boston", 42.3467, -71.0972, ["sports", "social"]),
        (84, "Boston Public Garden", "Boston", 42.3541, -71.0704, ["nature", "outdoors", "social"]),
        (85, "Quincy Market & Faneuil Hall", "Boston", 42.3600, -71.0545, ["food", "social", "culture"]),
        (86, "USS Constitution", "Boston", 42.3724, -71.0567, ["culture", "water"]),
        (87, "Bunker Hill Monument", "Boston", 42.3765, -71.0611, ["culture", "outdoors", "fitness"]),
        (88, "Old North Church", "Boston", 42.3663, -71.0544, ["culture"]),
        (89, "Harvard Yard", "Boston", 42.3744, -71.1169, ["culture", "outdoors"]),
        (90, "Boston Public Library", "Boston", 42.3494, -71.0782, ["culture", "art"]),
        (91, "New England Aquarium & Harborwalk", "Boston", 42.3592, -71.0490, ["water", "nature", "social"]),
        (92, "Acorn Street, Beacon Hill", "Boston", 42.3566, -71.0687, ["culture", "art", "outdoors"])
    ]

    static func experiences() -> [Experience] {
        landmarks.map { id, title, city, lat, lng, tags in
            // A scattering of visits and ratings so the cards do not all read identically.
            let visited = 3 + (id * 7) % 40
            let rating = 3.5 + Double((id * 3) % 4) * 0.5
            var dict: [String: Any] = [
                "id": id, "title": title, "location": city,
                "latitude": lat, "longitude": lng,
                "visibility": "public",
                "createdBy": meId, "creatorName": "Olaf",
                "visitedCount": visited, "visitingCount": (id * 3) % 9,
                "avgRating": rating, "ratingCount": max(2, visited / 3),
                "tags": tags,
                // Evergreen: no eventDate, so nothing ever expires out of the map.
                "createdAt": DemoJSON.stamp(DemoJSON.ago(days: 60))
            ]
            if id % 6 == 0 { dict["myStatus"] = "visited" }
            if id % 11 == 0 { dict["myStatus"] = "visiting" }
            return DemoJSON.make(Experience.self, dict)
        }
    }

    // MARK: - Organizations

    static func organizations() -> [Organization] {
        [
            ["id": 401, "ownerId": meId, "name": "Colorado School of Mines Outdoors",
             "ownerName": "Olaf Woodall",
             "description": "Trips, gear swaps, and people who own a second rope.",
             "locationVerificationEnabled": true, "postPermission": "members",
             "privacy": "public", "memberCount": 148, "zoneCount": 1,
             "isMember": true, "hasPendingRequest": false, "canPost": true, "myRole": "owner",
             "createdAt": DemoJSON.stamp(DemoJSON.ago(days: 200))],
            ["id": 402, "ownerId": 4, "name": "Brooklyn Morning Run Club",
             "ownerName": "Priya Raman",
             "description": "6:30am, Prospect Park, rain included.",
             "locationVerificationEnabled": true, "postPermission": "members",
             "privacy": "public", "memberCount": 62, "zoneCount": 1,
             "isMember": false, "hasPendingRequest": false, "canPost": false,
             "createdAt": DemoJSON.stamp(DemoJSON.ago(days: 90))]
        ].map { DemoJSON.make(Organization.self, $0) }
    }

    // MARK: - Crash pads

    static func crashPads() -> [FriendCrashPad] {
        [
            ["id": 501, "userId": 6, "title": "Spare room, Cambridge", "capacity": 2,
             "description": "Quiet street, ten minutes from the Red Line. Cat included.",
             "area": "Cambridge, MA", "hostName": "Nina Berg", "hostUsername": "nina",
             "createdAt": DemoJSON.stamp(DemoJSON.ago(days: 12))],
            ["id": 502, "userId": 7, "title": "Couch in Columbia Heights", "capacity": 1,
             "description": "It is a good couch. That is the whole pitch.",
             "area": "Washington, DC", "hostName": "Luca Ferrari", "hostUsername": "luca",
             "createdAt": DemoJSON.stamp(DemoJSON.ago(days: 30))]
        ].map { DemoJSON.make(FriendCrashPad.self, $0) }
    }

    // MARK: - Adventure

    static func dailyAdventure() -> DailyAdventure {
        // Copy drawn from config/adventure_pool.jsonl, which is where the real pool lives.
        DemoJSON.make(DailyAdventure.self, [
            "id": 1201,
            "title": "The Long Way Round",
            "description": "Pick somewhere you go often. Get there by a route you have never taken, and make it at least twice as long as it needs to be.",
            "difficulty": "medium",
            "points": 50,
            "status": "active",
            "steps_target": 4000,
            "distance_target_m": 3000,
            "steps_progress": 1180,
            "distance_progress_m": 890,
            "targets_met": false,
            // ISO 8601 with fractional-second tolerance — AdventureDates will not parse
            // the SQLite stamp format.
            "issued_at": DemoJSON.iso(DemoJSON.ago(hours: 3))
        ])
    }

    static func cosmetics() -> [CosmeticItem] {
        [
            ["id": 1, "key": "theme_blue", "kind": "accent", "price": 250, "owned": true],
            ["id": 2, "key": "theme_pink", "kind": "accent", "price": 400, "owned": false],
            ["id": 3, "key": "theme_dark_red", "kind": "accent", "price": 600, "owned": false]
        ].map { DemoJSON.make(CosmeticItem.self, $0) }
    }

    // MARK: - Assembly

    static func build() -> DemoStore.Snapshot {
        let everyone = people()
        let (convos, msgs) = conversations(everyone)
        return DemoStore.Snapshot(
            me: me(),
            people: everyone,
            posts: posts(everyone),
            postComments: postComments(everyone),
            followers: everyone.map(follow),
            following: everyone.map(follow),
            suggestions: suggestions(),
            blocked: [],
            conversations: convos,
            messages: msgs,
            notifications: notifications(),
            trips: trips(),
            entries: entries(),
            tripChat: tripChat(),
            tripTasks: tripTasks(),
            tripDates: tripDates(),
            experiences: experiences(),
            experienceComments: [:],
            organizations: organizations(),
            crashPads: crashPads(),
            myCrashPad: nil,
            crashPadIncoming: [],
            crashPadOutgoing: [],
            dailyAdventure: dailyAdventure(),
            pointsBalance: 275,
            cosmetics: cosmetics(),
            plan: nil
        )
    }
}
