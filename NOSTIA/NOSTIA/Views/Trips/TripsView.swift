import SwiftUI
import AVFoundation

struct TripsView: View {
    @StateObject private var vm = TripsViewModel()
    @State private var showCreateSheet = false
    @State private var tripToDetail: Trip?
    @State private var showQRScanner = false
    @State private var scanResultAlert: ScanResultAlert?

    struct ScanResultAlert: Identifiable {
        let id = UUID()
        let title: String
        let message: String
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            if vm.isLoading {
                LoadingView()
            } else {
                List {
                    ForEach(vm.trips) { trip in
                        TripCard(trip: trip) {
                            tripToDetail = trip
                        }
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                    }
                }
                .listStyle(.plain)
                .background(.clear)
                .scrollContentBackground(.hidden)
                .refreshable { await vm.loadTrips() }
                .overlay {
                    if vm.trips.isEmpty {
                        EmptyStateView(icon: "creditcard", text: "No vaults yet", sub: "Create your first vault!")
                    }
                }
            }

            Menu {
                Button { showCreateSheet = true } label: {
                    Label("Create Vault", systemImage: "plus.circle")
                }
                Button { Task { await requestCameraAndScan() } } label: {
                    Label("Scan QR to Join", systemImage: "qrcode.viewfinder")
                }
            } label: {
                LinearGradient(colors: [Color.nostiaAccent, Color.nostriaPurple],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
                    .frame(width: 60, height: 60).clipShape(Circle())
                    .overlay(Image(systemName: "plus").font(.title2.bold()).foregroundColor(.white))
                    .shadow(color: Color.nostiaAccent.opacity(0.5), radius: 12, y: 6)
            }
            .padding(20)
        }
        .background(.clear)
        .task { await vm.loadTrips() }
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
    private func handleScan(_ token: String) async {
        do {
            let result = try await TripsAPI.shared.redeemInviteToken(token)
            await vm.loadTrips()
            if result.alreadyMember {
                scanResultAlert = ScanResultAlert(
                    title: "Already a Member",
                    message: "You're already in \"\(result.vaultName)\"."
                )
            } else {
                let friendText = result.friendsAdded > 0
                    ? " Also added \(result.friendsAdded) new \(result.friendsAdded == 1 ? "friend" : "friends")."
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

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(trip.title).font(.headline).foregroundColor(.white)
                        if let desc = trip.description, !desc.isEmpty {
                            Text(desc).font(.footnote).foregroundColor(Color(hex: "D1D5DB")).lineLimit(2)
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
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .glassEffect(in: Capsule())
                        .overlay(Capsule().stroke(Color.nostiaWarning.opacity(0.4), lineWidth: 1))
                    }
                }
                Divider().background(Color.white.opacity(0.1))
                HStack {
                    Label("\(trip.activeParticipants.count) members", systemImage: "person.2")
                        .font(.footnote).foregroundColor(Color(hex: "D1D5DB"))
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption).foregroundColor(Color.nostiaTextMuted)
                }
            }
            .padding(16)
            .glassEffect(in: RoundedRectangle(cornerRadius: 18))
        }
        .buttonStyle(.plain)
    }
}
