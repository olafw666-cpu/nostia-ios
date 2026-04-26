import SwiftUI
import StripePaymentSheet

// VaultContentView: embeddable vault expense view (no own navigation)
struct VaultContentView: View {
    let tripId: Int
    var isKicked: Bool = false

    @StateObject private var vm = VaultViewModel()
    @State private var showAddExpense = false
    @State private var confirmPaySplitId: Int?
    @State private var paymentSuccessMessage: String?

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                if vm.isLoading {
                    ProgressView().tint(Color.nostiaAccent).frame(maxWidth: .infinity).padding(40)
                } else if let data = vm.vaultData {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Total Expenses").font(.footnote).foregroundColor(Color.nostiaTextSecond)
                            Text(String(format: "$%.2f", data.totalAmount ?? 0))
                                .font(.system(size: 34, weight: .bold)).foregroundColor(.white)
                        }
                        Spacer()
                        if !isKicked {
                            Button { showAddExpense = true } label: {
                                Label("Add Expense", systemImage: "plus")
                                    .font(.subheadline.bold()).foregroundColor(.white)
                                    .padding(.horizontal, 16).padding(.vertical, 10)
                                    .background(Color.nostiaAccent).cornerRadius(12)
                                    .shadow(color: Color.nostiaAccent.opacity(0.4), radius: 8)
                            }
                        }
                    }
                    .padding(16)
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

                    if !data.balances.isEmpty {
                        Text("Balances").font(.headline).foregroundColor(.white)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        ForEach(data.balances) { bal in
                            BalanceCard(balance: bal)
                        }
                    }

                    if !data.entries.isEmpty {
                        Text("Expenses").font(.headline).foregroundColor(.white)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        ForEach(data.entries) { entry in
                            ExpenseCard(
                                entry: entry,
                                onDelete: { Task { await vm.deleteEntry(entry.id, tripId: tripId) } },
                                onMarkPaid: { splitId in confirmPaySplitId = splitId },
                                onPayWithCard: { splitId in Task { await vm.preparePaymentSheet(splitId: splitId) } },
                                payingId: vm.payingId
                            )
                        }
                    }

                    if data.entries.isEmpty && data.balances.isEmpty {
                        EmptyStateView(icon: "creditcard", text: "No expenses yet", sub: "Add your first expense")
                    }
                }
            }
            .padding(16).padding(.bottom, 40)
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
        .sheet(isPresented: $showAddExpense) {
            CreateExpenseSheet(tripId: tripId, showCategory: false) { desc, amount, cat, date in
                let ok = await vm.addExpense(tripId: tripId, description: desc, amount: amount, category: cat, date: date)
                if ok { showAddExpense = false; await vm.loadVault(tripId: tripId) }
            }
        }
        .optionalPaymentSheet(isPresented: $vm.showPaymentSheet, paymentSheet: vm.paymentSheet) { result in
            Task {
                await vm.handlePaymentResult(result, tripId: tripId)
                if case .completed = result {
                    paymentSuccessMessage = vm.pendingPaymentMessage
                }
            }
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

struct BalanceCard: View {
    let balance: VaultBalance
    var body: some View {
        HStack(spacing: 12) {
            AvatarView(initial: String(balance.name.prefix(1)).uppercased(), color: Color.nostiaAccent, size: 44)
            VStack(alignment: .leading, spacing: 4) {
                Text(balance.name).font(.headline).foregroundColor(.white)
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
        }
        .padding(16)
        .glassEffect(in: RoundedRectangle(cornerRadius: 16))
    }
}

struct ExpenseCard: View {
    let entry: VaultEntry
    let onDelete: () -> Void
    let onMarkPaid: (Int) -> Void
    let onPayWithCard: (Int) -> Void
    let payingId: Int?

    @State private var showDeleteAlert = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
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
                Button { showDeleteAlert = true } label: {
                    Image(systemName: "trash").foregroundColor(Color.nostriaDanger).padding(.leading, 8)
                }
            }

            HStack {
                if let paidBy = entry.paidByName {
                    Text("Paid by \(Text(paidBy).bold().foregroundColor(.white))")
                        .foregroundColor(Color.nostiaTextSecond)
                }
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
                    HStack {
                        Text(split.userName ?? "User \(split.userId)")
                            .font(.footnote).foregroundColor(Color.nostiaTextSecond)
                        Spacer()
                        Text(String(format: "$%.2f", split.amount))
                            .font(.footnote.bold()).foregroundColor(.white)
                        if split.paid {
                            Label("Paid", systemImage: "checkmark.circle.fill")
                                .font(.subheadline.bold()).foregroundColor(Color.nostiaSuccess)
                        } else {
                            HStack(spacing: 8) {
                                Button { onMarkPaid(split.id) } label: {
                                    Text("Cash")
                                        .font(.subheadline.bold()).foregroundColor(.white)
                                        .padding(.horizontal, 16).padding(.vertical, 8)
                                        .glassEffect(in: RoundedRectangle(cornerRadius: 10))
                                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.2), lineWidth: 1))
                                }
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
        .padding(16)
        .glassEffect(in: RoundedRectangle(cornerRadius: 16))
        .alert("Delete Expense", isPresented: $showDeleteAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) { onDelete() }
        } message: {
            Text("Delete \"\(entry.description)\"? This removes all associated splits.")
        }
    }
}
