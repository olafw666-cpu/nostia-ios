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
    @EnvironmentObject var responsive: ResponsiveLayoutManager

    var body: some View {
        VStack(spacing: responsive.spacing(16)) {
            Image(systemName: icon)
                .font(.system(size: responsive.fontSize(56)))
                .foregroundStyle(Color.nostiaAccent.opacity(0.7))
            Text(text).font(.title3.bold()).foregroundColor(Color.nostiaTextPrimary)
            if !sub.isEmpty {
                Text(sub)
                    .font(.subheadline)
                    .foregroundColor(Color.nostiaTextSecond)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, responsive.spacing(60))
        .padding(.horizontal, responsive.spacing(32))
    }
}

// MARK: - Consent Sheet

struct ConsentSheet: View {
    let onContinue: () -> Void

    @EnvironmentObject var responsive: ResponsiveLayoutManager

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: responsive.spacing(20)) {
                    Text("Here's how Nostia uses your information to power the app.")
                        .font(.subheadline).foregroundColor(Color.nostiaTextSecond)

                    ConsentInfoRow(
                        icon: "location.fill",
                        title: "Location Services",
                        description: "Nostia uses your location to show nearby experiences and share your position with friends. You'll be asked for permission, and you can change it anytime in Settings."
                    )

                    ConsentInfoRow(
                        icon: "chart.bar.fill",
                        title: "Data Collection",
                        description: "We collect usage data to improve the app experience. All data is anonymized."
                    )

                    Text("By tapping \"Continue\", you confirm you've read and accept our Privacy Policy.")
                        .font(.caption).foregroundColor(Color.nostiaTextMuted)
                        .padding(.top, responsive.spacing(8))

                    Button {
                        onContinue()
                    } label: {
                        Text("Continue")
                            .font(.headline).foregroundColor(.white)
                            .frame(maxWidth: .infinity).padding(responsive.spacing(16))
                            .background(
                                LinearGradient(colors: [Color.nostiaAccent, Color.nostriaPurple],
                                               startPoint: .leading, endPoint: .trailing)
                            )
                            .cornerRadius(14)
                    }
                }
                .padding(responsive.spacing(24))
                .frame(maxWidth: responsive.sheetMaxWidth)
                .frame(maxWidth: .infinity)
            }
            .background(.clear)
            .navigationTitle("Privacy")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .interactiveDismissDisabled()
        }
        .presentationBackground(Color.nostiaBackground)
    }
}

struct ConsentInfoRow: View {
    let icon: String
    let title: String
    let description: String
    @EnvironmentObject var responsive: ResponsiveLayoutManager

    var body: some View {
        VStack(alignment: .leading, spacing: responsive.spacing(12)) {
            HStack {
                Image(systemName: icon).foregroundColor(Color.nostiaAccent)
                Text(title).font(.headline).foregroundColor(Color.nostiaTextPrimary)
                Spacer()
            }
            Text(description).font(.footnote).foregroundColor(Color.nostiaTextSecond)
        }
        .padding(responsive.spacing(16))
        .nostiaCard(in: RoundedRectangle(cornerRadius: 14))
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
    @EnvironmentObject var responsive: ResponsiveLayoutManager

    var body: some View {
        NavigationStack {
            if step == 1 {
                detailsStep
            } else {
                friendsStep
            }
        }
        .presentationBackground(Color.nostiaBackground)
    }

    private var detailsStep: some View {
        ScrollView {
            VStack(spacing: responsive.spacing(16)) {
                NostiaTextField(label: "Title *", placeholder: "Vault name", text: $title)
                VStack(alignment: .leading, spacing: 6) {
                    Text("Description")
                        .font(.system(size: responsive.fontSize(14), weight: .semibold))
                        .foregroundColor(Color.nostiaTextSecond)
                    TextEditor(text: $description)
                        .frame(minHeight: responsive.spacing(80)).padding(responsive.spacing(12))
                        .nostiaCard(in: RoundedRectangle(cornerRadius: 12))
                        .foregroundColor(Color.nostiaTextPrimary).scrollContentBackground(.hidden)
                }
            }
            .padding(responsive.spacing(20))
            .frame(maxWidth: responsive.sheetMaxWidth)
            .frame(maxWidth: .infinity)
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
                    .font(.system(size: responsive.fontSize(11), weight: .semibold))
                    .foregroundColor(Color.nostiaTextSecond)
                    .padding(.horizontal, responsive.spacing(20)).padding(.top, responsive.spacing(20)).padding(.bottom, responsive.spacing(10))

                if isLoadingFriends {
                    ProgressView().tint(Color.nostiaAccent).frame(maxWidth: .infinity).padding(40)
                } else if followers.isEmpty {
                    Text("No followers to add yet")
                        .font(.footnote).foregroundColor(Color.nostiaTextSecond)
                        .padding(.horizontal, responsive.spacing(20))
                } else {
                    ForEach(followers) { follower in
                        HStack(spacing: responsive.spacing(12)) {
                            AvatarView(initial: follower.initial, color: Color.nostiaAccent, size: responsive.spacing(38))
                            VStack(alignment: .leading, spacing: 2) {
                                Text(follower.name).font(.system(size: responsive.fontSize(14), weight: .semibold)).foregroundColor(Color.nostiaTextPrimary)
                                Text("@\(follower.username)").font(.system(size: responsive.fontSize(12))).foregroundColor(Color.nostiaTextSecond)
                            }
                            Spacer()
                            Image(systemName: selectedFriendIds.contains(follower.id) ? "checkmark.circle.fill" : "circle")
                                .font(.title3)
                                .foregroundColor(selectedFriendIds.contains(follower.id) ? Color.nostiaAccent : Color.nostiaTextMuted)
                        }
                        .padding(responsive.spacing(14))
                        .nostiaCard(in: RoundedRectangle(cornerRadius: 14))
                        .padding(.horizontal, responsive.spacing(16)).padding(.vertical, 4)
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
                Spacer(minLength: responsive.spacing(32))
            }
            .frame(maxWidth: responsive.sheetMaxWidth)
            .frame(maxWidth: .infinity)
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
    let members: [TripParticipant]
    var showCategory: Bool = true
    let onSave: (String, Double, String?, String, [ExpenseSplitInput]) async -> Void

    @State private var description = ""
    @State private var amountText = ""
    @State private var category = ""
    @State private var dateValue = Date()
    @State private var isSaving = false

    // Split state
    @State private var selectedMemberIds: Set<Int> = []
    @State private var memberAmounts: [Int: String] = [:]
    @State private var isCustomMode = false

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var responsive: ResponsiveLayoutManager

    private let currentUserId = AuthManager.shared.currentUserId
    private let categories = ["Food", "Transport", "Accommodation", "Activities", "Shopping", "Other"]
    private let dateFmt: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; return f
    }()

    private var activeMembers: [TripParticipant] { members.filter { !$0.isKicked } }
    private var expenseAmount: Double { Double(amountText) ?? 0 }
    private var assignedTotal: Double {
        selectedMemberIds.reduce(0.0) { sum, uid in sum + (Double(memberAmounts[uid] ?? "") ?? 0) }
    }
    private var totalMatchesExpense: Bool {
        expenseAmount > 0 && abs(assignedTotal - expenseAmount) < 0.005
    }
    private var allMembersSelected: Bool {
        !activeMembers.isEmpty && selectedMemberIds.count == activeMembers.count
    }
    private var splitIsValid: Bool {
        guard expenseAmount > 0, selectedMemberIds.count >= 1 else { return false }
        let hasZeroOrInvalid = selectedMemberIds.contains { (Double(memberAmounts[$0] ?? "") ?? 0) <= 0 }
        return !hasZeroOrInvalid && totalMatchesExpense
    }
    private var saveDisabled: Bool { description.isEmpty || expenseAmount <= 0 || !splitIsValid || isSaving }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: responsive.spacing(16)) {
                    NostiaTextField(label: "Description *", placeholder: "What was this for?", text: $description)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Amount *")
                            .font(.system(size: responsive.fontSize(14), weight: .semibold))
                            .foregroundColor(Color.nostiaTextSecond)
                        HStack {
                            Text("$").foregroundColor(Color.nostiaTextSecond).font(.title3)
                            TextField("0.00", text: $amountText).keyboardType(.decimalPad).foregroundColor(Color.nostiaTextPrimary)
                        }
                        .padding(responsive.spacing(16))
                        .nostiaCard(in: RoundedRectangle(cornerRadius: 12))
                    }
                    .onChange(of: amountText) { _ in
                        if !isCustomMode { recomputeEvenSplit() }
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Date *")
                            .font(.system(size: responsive.fontSize(14), weight: .semibold))
                            .foregroundColor(Color.nostiaTextSecond)
                        DatePicker("", selection: $dateValue, displayedComponents: .date)
                            .datePickerStyle(.compact)
                            .labelsHidden()
                            .tint(Color.nostiaAccent)
                            .colorScheme(.light)
                            .padding(responsive.spacing(12))
                            .nostiaCard(in: RoundedRectangle(cornerRadius: 12))
                    }

                    if showCategory {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Category")
                                .font(.system(size: responsive.fontSize(14), weight: .semibold))
                                .foregroundColor(Color.nostiaTextSecond)
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(categories, id: \.self) { cat in
                                        FilterChip(title: cat, isActive: category == cat) { category = cat }
                                    }
                                }
                            }
                        }
                    }

                    splitBetweenSection
                }
                .padding(responsive.spacing(20))
                .frame(maxWidth: responsive.sheetMaxWidth)
                .frame(maxWidth: .infinity)
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
                        guard !saveDisabled else { return }
                        isSaving = true
                        let splits = buildSplits()
                        Task {
                            await onSave(description, expenseAmount, category.isEmpty ? nil : category, dateFmt.string(from: dateValue), splits)
                            isSaving = false
                        }
                    } label: {
                        if isSaving { ProgressView().tint(Color.nostiaAccent) }
                        else { Text("Add").fontWeight(.semibold).foregroundColor(saveDisabled ? Color.nostiaTextMuted : Color.nostiaAccent) }
                    }
                    .disabled(saveDisabled)
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
        .presentationBackground(Color.nostiaBackground)
        .onAppear { initializeSplit() }
    }

    // MARK: - Split Between Section

    private var splitBetweenSection: some View {
        VStack(alignment: .leading, spacing: responsive.spacing(10)) {
            HStack {
                Text("Split Between")
                    .font(.system(size: responsive.fontSize(14), weight: .semibold))
                    .foregroundColor(Color.nostiaTextSecond)
                Spacer()
                if isCustomMode {
                    Button("Split Evenly") {
                        isCustomMode = false
                        recomputeEvenSplit()
                    }
                    .font(.caption.bold())
                    .foregroundColor(Color.nostiaAccent)
                }
            }

            // Everyone master toggle
            Button { toggleEveryone() } label: {
                HStack(spacing: 10) {
                    AvatarView(initial: "A", color: Color.nostriaPurple, size: responsive.spacing(36))
                    Text("Everyone").font(.subheadline.bold()).foregroundColor(Color.nostiaTextPrimary)
                    Spacer()
                    Image(systemName: allMembersSelected ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(allMembersSelected ? Color.nostiaAccent : Color.nostiaTextMuted)
                        .font(.title3)
                }
                .padding(responsive.spacing(12))
                .nostiaCard(in: RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)

            ForEach(activeMembers) { member in
                memberSplitRow(for: member)
            }

            if selectedMemberIds.count < 1 {
                Text("At least 1 member must be included in the split.")
                    .font(.caption)
                    .foregroundColor(Color.nostriaDanger)
                    .padding(.leading, 4)
            }

            if expenseAmount > 0 {
                HStack {
                    Text("Total assigned:").font(.caption).foregroundColor(Color.nostiaTextSecond)
                    Spacer()
                    // Non-color cue (icon) so the match/mismatch isn't color-only (Section 1.2).
                    HStack(spacing: 4) {
                        Image(systemName: totalMatchesExpense ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                            .font(.caption2)
                        Text(String(format: "$%.2f of $%.2f", assignedTotal, expenseAmount))
                            .font(.caption.bold())
                    }
                    .foregroundColor(totalMatchesExpense ? Color.nostiaSuccess : Color.nostriaDanger)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(
                        totalMatchesExpense
                        ? "Total assigned matches the expense, \(String(format: "$%.2f", assignedTotal))"
                        : "Total assigned does not match. \(String(format: "$%.2f assigned of $%.2f", assignedTotal, expenseAmount))"
                    )
                }
                .padding(.horizontal, 4)
            }
        }
    }

    @ViewBuilder
    private func memberSplitRow(for member: TripParticipant) -> some View {
        let isSelected = selectedMemberIds.contains(member.id)
        let isMe = member.id == currentUserId
        let displayName = member.username.map { "@\($0)" } ?? member.name ?? "User \(member.id)"
        let amountVal = Double(memberAmounts[member.id] ?? "") ?? 0
        let hasZeroError = isSelected && amountVal <= 0 && expenseAmount > 0

        VStack(alignment: .leading, spacing: 2) {
            Button { toggleMember(member) } label: {
                HStack(spacing: 10) {
                    AvatarView(
                        initial: String((member.name ?? "U").prefix(1)).uppercased(),
                        color: Color.nostiaAccent,
                        size: responsive.spacing(36)
                    )
                    HStack(spacing: 4) {
                        Text(displayName).font(.subheadline).foregroundColor(Color.nostiaTextPrimary)
                        if isMe {
                            Text("(you)").font(.caption).foregroundColor(Color.nostiaTextMuted)
                        }
                    }
                    Spacer()
                    TextField("0.00", text: Binding(
                        get: { memberAmounts[member.id] ?? "0.00" },
                        set: { val in
                            memberAmounts[member.id] = val
                            isCustomMode = true
                        }
                    ))
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .font(.subheadline.bold())
                    .foregroundColor(isSelected ? .white : Color.nostiaTextMuted)
                    .frame(width: 72)
                    .disabled(!isSelected)

                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(isSelected ? Color.nostiaAccent : Color.nostiaTextMuted)
                        .font(.title3)
                }
                .padding(responsive.spacing(12))
                .nostiaCard(in: RoundedRectangle(cornerRadius: 12))
                .opacity(isSelected ? 1.0 : 0.6)
            }
            .buttonStyle(.plain)

            if hasZeroError {
                Text("Amount must be greater than $0.")
                    .font(.caption2)
                    .foregroundColor(Color.nostriaDanger)
                    .padding(.leading, responsive.spacing(50))
            }
        }
    }

    // MARK: - Split Logic

    private func initializeSplit() {
        selectedMemberIds = Set(activeMembers.map { $0.id })
        for member in activeMembers { memberAmounts[member.id] = "0.00" }
        recomputeEvenSplit()
    }

    private func recomputeEvenSplit() {
        let selected = activeMembers.filter { selectedMemberIds.contains($0.id) }
        guard !selected.isEmpty, expenseAmount > 0 else { return }
        let totalCents = Int(round(expenseAmount * 100))
        let base = totalCents / selected.count
        let remainder = totalCents % selected.count
        for (i, member) in selected.enumerated() {
            let cents = base + (i < remainder ? 1 : 0)
            memberAmounts[member.id] = String(format: "%.2f", Double(cents) / 100.0)
        }
    }

    private func toggleEveryone() {
        if allMembersSelected {
            selectedMemberIds.removeAll()
        } else {
            selectedMemberIds = Set(activeMembers.map { $0.id })
            if !isCustomMode { recomputeEvenSplit() }
        }
    }

    private func toggleMember(_ member: TripParticipant) {
        if selectedMemberIds.contains(member.id) {
            selectedMemberIds.remove(member.id)
        } else {
            selectedMemberIds.insert(member.id)
        }
        if !isCustomMode { recomputeEvenSplit() }
    }

    private func buildSplits() -> [ExpenseSplitInput] {
        activeMembers
            .filter { selectedMemberIds.contains($0.id) }
            .compactMap { member in
                guard let amt = Double(memberAmounts[member.id] ?? ""), amt > 0 else { return nil }
                return ExpenseSplitInput(userId: member.id, amount: amt)
            }
    }
}

// MARK: - Filter Chip (shared across Adventures and Vault)

struct FilterChip: View {
    let title: String; let isActive: Bool; let action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption.bold())
                .foregroundColor(isActive ? .white : Color(hex: "4B5563"))
                .padding(.horizontal, 14).padding(.vertical, 8)
                .frame(minHeight: 32)
                .background(Capsule().fill(isActive ? Color.nostiaAccent : Color.white))
                .overlay(isActive ? nil : Capsule().stroke(Color.nostriaBorder, lineWidth: 1))
                .shadow(color: Color.nostiaShadow.opacity(0.06), radius: 6, x: 0, y: 1)
        }
        // State conveyed to VoiceOver, not by color alone (Section 1.2 / 1.4).
        .accessibilityLabel("\(title) filter")
        .accessibilityValue(isActive ? "On" : "Off")
        .accessibilityAddTraits(isActive ? [.isButton, .isSelected] : .isButton)
    }
}

// MARK: - Shimmer

private struct ShimmerModifier: ViewModifier {
    @State private var start = UnitPoint(x: -1, y: 0.5)
    @State private var end   = UnitPoint(x:  0, y: 0.5)
    // Respect the iOS Reduce Motion setting (Section 1.2 "Reduce Motion").
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .overlay(
                Group {
                    if !reduceMotion {
                        LinearGradient(
                            colors: [.clear, Color.white.opacity(0.35), .clear],
                            startPoint: start,
                            endPoint: end
                        )
                        .allowsHitTesting(false)
                    }
                }
            )
            .onAppear {
                guard !reduceMotion else { return }
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

// Skeleton placeholders are decorative — VoiceOver should announce "Loading" at the
// container level, not read the placeholder shapes (Section 1.2 "State announcements").
struct SkeletonBar: View {
    var width: CGFloat? = nil
    var height: CGFloat = 14

    var body: some View {
        RoundedRectangle(cornerRadius: height / 2)
            .fill(Color(uiColor: .systemGray5))
            .frame(width: width, height: height)
            .frame(maxWidth: width == nil ? .infinity : nil, alignment: .leading)
            .shimmer()
            .accessibilityHidden(true)
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
            .accessibilityHidden(true)
    }
}

struct SkeletonCircle: View {
    var size: CGFloat

    var body: some View {
        Circle()
            .fill(Color(uiColor: .systemGray5))
            .frame(width: size, height: size)
            .shimmer()
            .accessibilityHidden(true)
    }
}

// MARK: - Skeleton Composites

struct FeedPostCardSkeleton: View {
    private var r: ResponsiveLayoutManager { ResponsiveLayoutManager.shared }
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
            .padding(.horizontal, r.spacing(14)).padding(.top, r.spacing(14)).padding(.bottom, r.spacing(10))

            SkeletonRect(height: 200, cornerRadius: 0)

            VStack(alignment: .leading, spacing: 8) {
                SkeletonBar(height: 12)
                SkeletonBar(width: 200, height: 12)
            }
            .padding(.horizontal, r.spacing(14)).padding(.vertical, r.spacing(10))

            SkeletonBar(width: 110, height: 10)
                .padding(.horizontal, r.spacing(14)).padding(.bottom, r.spacing(14))
        }
        .nostiaCard(in: RoundedRectangle(cornerRadius: 18))
    }
}

struct FeedSkeletonView: View {
    private var r: ResponsiveLayoutManager { ResponsiveLayoutManager.shared }
    var body: some View {
        ScrollView {
            LazyVStack(spacing: r.spacing(12)) {
                ForEach(0..<4, id: \.self) { _ in
                    FeedPostCardSkeleton()
                }
            }
            .padding(r.spacing(16))
        }
        .disabled(true)
        .background(.clear)
    }
}

struct ProfileSkeletonView: View {
    private var r: ResponsiveLayoutManager { ResponsiveLayoutManager.shared }
    var body: some View {
        ScrollView {
            VStack(spacing: r.spacing(16)) {
                VStack(spacing: r.spacing(12)) {
                    SkeletonCircle(size: 80)
                    SkeletonBar(width: 160, height: 16)
                    SkeletonBar(width: 220, height: 12)
                    SkeletonBar(width: 100, height: 11)
                }
                .frame(maxWidth: .infinity)
                .padding(r.spacing(20))
                .nostiaCard(in: RoundedRectangle(cornerRadius: 20))

                ForEach(0..<2, id: \.self) { _ in
                    FeedPostCardSkeleton()
                }
            }
            .padding(r.spacing(16))
        }
        .disabled(true)
        .background(.clear)
    }
}

struct NotificationSkeletonView: View {
    private var r: ResponsiveLayoutManager { ResponsiveLayoutManager.shared }
    var body: some View {
        ScrollView {
            LazyVStack(spacing: r.spacing(10)) {
                ForEach(0..<6, id: \.self) { i in
                    HStack(spacing: 12) {
                        SkeletonCircle(size: 40)
                        VStack(alignment: .leading, spacing: 6) {
                            SkeletonBar(width: i % 2 == 0 ? 200 : 160, height: 12)
                            SkeletonBar(width: i % 2 == 0 ? 140 : 180, height: 11)
                        }
                        Spacer()
                    }
                    .padding(r.spacing(14))
                    .nostiaCard(in: RoundedRectangle(cornerRadius: 14))
                }
            }
            .padding(r.spacing(16))
        }
        .disabled(true)
        .background(.clear)
    }
}

struct FollowSkeletonView: View {
    private var r: ResponsiveLayoutManager { ResponsiveLayoutManager.shared }
    var body: some View {
        ScrollView {
            LazyVStack(spacing: r.spacing(10)) {
                ForEach(0..<6, id: \.self) { i in
                    HStack(spacing: 12) {
                        SkeletonCircle(size: 40)
                        SkeletonBar(width: i % 3 == 0 ? 140 : 110, height: 13)
                        Spacer()
                        SkeletonBar(width: 70, height: 28)
                    }
                    .padding(r.spacing(14))
                    .nostiaCard(in: RoundedRectangle(cornerRadius: 14))
                }
            }
            .padding(r.spacing(16))
        }
        .disabled(true)
        .background(.clear)
    }
}

struct SearchSkeletonView: View {
    private var r: ResponsiveLayoutManager { ResponsiveLayoutManager.shared }
    var body: some View {
        LazyVStack(spacing: r.spacing(10)) {
            ForEach(0..<5, id: \.self) { i in
                HStack(spacing: 12) {
                    SkeletonCircle(size: 40)
                    SkeletonBar(width: i % 2 == 0 ? 150 : 120, height: 13)
                    Spacer()
                }
                .padding(r.spacing(14))
                .nostiaCard(in: RoundedRectangle(cornerRadius: 14))
            }
        }
        .padding(.horizontal, r.spacing(16))
        .disabled(true)
    }
}

struct VaultListSkeletonView: View {
    private var r: ResponsiveLayoutManager { ResponsiveLayoutManager.shared }
    var body: some View {
        ScrollView {
            LazyVStack(spacing: r.spacing(12)) {
                ForEach(0..<4, id: \.self) { i in
                    VStack(alignment: .leading, spacing: 8) {
                        SkeletonBar(height: 15)
                        SkeletonBar(width: i % 2 == 0 ? 130 : 100, height: 12)
                    }
                    .padding(r.spacing(18))
                    .nostiaCard(in: RoundedRectangle(cornerRadius: 16))
                }
            }
            .padding(r.spacing(16))
        }
        .disabled(true)
        .background(.clear)
    }
}

struct VaultDetailSkeletonView: View {
    private var r: ResponsiveLayoutManager { ResponsiveLayoutManager.shared }
    var body: some View {
        VStack(alignment: .leading, spacing: r.spacing(12)) {
            SkeletonBar(height: 16)
            SkeletonBar(width: 180, height: 13)

            ForEach(0..<4, id: \.self) { i in
                HStack(spacing: 10) {
                    if i % 2 == 0 { Spacer() }
                    SkeletonCircle(size: 32)
                    SkeletonBar(width: 150, height: 12)
                    if i % 2 != 0 { Spacer() }
                }
                .padding(r.spacing(12))
                .nostiaCard(in: RoundedRectangle(cornerRadius: 14))
            }
        }
        .padding(r.spacing(16))
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .disabled(true)
        .background(.clear)
    }
}

struct VaultExpenseSkeletonView: View {
    private var r: ResponsiveLayoutManager { ResponsiveLayoutManager.shared }
    var body: some View {
        ScrollView {
            LazyVStack(spacing: r.spacing(10)) {
                ForEach(0..<4, id: \.self) { i in
                    HStack(spacing: 12) {
                        SkeletonBar(width: i % 2 == 0 ? 160 : 130, height: 13)
                        Spacer()
                        SkeletonBar(width: 60, height: 13)
                    }
                    .padding(r.spacing(14))
                    .nostiaCard(in: RoundedRectangle(cornerRadius: 14))
                }
            }
            .padding(r.spacing(16))
        }
        .disabled(true)
        .background(.clear)
    }
}

struct ExperienceListSkeletonView: View {
    private var r: ResponsiveLayoutManager { ResponsiveLayoutManager.shared }
    var body: some View {
        ScrollView {
            LazyVStack(spacing: r.spacing(12)) {
                ForEach(0..<4, id: \.self) { i in
                    HStack(spacing: 12) {
                        SkeletonRect(width: 60, height: 60, cornerRadius: 10)
                        VStack(alignment: .leading, spacing: 8) {
                            SkeletonBar(height: 14)
                            SkeletonBar(width: i % 2 == 0 ? 140 : 110, height: 11)
                        }
                        Spacer()
                    }
                    .padding(r.spacing(14))
                    .nostiaCard(in: RoundedRectangle(cornerRadius: 16))
                }
            }
            .padding(r.spacing(16))
        }
        .disabled(true)
        .background(.clear)
    }
}

struct CommentSkeletonView: View {
    private var r: ResponsiveLayoutManager { ResponsiveLayoutManager.shared }
    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: r.spacing(12)) {
                ForEach(0..<4, id: \.self) { i in
                    HStack(alignment: .top, spacing: 10) {
                        SkeletonCircle(size: 34)
                        VStack(alignment: .leading, spacing: 6) {
                            SkeletonBar(width: i % 2 == 0 ? 100 : 130, height: 11)
                            SkeletonBar(width: i % 2 == 0 ? 200 : 170, height: 12)
                        }
                        Spacer()
                    }
                    .padding(r.spacing(12))
                    .nostiaCard(in: RoundedRectangle(cornerRadius: 14))
                }
            }
            .padding(r.spacing(16))
        }
        .disabled(true)
        .background(.clear)
    }
}

// MARK: - FlowLayout

/// Left-to-right wrapping layout. Used for tag chip rows on experience cards/detail
/// sheets and the multi-select tag picker. Wraps to a new line when the next subview
/// would overflow the proposed width.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var rowWidth: CGFloat = 0
        var rowHeight: CGFloat = 0
        var totalWidth: CGFloat = 0
        var totalHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if rowWidth > 0, rowWidth + spacing + size.width > maxWidth {
                totalWidth = max(totalWidth, rowWidth)
                totalHeight += rowHeight + spacing
                rowWidth = size.width
                rowHeight = size.height
            } else {
                rowWidth += (rowWidth > 0 ? spacing : 0) + size.width
                rowHeight = max(rowHeight, size.height)
            }
        }
        totalWidth = max(totalWidth, rowWidth)
        totalHeight += rowHeight
        return CGSize(width: min(totalWidth, maxWidth), height: totalHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > bounds.minX, x + size.width > bounds.maxX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), anchor: .topLeading, proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
