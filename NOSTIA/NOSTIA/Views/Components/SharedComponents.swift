import SwiftUI
import UIKit

// MARK: - Profile Picture View (handles base64, remote URL, or fallback)

struct ProfilePictureView: View {
    let urlString: String?
    let initial: String
    let size: CGFloat

    var body: some View {
        Group {
            if let s = urlString, !s.isEmpty {
                if s.hasPrefix("data:image"),
                   let base64 = s.components(separatedBy: "base64,").last,
                   let data = Data(base64Encoded: base64, options: .ignoreUnknownCharacters),
                   let img = UIImage(data: data) {
                    Image(uiImage: img)
                        .resizable().scaledToFill()
                } else if let data = Data(base64Encoded: s, options: .ignoreUnknownCharacters),
                          let img = UIImage(data: data) {
                    Image(uiImage: img)
                        .resizable().scaledToFill()
                } else if s.hasPrefix("http"), let url = URL(string: s) {
                    AsyncImage(url: url) { phase in
                        if case .success(let img) = phase {
                            img.resizable().scaledToFill()
                        } else {
                            avatarFallback
                        }
                    }
                } else {
                    avatarFallback
                }
            } else {
                avatarFallback
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay(Circle().stroke(.white.opacity(0.4), lineWidth: 1.5))
    }

    private var avatarFallback: some View {
        AvatarView(initial: initial, color: Color.nostiaAccent, size: size)
    }
}

// MARK: - User Avatar View (shows profile picture or falls back to initials)

struct UserAvatarView: View {
    let imageData: String?
    let initial: String
    let color: Color
    let size: CGFloat

    private var uiImage: UIImage? {
        guard let str = imageData, !str.isEmpty,
              let data = Data(base64Encoded: str) else { return nil }
        return UIImage(data: data)
    }

    var body: some View {
        if let img = uiImage {
            Image(uiImage: img)
                .resizable()
                .scaledToFill()
                .frame(width: size, height: size)
                .clipShape(Circle())
                .overlay(Circle().stroke(.white.opacity(0.25), lineWidth: 1))
        } else {
            AvatarView(initial: initial, color: color, size: size)
        }
    }
}

// MARK: - Avatar View

struct AvatarView: View {
    let initial: String
    let color: Color
    let size: CGFloat

    var body: some View {
        Text(initial)
            .font(.system(size: size * 0.4, weight: .bold))
            .foregroundColor(.white)
            .frame(width: size, height: size)
            .background(color.opacity(0.85))
            .clipShape(Circle())
            .overlay(Circle().stroke(.white.opacity(0.25), lineWidth: 1))
            .shadow(color: color.opacity(0.45), radius: size * 0.18)
    }
}

// MARK: - Loading View

struct LoadingView: View {
    var body: some View {
        VStack {
            ProgressView().tint(Color.nostiaAccent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.clear)
    }
}

// MARK: - Empty State View

struct EmptyStateView: View {
    let icon: String
    let text: String
    let sub: String

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 56))
                .foregroundStyle(Color.nostiaAccent.opacity(0.7))
            Text(text).font(.title3.bold()).foregroundColor(.white)
            if !sub.isEmpty {
                Text(sub)
                    .font(.subheadline)
                    .foregroundColor(Color.nostiaTextSecond)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
        .padding(.horizontal, 32)
    }
}

// MARK: - Consent Sheet

struct ConsentSheet: View {
    let onConsent: (Bool, Bool) -> Void
    let onDecline: () -> Void

    @State private var locationConsent = true
    @State private var dataCollectionConsent = true
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Before you join Nostia, we need your consent to use certain features.")
                        .font(.subheadline).foregroundColor(Color.nostiaTextSecond)

                    ConsentToggle(
                        icon: "location.fill",
                        title: "Location Services",
                        description: "Nostia uses your location to show nearby events and share your position with friends. You can change this at any time.",
                        isOn: $locationConsent
                    )

                    ConsentToggle(
                        icon: "chart.bar.fill",
                        title: "Data Collection",
                        description: "We collect usage data to improve the app experience. All data is anonymized and never sold to third parties.",
                        isOn: $dataCollectionConsent
                    )

                    Text("By tapping \"I Agree\", you confirm you've read and accept our Privacy Policy.")
                        .font(.caption).foregroundColor(Color.nostiaTextMuted)
                        .padding(.top, 8)

                    VStack(spacing: 12) {
                        Button {
                            onConsent(locationConsent, dataCollectionConsent)
                        } label: {
                            HStack {
                                Image(systemName: "checkmark.shield.fill")
                                Text("I Agree")
                            }
                            .font(.headline).foregroundColor(.white)
                            .frame(maxWidth: .infinity).padding(16)
                            .background(
                                LinearGradient(colors: [Color.nostiaAccent, Color.nostriaPurple],
                                               startPoint: .leading, endPoint: .trailing)
                            )
                            .cornerRadius(14)
                        }

                        Button {
                            onDecline()
                        } label: {
                            Text("Decline")
                                .font(.headline).foregroundColor(Color.nostiaTextSecond)
                                .frame(maxWidth: .infinity).padding(16)
                                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
                        }
                    }
                }
                .padding(24)
            }
            .background(.clear)
            .navigationTitle("Privacy Consent")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
        }
        .presentationBackground(.ultraThinMaterial)
    }
}

struct ConsentToggle: View {
    let icon: String
    let title: String
    let description: String
    @Binding var isOn: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon).foregroundColor(Color.nostiaAccent)
                Text(title).font(.headline).foregroundColor(.white)
                Spacer()
                Toggle("", isOn: $isOn).tint(Color.nostiaAccent).labelsHidden()
            }
            Text(description).font(.footnote).foregroundColor(Color.nostiaTextSecond)
        }
        .padding(16)
        .glassEffect(in: RoundedRectangle(cornerRadius: 14))
    }
}

// MARK: - Date helpers (used by trip sheets)

func formatTripDate(_ raw: String) -> String {
    let digits = String(raw.filter { $0.isNumber }.prefix(8))
    switch digits.count {
    case 0...4: return digits
    case 5...6: return "\(digits.prefix(4))-\(digits.dropFirst(4))"
    default:
        return "\(digits.prefix(4))-\(digits.dropFirst(4).prefix(2))-\(digits.dropFirst(6))"
    }
}

func isValidTripDate(_ value: String) -> Bool {
    guard value.count == 10 else { return false }
    let parts = value.split(separator: "-")
    guard parts.count == 3,
          let y = Int(parts[0]), let m = Int(parts[1]), let d = Int(parts[2]) else { return false }
    var comps = DateComponents()
    comps.year = y; comps.month = m; comps.day = d
    return Calendar.current.date(from: comps).map {
        Calendar.current.component(.year, from: $0) == y &&
        Calendar.current.component(.month, from: $0) == m &&
        Calendar.current.component(.day, from: $0) == d
    } ?? false
}

// MARK: - Create Trip Sheet (2-step: details → invite friends)

struct CreateTripSheet: View {
    let onSave: (String, String?, [Int]) async -> Void

    @State private var step = 1
    @State private var title = ""
    @State private var description = ""
    @State private var followers: [FollowUser] = []
    @State private var selectedFriendIds: Set<Int> = []
    @State private var isLoadingFriends = false
    @State private var isSaving = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            if step == 1 {
                detailsStep
            } else {
                friendsStep
            }
        }
        .presentationBackground(.ultraThinMaterial)
    }

    private var detailsStep: some View {
        ScrollView {
            VStack(spacing: 16) {
                NostiaTextField(label: "Title *", placeholder: "Vault name", text: $title)
                VStack(alignment: .leading, spacing: 6) {
                    Text("Description")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white.opacity(0.7))
                    TextEditor(text: $description)
                        .frame(minHeight: 80).padding(12)
                        .glassEffect(in: RoundedRectangle(cornerRadius: 12))
                        .foregroundColor(.white).scrollContentBackground(.hidden)
                }
            }
            .padding(20)
        }
        .background(.clear)
        .navigationTitle("Create Vault")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Cancel") { dismiss() }.foregroundColor(Color.nostiaAccent)
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("Next") {
                    step = 2
                    Task { await loadFriends() }
                }
                .fontWeight(.semibold).foregroundColor(Color.nostiaAccent)
                .disabled(title.isEmpty)
            }
        }
    }

    private var friendsStep: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text("SELECT FOLLOWERS")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(Color.nostiaTextSecond)
                    .padding(.horizontal, 20).padding(.top, 20).padding(.bottom, 10)

                if isLoadingFriends {
                    ProgressView().tint(Color.nostiaAccent).frame(maxWidth: .infinity).padding(40)
                } else if followers.isEmpty {
                    Text("No followers to add yet")
                        .font(.footnote).foregroundColor(Color.nostiaTextSecond)
                        .padding(.horizontal, 20)
                } else {
                    ForEach(followers) { follower in
                        HStack(spacing: 12) {
                            AvatarView(initial: follower.initial, color: Color.nostiaAccent, size: 38)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(follower.name).font(.system(size: 14, weight: .semibold)).foregroundColor(.white)
                                Text("@\(follower.username)").font(.system(size: 12)).foregroundColor(Color.nostiaTextSecond)
                            }
                            Spacer()
                            Image(systemName: selectedFriendIds.contains(follower.id) ? "checkmark.circle.fill" : "circle")
                                .font(.title3)
                                .foregroundColor(selectedFriendIds.contains(follower.id) ? Color.nostiaAccent : Color.nostiaTextMuted)
                        }
                        .padding(14)
                        .glassEffect(in: RoundedRectangle(cornerRadius: 14))
                        .padding(.horizontal, 16).padding(.vertical, 4)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if selectedFriendIds.contains(follower.id) {
                                selectedFriendIds.remove(follower.id)
                            } else {
                                selectedFriendIds.insert(follower.id)
                            }
                        }
                    }
                }
                Spacer(minLength: 32)
            }
        }
        .background(.clear)
        .navigationTitle("Add Followers")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Back") { step = 1 }.foregroundColor(Color.nostiaAccent)
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    isSaving = true
                    Task {
                        await onSave(title, description.isEmpty ? nil : description, Array(selectedFriendIds))
                        isSaving = false
                    }
                } label: {
                    if isSaving { ProgressView().tint(Color.nostiaAccent) }
                    else { Text("Create").fontWeight(.semibold).foregroundColor(Color.nostiaAccent) }
                }
                .disabled(isSaving)
            }
        }
    }

    private func loadFriends() async {
        isLoadingFriends = true
        followers = (try? await FriendsAPI.shared.getFollowers()) ?? []
        isLoadingFriends = false
    }
}

// MARK: - Create Expense Sheet

struct CreateExpenseSheet: View {
    let tripId: Int
    var showCategory: Bool = true
    let onSave: (String, Double, String?, String) async -> Void

    @State private var description = ""
    @State private var amountText = ""
    @State private var category = ""
    @State private var dateValue = Date()
    @State private var isSaving = false
    @Environment(\.dismiss) private var dismiss

    let categories = ["Food", "Transport", "Accommodation", "Activities", "Shopping", "Other"]

    private let dateFmt: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; return f
    }()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    NostiaTextField(label: "Description *", placeholder: "What was this for?", text: $description)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Amount *")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white.opacity(0.7))
                        HStack {
                            Text("$").foregroundColor(Color.nostiaTextSecond).font(.title3)
                            TextField("0.00", text: $amountText).keyboardType(.decimalPad).foregroundColor(.white)
                        }
                        .padding(16)
                        .glassEffect(in: RoundedRectangle(cornerRadius: 12))
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Date *")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white.opacity(0.7))
                        DatePicker("", selection: $dateValue, displayedComponents: .date)
                            .datePickerStyle(.compact)
                            .labelsHidden()
                            .tint(Color.nostiaAccent)
                            .colorScheme(.dark)
                            .padding(12)
                            .glassEffect(in: RoundedRectangle(cornerRadius: 12))
                    }

                    if showCategory {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Category")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.white.opacity(0.7))
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(categories, id: \.self) { cat in
                                        FilterChip(title: cat, isActive: category == cat) { category = cat }
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(20)
            }
            .background(.clear)
            .navigationTitle("Add Expense")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }.foregroundColor(Color.nostiaAccent)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        guard let amount = Double(amountText), amount > 0, !description.isEmpty else { return }
                        isSaving = true
                        Task {
                            await onSave(description, amount, category.isEmpty ? nil : category, dateFmt.string(from: dateValue))
                            isSaving = false
                        }
                    } label: {
                        if isSaving { ProgressView().tint(Color.nostiaAccent) }
                        else { Text("Add").fontWeight(.semibold).foregroundColor(Color.nostiaAccent) }
                    }
                    .disabled(description.isEmpty || amountText.isEmpty || isSaving)
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    }
                    .foregroundColor(Color.nostiaAccent)
                }
            }
        }
        .presentationBackground(.ultraThinMaterial)
    }
}

// MARK: - Filter Chip (shared across Adventures and Vault)

struct FilterChip: View {
    let title: String; let isActive: Bool; let action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption.bold())
                .foregroundColor(isActive ? .white : Color.nostiaTextSecond)
                .padding(.horizontal, 12).padding(.vertical, 6)
                .background(.ultraThinMaterial, in: Capsule())
                .overlay(isActive ? Capsule().stroke(Color.nostiaAccent, lineWidth: 1) : nil)
        }
    }
}

// MARK: - Shimmer

private struct ShimmerModifier: ViewModifier {
    @State private var start = UnitPoint(x: -1, y: 0.5)
    @State private var end   = UnitPoint(x:  0, y: 0.5)

    func body(content: Content) -> some View {
        content
            .overlay(
                LinearGradient(
                    colors: [.clear, Color.white.opacity(0.35), .clear],
                    startPoint: start,
                    endPoint: end
                )
                .allowsHitTesting(false)
            )
            .onAppear {
                withAnimation(.linear(duration: 1.3).repeatForever(autoreverses: false)) {
                    start = UnitPoint(x: 1, y: 0.5)
                    end   = UnitPoint(x: 2, y: 0.5)
                }
            }
    }
}

extension View {
    func shimmer() -> some View { modifier(ShimmerModifier()) }
}

// MARK: - Skeleton Primitives

struct SkeletonBar: View {
    var width: CGFloat? = nil
    var height: CGFloat = 14

    var body: some View {
        RoundedRectangle(cornerRadius: height / 2)
            .fill(Color(uiColor: .systemGray5))
            .frame(width: width, height: height)
            .frame(maxWidth: width == nil ? .infinity : nil, alignment: .leading)
            .shimmer()
    }
}

struct SkeletonRect: View {
    var width: CGFloat? = nil
    var height: CGFloat
    var cornerRadius: CGFloat = 8

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(Color(uiColor: .systemGray5))
            .frame(width: width, height: height)
            .frame(maxWidth: width == nil ? .infinity : nil)
            .shimmer()
    }
}

struct SkeletonCircle: View {
    var size: CGFloat

    var body: some View {
        Circle()
            .fill(Color(uiColor: .systemGray5))
            .frame(width: size, height: size)
            .shimmer()
    }
}

// MARK: - Skeleton Composites

struct FeedPostCardSkeleton: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                SkeletonCircle(size: 36)
                VStack(alignment: .leading, spacing: 6) {
                    SkeletonBar(width: 140, height: 12)
                    SkeletonBar(width: 90, height: 10)
                }
                Spacer()
            }
            .padding(.horizontal, 14).padding(.top, 14).padding(.bottom, 10)

            SkeletonRect(height: 200, cornerRadius: 0)

            VStack(alignment: .leading, spacing: 8) {
                SkeletonBar(height: 12)
                SkeletonBar(width: 200, height: 12)
            }
            .padding(.horizontal, 14).padding(.vertical, 10)

            SkeletonBar(width: 110, height: 10)
                .padding(.horizontal, 14).padding(.bottom, 14)
        }
        .glassEffect(in: RoundedRectangle(cornerRadius: 18))
    }
}

struct FeedSkeletonView: View {
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(0..<4, id: \.self) { _ in
                    FeedPostCardSkeleton()
                }
            }
            .padding(16)
        }
        .disabled(true)
        .background(.clear)
    }
}

struct ProfileSkeletonView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                VStack(spacing: 12) {
                    SkeletonCircle(size: 80)
                    SkeletonBar(width: 160, height: 16)
                    SkeletonBar(width: 220, height: 12)
                    SkeletonBar(width: 100, height: 11)
                }
                .frame(maxWidth: .infinity)
                .padding(20)
                .glassEffect(in: RoundedRectangle(cornerRadius: 20))

                ForEach(0..<2, id: \.self) { _ in
                    FeedPostCardSkeleton()
                }
            }
            .padding(16)
        }
        .disabled(true)
        .background(.clear)
    }
}

struct NotificationSkeletonView: View {
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 10) {
                ForEach(0..<6, id: \.self) { i in
                    HStack(spacing: 12) {
                        SkeletonCircle(size: 40)
                        VStack(alignment: .leading, spacing: 6) {
                            SkeletonBar(width: i % 2 == 0 ? 200 : 160, height: 12)
                            SkeletonBar(width: i % 2 == 0 ? 140 : 180, height: 11)
                        }
                        Spacer()
                    }
                    .padding(14)
                    .glassEffect(in: RoundedRectangle(cornerRadius: 14))
                }
            }
            .padding(16)
        }
        .disabled(true)
        .background(.clear)
    }
}

struct FollowSkeletonView: View {
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 10) {
                ForEach(0..<6, id: \.self) { i in
                    HStack(spacing: 12) {
                        SkeletonCircle(size: 40)
                        SkeletonBar(width: i % 3 == 0 ? 140 : 110, height: 13)
                        Spacer()
                        SkeletonBar(width: 70, height: 28)
                    }
                    .padding(14)
                    .glassEffect(in: RoundedRectangle(cornerRadius: 14))
                }
            }
            .padding(16)
        }
        .disabled(true)
        .background(.clear)
    }
}

struct SearchSkeletonView: View {
    var body: some View {
        LazyVStack(spacing: 10) {
            ForEach(0..<5, id: \.self) { i in
                HStack(spacing: 12) {
                    SkeletonCircle(size: 40)
                    SkeletonBar(width: i % 2 == 0 ? 150 : 120, height: 13)
                    Spacer()
                }
                .padding(14)
                .glassEffect(in: RoundedRectangle(cornerRadius: 14))
            }
        }
        .padding(.horizontal, 16)
        .disabled(true)
    }
}

struct VaultListSkeletonView: View {
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(0..<4, id: \.self) { i in
                    VStack(alignment: .leading, spacing: 8) {
                        SkeletonBar(height: 15)
                        SkeletonBar(width: i % 2 == 0 ? 130 : 100, height: 12)
                    }
                    .padding(18)
                    .glassEffect(in: RoundedRectangle(cornerRadius: 16))
                }
            }
            .padding(16)
        }
        .disabled(true)
        .background(.clear)
    }
}

struct VaultDetailSkeletonView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SkeletonBar(height: 16)
            SkeletonBar(width: 180, height: 13)

            ForEach(0..<4, id: \.self) { i in
                HStack(spacing: 10) {
                    if i % 2 == 0 { Spacer() }
                    SkeletonCircle(size: 32)
                    SkeletonBar(width: 150, height: 12)
                    if i % 2 != 0 { Spacer() }
                }
                .padding(12)
                .glassEffect(in: RoundedRectangle(cornerRadius: 14))
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .disabled(true)
        .background(.clear)
    }
}

struct VaultExpenseSkeletonView: View {
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 10) {
                ForEach(0..<4, id: \.self) { i in
                    HStack(spacing: 12) {
                        SkeletonBar(width: i % 2 == 0 ? 160 : 130, height: 13)
                        Spacer()
                        SkeletonBar(width: 60, height: 13)
                    }
                    .padding(14)
                    .glassEffect(in: RoundedRectangle(cornerRadius: 14))
                }
            }
            .padding(16)
        }
        .disabled(true)
        .background(.clear)
    }
}

struct EventListSkeletonView: View {
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(0..<4, id: \.self) { i in
                    HStack(spacing: 12) {
                        SkeletonRect(width: 60, height: 60, cornerRadius: 10)
                        VStack(alignment: .leading, spacing: 8) {
                            SkeletonBar(height: 14)
                            SkeletonBar(width: i % 2 == 0 ? 140 : 110, height: 11)
                        }
                        Spacer()
                    }
                    .padding(14)
                    .glassEffect(in: RoundedRectangle(cornerRadius: 16))
                }
            }
            .padding(16)
        }
        .disabled(true)
        .background(.clear)
    }
}

struct CommentSkeletonView: View {
    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 12) {
                ForEach(0..<4, id: \.self) { i in
                    HStack(alignment: .top, spacing: 10) {
                        SkeletonCircle(size: 34)
                        VStack(alignment: .leading, spacing: 6) {
                            SkeletonBar(width: i % 2 == 0 ? 100 : 130, height: 11)
                            SkeletonBar(width: i % 2 == 0 ? 200 : 170, height: 12)
                        }
                        Spacer()
                    }
                    .padding(12)
                    .glassEffect(in: RoundedRectangle(cornerRadius: 14))
                }
            }
            .padding(16)
        }
        .disabled(true)
        .background(.clear)
    }
}
