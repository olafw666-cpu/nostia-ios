import Foundation
import StripePaymentSheet

@MainActor
final class VaultViewModel: ObservableObject {
    @Published var vaultData: VaultSummary?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var payingId: Int?

    // Stripe
    @Published var paymentSheet: PaymentSheet?
    @Published var showPaymentSheet = false
    @Published var pendingPaymentMessage: String?

    func loadVault(tripId: Int) async {
        isLoading = true
        errorMessage = nil
        do {
            vaultData = try await VaultAPI.shared.getTripSummary(tripId)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func addExpense(tripId: Int, description: String, amount: Double, category: String?, date: String) async -> Bool {
        do {
            _ = try await VaultAPI.shared.createEntry(tripId: tripId, description: description, amount: amount, category: category, date: date)
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func deleteEntry(_ id: Int, tripId: Int) async {
        do {
            try await VaultAPI.shared.deleteEntry(id)
            await loadVault(tripId: tripId)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func markPaid(splitId: Int, tripId: Int) async {
        do {
            try await VaultAPI.shared.markSplitPaid(splitId)
            await loadVault(tripId: tripId)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func preparePaymentSheet(splitId: Int) async {
        payingId = splitId
        do {
            let res = try await VaultAPI.shared.createPaymentIntent(splitId: splitId)
            var config = PaymentSheet.Configuration()
            config.merchantDisplayName = "Nostia"
            paymentSheet = PaymentSheet(paymentIntentClientSecret: res.clientSecret, configuration: config)
            pendingPaymentMessage = String(format: "$%.2f paid (includes Stripe processing fee). Your split will be marked as paid shortly.", res.chargedAmount)
            showPaymentSheet = true
        } catch {
            errorMessage = error.localizedDescription
            payingId = nil
        }
    }

    func handlePaymentResult(_ result: PaymentSheetResult, tripId: Int) async {
        showPaymentSheet = false
        payingId = nil
        switch result {
        case .completed:
            await loadVault(tripId: tripId)
        case .canceled:
            break
        case .failed(let error):
            errorMessage = error.localizedDescription
        }
    }
}
