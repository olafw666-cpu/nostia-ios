import Combine
import Foundation
import StripePaymentSheet

@MainActor
final class VaultViewModel: ObservableObject {
    @Published var vaultData: VaultSummary?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var payingId: Int?

    // Stripe — single split
    @Published var paymentSheet: PaymentSheet?
    @Published var showPaymentSheet = false
    @Published var pendingPaymentMessage: String?

    // Stripe — bulk pay
    @Published var bulkPaymentSheet: PaymentSheet?
    @Published var showBulkPaymentSheet = false
    @Published var pendingBulkMessage: String?

    // No-card prompt
    @Published var showNoCardPrompt = false
    @Published var pendingCardSplitId: Int?       // set when Card tapped for single split
    @Published var pendingCardBulkSplitIds: [Int]? // set when Card tapped for bulk pay

    func loadVault(tripId: Int) async {
        let key = CacheKey.vaultDetail(tripId)
        if let cached: VaultSummary = await CacheManager.shared.get(key) {
            vaultData = cached
        } else {
            isLoading = true
        }
        errorMessage = nil
        do {
            let fresh = try await VaultAPI.shared.getTripSummary(tripId)
            vaultData = fresh
            await CacheManager.shared.set(key, value: fresh)
        } catch is CancellationError {
        } catch let urlErr as URLError where urlErr.code == .cancelled {
        } catch {
            if vaultData == nil { errorMessage = error.localizedDescription }
        }
        isLoading = false
    }

    func addExpense(tripId: Int, description: String, amount: Double, category: String?, date: String) async -> Bool {
        do {
            try await VaultAPI.shared.createEntry(tripId: tripId, description: description, amount: amount, category: category, date: date)
            await CacheManager.shared.invalidate(CacheKey.vaultDetail(tripId))
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func deleteEntry(_ id: Int, tripId: Int) async {
        do {
            try await VaultAPI.shared.deleteEntry(id)
            await CacheManager.shared.invalidate(CacheKey.vaultDetail(tripId))
            await loadVault(tripId: tripId)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func markPaid(splitId: Int, tripId: Int) async {
        do {
            try await VaultAPI.shared.markSplitPaid(splitId)
            await CacheManager.shared.invalidate(CacheKey.vaultDetail(tripId))
            await loadVault(tripId: tripId)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func markAllPaid(splitIds: [Int], tripId: Int) async {
        do {
            for id in splitIds {
                try await VaultAPI.shared.markSplitPaid(id)
            }
            await CacheManager.shared.invalidate(CacheKey.vaultDetail(tripId))
            await loadVault(tripId: tripId)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // Called when user taps Card on a single split — check for saved card first
    func handleCardTap(splitId: Int) async {
        let methods = (try? await PaymentsAPI.shared.getPaymentMethods()) ?? []
        if methods.isEmpty {
            pendingCardSplitId = splitId
            showNoCardPrompt = true
        } else {
            await preparePaymentSheet(splitId: splitId)
        }
    }

    // Called when user taps Card on the Pay Total modal — check for saved card first
    func handleBulkCardTap(splitIds: [Int], tripId: Int) async {
        let methods = (try? await PaymentsAPI.shared.getPaymentMethods()) ?? []
        if methods.isEmpty {
            pendingCardBulkSplitIds = splitIds
            showNoCardPrompt = true
        } else {
            await prepareBulkPaymentSheet(splitIds: splitIds, tripId: tripId)
        }
    }

    func preparePaymentSheet(splitId: Int) async {
        payingId = splitId
        do {
            let res = try await VaultAPI.shared.createPaymentIntent(splitId: splitId)
            var config = PaymentSheet.Configuration()
            config.merchantDisplayName = "Nostia"
            if let cid = res.customerId, let ek = res.ephemeralKeySecret {
                config.customer = PaymentSheet.CustomerConfiguration(id: cid, ephemeralKeySecret: ek)
            }
            paymentSheet = PaymentSheet(paymentIntentClientSecret: res.clientSecret, configuration: config)
            pendingPaymentMessage = String(format: "$%.2f paid (includes Stripe processing fee). Your split will be marked as paid shortly.", res.chargedAmount)
            showPaymentSheet = true
        } catch {
            errorMessage = error.localizedDescription
            payingId = nil
        }
    }

    func prepareBulkPaymentSheet(splitIds: [Int], tripId: Int) async {
        do {
            let res = try await VaultAPI.shared.createBulkPaymentIntent(splitIds: splitIds, tripId: tripId)
            var config = PaymentSheet.Configuration()
            config.merchantDisplayName = "Nostia"
            if let cid = res.customerId, let ek = res.ephemeralKeySecret {
                config.customer = PaymentSheet.CustomerConfiguration(id: cid, ephemeralKeySecret: ek)
            }
            bulkPaymentSheet = PaymentSheet(paymentIntentClientSecret: res.clientSecret, configuration: config)
            pendingBulkMessage = String(format: "$%.2f paid (includes Stripe processing fee). Your balance will be cleared shortly.", res.chargedAmount)
            showBulkPaymentSheet = true
        } catch {
            errorMessage = error.localizedDescription
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

    func handleBulkPaymentResult(_ result: PaymentSheetResult, tripId: Int) async {
        showBulkPaymentSheet = false
        bulkPaymentSheet = nil
        switch result {
        case .completed:
            await loadVault(tripId: tripId)
        case .canceled:
            break
        case .failed(let error):
            errorMessage = error.localizedDescription
        }
    }

    func sendReminder(targetUserId: Int, tripId: Int) async {
        do {
            try await VaultAPI.shared.sendReminder(targetUserId: targetUserId, tripId: tripId)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
