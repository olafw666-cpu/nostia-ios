import SwiftUI
import AVFoundation

struct TripsView: View {
    @StateObject private var vm = TripsViewModel()
    @State private var showCreateSheet = false
    @State private var tripToDetail: Trip?
    @State private var showQRScanner = false
    @State private var scanResultAlert: ScanResultAlert?
    @EnvironmentObject var responsive: ResponsiveLayoutManager
    @EnvironmentObject var deepLinkRouter: DeepLinkRouter

    struct ScanResultAlert: Identifiable {
        let id = UUID()
        let title: String
        let message: String
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 14) {
                    VStack(alignment: .leading, spacing: 4) {
                        NostiaScreenTitle(title: "Vaults")
                        Text("Shared pots. Add followers, split costs, settle up.")
                            .font(.system(size: 14)).foregroundColor(Color.nostiaTextSecond)
                    }
                    .padding(.top, 4)
                    .padding(.bottom, 2)

                    if vm.isLoading && vm.trips.isEmpty {
                        VaultListSkeletonView()
                    } else if vm.trips.isEmpty {
                        EmptyStateView(icon: "creditcard", text: "No vaults yet", sub: "Create your first vault!")
                    } else {
                        ForEach(vm.trips) { trip in
                            TripCard(trip: trip) {
                                Haptics.tap()
                                tripToDetail = trip
                            }
                        }
                    }
                }
                .padding(.horizontal, responsive.spacing(16))
                .padding(.bottom, 120)
                .frame(maxWidth: responsive.contentMaxWidth)
                .frame(maxWidth: .infinity)
            }
            .background(.clear)
            .refreshable { await vm.loadTrips() }

            Menu {
                Button { Haptics.tap(); showCreateSheet = true } label: {
                    Label("Create Vault", systemImage: "plus.circle")
                }
                Button { Haptics.tap(); Task { await requestCameraAndScan() } } label: {
                    Label("Scan QR to Join", systemImage: "qrcode.viewfinder")
                }
            } label: {
                Circle().fill(Color.nostiaAccent)
                    .frame(width: 60, height: 60)
                    .overlay(Image(systemName: "plus").font(.system(size: 31, weight: .semibold)).foregroundColor(.white))
                    .shadow(color: Color.nostiaAccent.opacity(0.6), radius: 18, y: 8)
            }
            .padding(.trailing, responsive.spacing(22))
            .padding(.bottom, 100)
        }
        .background(.clear)
        .task {
            await vm.loadTrips()
            consumePendingVaultLink()
        }
        // A tapped vault push can only switch tabs; opening the actual vault happens
        // here, once the trip list contains the target.
        .onChange(of: deepLinkRouter.pendingVaultTripId) {
            consumePendingVaultLink()
        }
        .onChange(of: vm.isLoading) {
            if !vm.isLoading { consumePendingVaultLink() }
        }
        .alert("Error", isPresented: Binding(get: { vm.errorMessage != nil }, set: { if !$0 { vm.errorMessage = nil } })) {
            Button("OK") { vm.errorMessage = nil }
        } message: { Text(vm.errorMessage ?? "") }
        .sheet(isPresented: $showCreateSheet) {
            CreateTripSheet { title, desc, friendIds in
                if let trip = await vm.createTrip(title: title, description: desc, friendIds: friendIds) {
                    showCreateSheet = false
                    tripToDetail = trip
                }
            }
        }
        .sheet(isPresented: $showQRScanner) {
            QRScannerSheet { scanned in Task { await handleScan(scanned) } }
        }
        .alert(item: $scanResultAlert) { a in
            Alert(title: Text(a.title), message: Text(a.message), dismissButton: .default(Text("OK")))
        }
        .navigationDestination(item: $tripToDetail) { trip in
            VaultDetailView(trip: trip, tripsVM: vm)
        }
    }

    /// Opens the vault a tapped push pointed at. Left pending until the trip list
    /// actually contains it (it may still be loading when the tab switches).
    private func consumePendingVaultLink() {
        guard let tripId = deepLinkRouter.pendingVaultTripId,
              let trip = vm.trips.first(where: { $0.id == tripId }) else { return }
        deepLinkRouter.pendingVaultTripId = nil
        tripToDetail = trip
    }

    @MainActor
    private func requestCameraAndScan() async {
        let granted = await AVCaptureDevice.requestAccess(for: .video)
        if granted {
            showQRScanner = true
        } else {
            scanResultAlert = ScanResultAlert(
                title: "Camera Required",
                message: "Enable camera access in Settings to scan QR codes."
            )
        }
    }

    @MainActor
    private func handleScan(_ scanned: String) async {
        // QRs now carry nostia://invite/<token> (scannable by the native Camera app);
        // QRs from older builds hold the bare 32-hex token. Accept both.
        let token = scanned
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "nostia://invite/", with: "")
        do {
            let result = try await TripsAPI.shared.redeemInviteToken(token)
            await vm.loadTrips()
            if result.alreadyMember {
                scanResultAlert = ScanResultAlert(
                    title: "Already a Member",
                    message: "You're already in \"\(result.vaultName)\"."
                )
            } else {
                let friendsAdded = result.friendsAdded ?? 0
                let friendText = friendsAdded > 0
                    ? " Also added \(friendsAdded) new \(friendsAdded == 1 ? "friend" : "friends")."
                    : ""
                scanResultAlert = ScanResultAlert(
                    title: "Joined \(result.vaultName)!",
                    message: "Welcome to the vault!\(friendText)"
                )
                tripToDetail = result.trip
            }
        } catch {
            scanResultAlert = ScanResultAlert(
                title: "Could Not Join",
                message: error.localizedDescription
            )
        }
    }
}

struct TripCard: View {
    let trip: Trip
    let onTap: () -> Void
    @EnvironmentObject var responsive: ResponsiveLayoutManager

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: responsive.spacing(12)) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(trip.title).font(.nostiaDisplay(21, weight: .heavy)).foregroundColor(Color.nostiaTextPrimary)
                        if let desc = trip.description, !desc.isEmpty {
                            Text(desc).font(.footnote).foregroundColor(Color.nostiaTextSecond).lineLimit(2)
                        }
                    }
                    Spacer()
                    // Leader badge
                    if let leaderId = trip.vaultLeaderId,
                       leaderId == AuthManager.shared.currentUserId {
                        HStack(spacing: 4) {
                            Image(systemName: "key.fill").font(.system(size: 10))
                            Text("Leader")
                        }
                        .font(.caption.bold()).foregroundColor(Color.nostiaWarning)
                        .padding(.horizontal, 11).padding(.vertical, 5)
                        .background(Capsule().fill(Color.nostiaWarningSoft))
                    }
                }
                Divider().background(Color.nostiaDivider)
                HStack(spacing: 10) {
                    Label("\(trip.activeParticipants.count) members", systemImage: "person.2.fill")
                        .font(.system(size: 13.5, weight: .semibold)).foregroundColor(Color.nostiaTextSecond)
                        .labelStyle(AtlasLeadingIconLabel(tint: Color.nostiaAccent))
                    Spacer()
                    Text(trip.formattedVaultTotal)
                        .font(.nostiaDisplay(17, weight: .heavy))
                        .foregroundColor(Color.nostiaTextPrimary)
                        .lineLimit(1)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 18)).foregroundColor(Color.nostiaTextMuted)
                }
            }
            .padding(responsive.spacing(18))
            .nostiaWarmCard(in: RoundedRectangle(cornerRadius: 20))
        }
        .buttonStyle(.plain)
    }
}
