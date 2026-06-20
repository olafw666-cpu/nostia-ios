import SwiftUI
import StripePaymentSheet

// VaultContentView: embeddable vault expense view (no own navigation)
struct VaultContentView: View {
    let tripId: Int
    var isKicked: Bool = false
    var participants: [TripParticipant] = []

    @StateObject private var vm = VaultViewModel()
    @State private var showAddExpense = false
    @State private var confirmPaySplitId: Int?
    @State private var paymentSuccessMessage: String?
    @State private var showPayTotal = false
    @State private var reminderTargetId: Int?
    @State private var reminderTargetUsername: String?
    @State private var reminderTargetBalance: Double = 0

    private var currentUserId: Int? { AuthManager.shared.currentUserId }
    @EnvironmentObject var responsive: ResponsiveLayoutManager

    var body: some View {
        ScrollView {
            LazyVStack(spacing: responsive.spacing(16)) {
                if vm.isLoading && vm.vaultData == nil {
                    VaultExpenseSkeletonView()
                } else if let data = vm.vaultData {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Total Expenses").font(.footnote).foregroundColor(Color.nostiaTextSecond)
                            Text(String(format: "$%.2f", data.totalAmount ?? 0))
                                .font(.system(size: responsive.fontSize(34), weight: .bold)).foregroundColor(.white)
                        }
                        Spacer()
                        if !isKicked {
                            Button { Haptics.impact(.medium); showAddExpense = true } label: {
                                Label("Add Expense", systemImage: "plus")
                                    .font(.subheadline.bold()).foregroundColor(.white)
                                    .padding(.horizontal, responsive.spacing(16)).padding(.vertical, responsive.spacing(10))
                                    .background(Color.nostiaAccent).cornerRadius(12)
                                    .shadow(color: Color.nostiaAccent.opacity(0.4), radius: 8)
                            }
                        }
                    }
                    .padding(responsive.spacing(16))
                    .glassEffect(in: RoundedRectangle(cornerRadius: 18))

                    if isKicked {
                        HStack(spacing: 6) {
                            Image(systemName: "eye").foregroundColor(Color.nostiaTextMuted).font(.caption)
                            Text("You're in read-only mode — settle your balance to leave")
                                .font(.caption).foregroundColor(Color.nostiaTextMuted)
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity)
                        .glassEffect(in: RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.nostiaTextMuted.opacity(0.3), lineWidth: 1))
                    }

                    let nonZeroBalances = data.balances.filter { abs($0.balance) > 0.005 }
                    if !nonZeroBalances.isEmpty {
                        Text("Balances").font(.headline).foregroundColor(.white)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        ForEach(nonZeroBalances) { bal in
                            BalanceRow(
                                balance: bal,
                                isOwnRow: bal.id == currentUserId,
                                onTapOwn: { showPayTotal = true },
                                onTapOther: {
                                    guard canSendReminder(to: bal.id, in: data),
                                          bal.balance < 0 else { return }
                                    reminderTargetId = bal.id
                                    reminderTargetUsername = bal.username ?? bal.name
                                    reminderTargetBalance = abs(bal.balance)
                                }
                            )
                        }
                    }

                    if !data.entries.isEmpty {
                        Text("Expenses").font(.headline).foregroundColor(.white)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        ForEach(data.entries) { entry in
                            ExpenseCard(
                                entry: entry,
                                currentUserId: currentUserId,
                                vaultLeaderId: data.vaultLeaderId,
                                vaultLeaderHasStripe: data.vaultLeaderHasStripe ?? false,
                                onDelete: { Task { await vm.deleteEntry(entry.id, tripId: tripId) } },
                                onMarkPaid: { splitId in confirmPaySplitId = splitId },
                                onPayWithCard: { splitId in Task { await vm.handleCardTap(splitId: splitId) } },
                                payingId: vm.payingId
                            )
                        }
                    }

                    if data.entries.isEmpty && data.balances.isEmpty {
                        EmptyStateView(icon: "creditcard", text: "No expenses yet", sub: "Add your first expense")
                    }
                }
            }
            .padding(responsive.spacing(16)).padding(.bottom, 40)
            .frame(maxWidth: responsive.contentMaxWidth)
            .frame(maxWidth: .infinity)
        }
        .background(.clear)
        .refreshable { await vm.loadVault(tripId: tripId) }
        .task { await vm.loadVault(tripId: tripId) }
        .alert("Error", isPresented: Binding(get: { vm.errorMessage != nil }, set: { if !$0 { vm.errorMessage = nil } })) {
            Button("OK") { vm.errorMessage = nil }
        } message: { Text(vm.errorMessage ?? "") }
        .alert("Confirm Settlement", isPresented: Binding(get: { confirmPaySplitId != nil }, set: { if !$0 { confirmPaySplitId = nil } })) {
            Button("Cancel", role: .cancel) { confirmPaySplitId = nil }
            Button("Yes, Settled") {
                if let id = confirmPaySplitId {
                    Task { await vm.markPaid(splitId: id, tripId: tripId) }
                    confirmPaySplitId = nil
                }
            }
        } message: {
            Text("Confirm this has been settled outside the app (cash, bank transfer, etc.)?")
        }
        .alert("Payment Submitted", isPresented: Binding(get: { paymentSuccessMessage != nil }, set: { if !$0 { paymentSuccessMessage = nil } })) {
            Button("OK") { paymentSuccessMessage = nil }
        } message: { Text(paymentSuccessMessage ?? "") }
        // No-card prompt
        .alert("No Card on File", isPresented: $vm.showNoCardPrompt) {
            Button("Cancel", role: .cancel) {
                vm.pendingCardSplitId = nil
                vm.pendingCardBulkSplitIds = nil
            }
            Button("Add Card") {
                vm.showNoCardPrompt = false
                // PaymentMethodsView will be shown via sheet
            }
        } message: {
            Text("You have no card on file. Would you like to add one?")
        }
        // Reminder confirmation
        .alert("Send Reminder", isPresented: Binding(get: { reminderTargetId != nil }, set: { if !$0 { reminderTargetId = nil } })) {
            Button("Cancel", role: .cancel) { reminderTargetId = nil }
            Button("Send") {
                if let uid = reminderTargetId {
                    Task { await vm.sendReminder(targetUserId: uid, tripId: tripId) }
                    reminderTargetId = nil
                }
            }
        } message: {
            Text("Send a payment reminder to \(reminderTargetUsername.map { "@\($0)" } ?? "this member")?")
        }
        .sheet(isPresented: $showAddExpense) {
            CreateExpenseSheet(tripId: tripId, members: participants, showCategory: false) { desc, amount, cat, date, splits in
                let ok = await vm.addExpense(tripId: tripId, description: desc, amount: amount, category: cat, date: date, splits: splits)
                if ok { showAddExpense = false; await vm.loadVault(tripId: tripId) }
            }
        }
        .sheet(isPresented: $showPayTotal) {
            if let data = vm.vaultData {
                PayTotalSheet(
                    unpaidSplits: data.unpaidSplits ?? [],
                    tripId: tripId,
                    vm: vm,
                    vaultLeaderHasStripe: data.vaultLeaderHasStripe ?? false,
                    onMarkAllPaid: { splitIds in
                        Task {
                            await vm.markAllPaid(splitIds: splitIds, tripId: tripId)
                            showPayTotal = false
                        }
                    },
                    onCardPay: { splitIds in
                        showPayTotal = false
                        Task { await vm.handleBulkCardTap(splitIds: splitIds, tripId: tripId) }
                    }
                )
            }
        }
        // Add-card sheet (shown after no-card prompt → Add Card)
        .sheet(isPresented: Binding(
            get: { !vm.showNoCardPrompt && (vm.pendingCardSplitId != nil || vm.pendingCardBulkSplitIds != nil) },
            set: { if !$0 {
                vm.pendingCardSplitId = nil
                vm.pendingCardBulkSplitIds = nil
            }}
        )) {
            AddCardReturnView(
                onCardAdded: {
                    let splitId = vm.pendingCardSplitId
                    let bulkIds = vm.pendingCardBulkSplitIds
                    vm.pendingCardSplitId = nil
                    vm.pendingCardBulkSplitIds = nil
                    if let id = splitId {
                        Task { await vm.preparePaymentSheet(splitId: id) }
                    } else if let ids = bulkIds {
                        Task { await vm.prepareBulkPaymentSheet(splitIds: ids, tripId: tripId) }
                    }
                }
            )
        }
        .optionalPaymentSheet(isPresented: $vm.showPaymentSheet, paymentSheet: vm.paymentSheet) { result in
            Task {
                await vm.handlePaymentResult(result, tripId: tripId)
                if case .completed = result {
                    paymentSuccessMessage = vm.pendingPaymentMessage
                }
            }
        }
        .optionalPaymentSheet(isPresented: $vm.showBulkPaymentSheet, paymentSheet: vm.bulkPaymentSheet) { result in
            Task {
                await vm.handleBulkPaymentResult(result, tripId: tripId)
                if case .completed = result {
                    paymentSuccessMessage = vm.pendingBulkMessage
                }
            }
        }
    }

    private func canSendReminder(to targetId: Int, in data: VaultSummary) -> Bool {
        guard let me = currentUserId else { return false }
        if data.vaultLeaderId == me { return true }
        return data.entries.contains { entry in
            entry.paidById == me &&
            (entry.splits?.contains { $0.userId == targetId && !$0.paid } ?? false)
        }
    }
}

private extension View {
    @ViewBuilder
    func optionalPaymentSheet(
        isPresented: Binding<Bool>,
        paymentSheet: PaymentSheet?,
        onCompletion: @escaping (PaymentSheetResult) -> Void
    ) -> some View {
        if let sheet = paymentSheet {
            self.paymentSheet(isPresented: isPresented, paymentSheet: sheet, onCompletion: onCompletion)
        } else {
            self
        }
    }
}

// MARK: - Balance Row

struct BalanceRow: View {
    let balance: VaultBalance
    let isOwnRow: Bool
    let onTapOwn: () -> Void
    let onTapOther: () -> Void
    @EnvironmentObject var responsive: ResponsiveLayoutManager

    private var displayName: String { balance.username.map { "@\($0)" } ?? balance.name }
    private var isPayable: Bool { isOwnRow && balance.balance < 0 }

    // Combined VoiceOver summary so the row reads as one coherent statement, and the
    // owe/collect direction is conveyed in words, not color alone (Section 1.2).
    private var accessibilityText: String {
        let direction = balance.balance >= 0 ? "to collect" : "to pay"
        let amount = String(format: "$%.2f", abs(balance.balance))
        return "\(displayName), \(amount) \(direction). Paid \(String(format: "$%.2f", balance.paid)), owes \(String(format: "$%.2f", balance.owes))."
    }
    private var accessibilityActionHint: String {
        if isPayable { return "Double tap to pay your balance" }
        if !isOwnRow && balance.balance < 0 { return "Double tap to send a payment reminder" }
        return ""
    }

    var body: some View {
        Button {
            if isOwnRow {
                if isPayable { onTapOwn() }
            } else {
                onTapOther()
            }
        } label: {
            HStack(spacing: 12) {
                AvatarView(initial: String(balance.name.prefix(1)).uppercased(), color: Color.nostiaAccent, size: responsive.spacing(44))
                VStack(alignment: .leading, spacing: 4) {
                    Text(displayName).font(.headline).foregroundColor(.white)
                    HStack(spacing: 4) {
                        Text("Paid: ").foregroundColor(Color.nostiaTextSecond)
                        Text(String(format: "$%.2f", balance.paid)).foregroundColor(Color.nostiaSuccess)
                        Text(" | Owes: ").foregroundColor(Color.nostiaTextSecond)
                        Text(String(format: "$%.2f", balance.owes)).foregroundColor(Color.nostriaDanger)
                    }
                    .font(.caption)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(String(format: "$%.2f", abs(balance.balance)))
                        .font(.headline.bold())
                        .foregroundColor(balance.balance >= 0 ? Color.nostiaSuccess : Color.nostriaDanger)
                    Text(balance.balance >= 0 ? "to collect" : "to pay")
                        .font(.caption).foregroundColor(Color.nostiaTextSecond)
                }
                if isPayable {
                    Image(systemName: "chevron.right")
                        .font(.caption.bold()).foregroundColor(Color.nostiaTextMuted)
                }
            }
            .padding(responsive.spacing(16))
            .glassEffect(in: RoundedRectangle(cornerRadius: 16))
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(accessibilityText)
            .accessibilityHint(accessibilityActionHint)
        }
        .buttonStyle(.plain)
        .disabled(!isPayable && isOwnRow)
    }
}

// MARK: - Expense Card

struct ExpenseCard: View {
    let entry: VaultEntry
    let currentUserId: Int?
    let vaultLeaderId: Int?
    var vaultLeaderHasStripe: Bool = false
    let onDelete: () -> Void
    let onMarkPaid: (Int) -> Void
    let onPayWithCard: (Int) -> Void
    let payingId: Int?

    @State private var showDeleteAlert = false
    @EnvironmentObject var responsive: ResponsiveLayoutManager

    private var canDelete: Bool {
        guard let me = currentUserId else { return false }
        return vaultLeaderId == me || entry.paidById == me
    }

    private var paidByDisplay: String {
        entry.paidByUsername.map { "@\($0)" } ?? entry.paidByName ?? "Unknown"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: responsive.spacing(12)) {
            HStack {
                Image(systemName: "doc.text").foregroundColor(Color.nostiaWarning).font(.title3)
                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.description).font(.headline).foregroundColor(.white)
                    Text(entry.formattedDate).font(.caption).foregroundColor(Color.nostiaTextSecond)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(String(format: "$%.2f", entry.amount))
                        .font(.headline.bold()).foregroundColor(.white)
                    Text(entry.currency).font(.caption).foregroundColor(Color.nostiaTextSecond)
                }
                if canDelete {
                    Button { showDeleteAlert = true } label: {
                        Image(systemName: "trash").foregroundColor(Color.nostriaDanger).padding(.leading, 8)
                    }
                }
            }

            HStack {
                Text("Paid by \(Text(paidByDisplay).bold().foregroundColor(.white))")
                    .foregroundColor(Color.nostiaTextSecond)
                Spacer()
                if let cat = entry.category {
                    Text(cat).font(.caption.bold()).foregroundColor(Color.nostiaTextSecond)
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .glassEffect(in: Capsule())
                }
            }
            .font(.caption)

            if let splits = entry.splits, !splits.isEmpty {
                Divider().background(Color.white.opacity(0.1))
                ForEach(splits) { split in
                    let splitDisplay = split.userUsername.map { "@\($0)" } ?? split.userName ?? "User \(split.userId)"
                    let isOwnSplit = split.userId == currentUserId
                    HStack {
                        Text(splitDisplay)
                            .font(.footnote).foregroundColor(Color.nostiaTextSecond)
                        Spacer()
                        Text(String(format: "$%.2f", split.amount))
                            .font(.footnote.bold()).foregroundColor(.white)
                        if split.paid {
                            Label("Paid", systemImage: "checkmark.circle.fill")
                                .font(.subheadline.bold()).foregroundColor(Color.nostiaSuccess)
                        } else if isOwnSplit {
                            HStack(spacing: 8) {
                                Button { onMarkPaid(split.id) } label: {
                                    Text("Cash")
                                        .font(.subheadline.bold()).foregroundColor(.white)
                                        .padding(.horizontal, 16).padding(.vertical, 8)
                                        .glassEffect(in: RoundedRectangle(cornerRadius: 10))
                                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.2), lineWidth: 1))
                                }
                                if vaultLeaderHasStripe {
                                    Button { onPayWithCard(split.id) } label: {
                                        if payingId == split.id {
                                            ProgressView().tint(.white).scaleEffect(0.8)
                                                .frame(width: 70, height: 34)
                                                .background(Color.nostiaAccent).cornerRadius(10)
                                        } else {
                                            Text("Card")
                                                .font(.subheadline.bold()).foregroundColor(.white)
                                                .padding(.horizontal, 16).padding(.vertical, 8)
                                                .background(Color.nostiaAccent).cornerRadius(10)
                                                .shadow(color: Color.nostiaAccent.opacity(0.4), radius: 4)
                                        }
                                    }
                                    .disabled(payingId != nil)
                                }
                            }
                        }
                    }
                }
            }
        }
        .padding(responsive.spacing(16))
        .glassEffect(in: RoundedRectangle(cornerRadius: 16))
        .alert("Delete Expense", isPresented: $showDeleteAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) { onDelete() }
        } message: {
            Text("Delete \"\(entry.description)\"? This removes all associated splits.")
        }
    }
}

// MARK: - Pay Total Sheet

struct PayTotalSheet: View {
    let unpaidSplits: [UnpaidSplit]
    let tripId: Int
    let vm: VaultViewModel
    var vaultLeaderHasStripe: Bool = false
    let onMarkAllPaid: ([Int]) -> Void
    let onCardPay: ([Int]) -> Void

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var responsive: ResponsiveLayoutManager

    private var total: Double { unpaidSplits.reduce(0) { $0 + $1.amount } }
    private var splitIds: [Int] { unpaidSplits.map(\.id) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: responsive.spacing(16)) {
                    if unpaidSplits.isEmpty {
                        EmptyStateView(icon: "checkmark.circle", text: "All settled up!", sub: "You have no outstanding splits")
                            .padding(.top, 40)
                    } else {
                        ForEach(unpaidSplits) { split in
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(split.description).font(.subheadline.bold()).foregroundColor(.white)
                                    Text(split.formattedDate).font(.caption).foregroundColor(Color.nostiaTextSecond)
                                }
                                Spacer()
                                Text(String(format: "$%.2f", split.amount))
                                    .font(.subheadline.bold()).foregroundColor(.white)
                            }
                            .padding(responsive.spacing(14))
                            .glassEffect(in: RoundedRectangle(cornerRadius: 12))
                        }

                        VStack(spacing: 4) {
                            HStack {
                                Text("Total").font(.headline).foregroundColor(Color.nostiaTextSecond)
                                Spacer()
                                Text(String(format: "$%.2f", total))
                                    .font(.system(size: responsive.fontSize(28), weight: .bold)).foregroundColor(.white)
                            }
                            Text(String(format: "Card charge: $%.2f (includes Stripe fee)", calculateChargedAmount(total)))
                                .font(.caption).foregroundColor(Color.nostiaTextMuted)
                                .frame(maxWidth: .infinity, alignment: .trailing)
                        }
                        .padding(responsive.spacing(16))
                        .glassEffect(in: RoundedRectangle(cornerRadius: 16))

                        VStack(spacing: responsive.spacing(12)) {
                            HStack(spacing: 12) {
                                Button {
                                    onMarkAllPaid(splitIds)
                                } label: {
                                    Text("Pay Cash")
                                        .font(.headline.bold()).foregroundColor(.white)
                                        .frame(maxWidth: .infinity).padding(.vertical, responsive.spacing(14))
                                        .glassEffect(in: RoundedRectangle(cornerRadius: 14))
                                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.2), lineWidth: 1))
                                }
                                if vaultLeaderHasStripe {
                                    Button {
                                        onCardPay(splitIds)
                                    } label: {
                                        Text("Pay with Card")
                                            .font(.headline.bold()).foregroundColor(.white)
                                            .frame(maxWidth: .infinity).padding(.vertical, responsive.spacing(14))
                                            .background(Color.nostiaAccent).cornerRadius(14)
                                            .shadow(color: Color.nostiaAccent.opacity(0.4), radius: 8)
                                    }
                                }
                            }
                            if !vaultLeaderHasStripe {
                                Text("Card payments unavailable — the vault owner hasn't set up payouts.")
                                    .font(.caption).foregroundColor(Color.nostiaTextMuted)
                                    .multilineTextAlignment(.center)
                            }
                        }
                    }
                }
                .padding(responsive.spacing(16))
                .frame(maxWidth: responsive.sheetMaxWidth)
                .frame(maxWidth: .infinity)
            }
            .background(.clear)
            .navigationTitle("Pay Total")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cancel") { dismiss() }.foregroundColor(Color.nostiaAccent)
                }
            }
        }
        .presentationBackground(.ultraThinMaterial)
    }
}

// MARK: - Add Card Return View

struct AddCardReturnView: View {
    let onCardAdded: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            PaymentMethodsView()
                .navigationTitle("Payment Methods")
                .navigationBarTitleDisplayMode(.inline)
                .toolbarBackground(.hidden, for: .navigationBar)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Done") {
                            dismiss()
                            onCardAdded()
                        }.foregroundColor(Color.nostiaAccent)
                    }
                }
        }
        .presentationBackground(.ultraThinMaterial)
    }
}
