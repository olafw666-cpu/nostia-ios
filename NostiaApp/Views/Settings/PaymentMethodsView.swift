import SwiftUI
import SafariServices

struct PaymentMethodsView: View {
    @StateObject private var vm = PaymentsViewModel()

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                if vm.isLoading {
                    ProgressView().tint(Color.nostiaAccent).padding(40)
                } else {
                    // Saved cards
                    SettingsSection(title: "Saved Cards") {
                        if vm.paymentMethods.isEmpty {
                            Text("No saved payment methods")
                                .font(.subheadline).foregroundColor(Color.nostiaTextSecond)
                                .padding(16)
                        } else {
                            ForEach(vm.paymentMethods) { method in
                                HStack(spacing: 12) {
                                    Image(systemName: "creditcard.fill")
                                        .foregroundColor(Color.nostiaAccent).frame(width: 24)
                                    VStack(alignment: .leading, spacing: 2) {
                                        HStack {
                                            Text(method.displayName).foregroundColor(.white).font(.subheadline)
                                            if method.isDefault == true {
                                                Text("Default")
                                                    .font(.caption.bold()).foregroundColor(.white)
                                                    .padding(.horizontal, 8).padding(.vertical, 2)
                                                    .background(Color.nostiaAccent).cornerRadius(8)
                                            }
                                        }
                                        if !method.expiry.isEmpty {
                                            Text("Expires \(method.expiry)").font(.caption).foregroundColor(Color.nostiaTextMuted)
                                        }
                                    }
                                    Spacer()
                                    Menu {
                                        if method.isDefault != true {
                                            Button("Set as Default") { Task { await vm.setDefault(id: method.id) } }
                                        }
                                        Button("Remove", role: .destructive) { Task { await vm.removeMethod(id: method.id) } }
                                    } label: {
                                        Image(systemName: "ellipsis").foregroundColor(Color.nostiaTextSecond)
                                    }
                                }
                                .padding(16)
                                Divider().background(Color.nostriaBorder)
                            }
                        }
                    }

                    // Stripe Connect — for receiving payments
                    SettingsSection(title: "Receive Payments") {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "banknote.fill").foregroundColor(Color.nostiaSuccess).frame(width: 24)
                                Text("Payout Account").foregroundColor(.white)
                                Spacer()
                                if vm.onboardingStatus?.complete == true {
                                    Text("Active").font(.caption.bold()).foregroundColor(.white)
                                        .padding(.horizontal, 8).padding(.vertical, 2)
                                        .background(Color.nostiaSuccess).cornerRadius(8)
                                } else {
                                    Text("Not set up").font(.caption).foregroundColor(Color.nostiaWarning)
                                }
                            }
                            .padding(16)

                            if vm.onboardingStatus?.complete != true {
                                Button {
                                    Task { await vm.startOnboarding() }
                                } label: {
                                    Text("Set Up Payouts with Stripe")
                                        .font(.subheadline.bold()).foregroundColor(.white)
                                        .frame(maxWidth: .infinity).padding(14)
                                        .background(Color.nostiaAccent).cornerRadius(10)
                                }
                                .padding(.horizontal, 16).padding(.bottom, 12)

                                Text("Required to receive reimbursements from trip expenses.")
                                    .font(.caption).foregroundColor(Color.nostiaTextMuted)
                                    .padding(.horizontal, 16).padding(.bottom, 12)
                            }
                        }
                    }
                }

                if let err = vm.errorMessage {
                    Text(err).font(.footnote).foregroundColor(Color.nostriaDanger)
                        .padding(12).background(Color.nostriaDanger.opacity(0.1)).cornerRadius(8)
                }
            }
            .padding(16)
        }
        .background(Color.nostiaBackground)
        .task { await vm.load() }
        .refreshable { await vm.load() }
        .sheet(isPresented: $vm.showOnboarding) {
            if let url = vm.onboardingURL {
                SafariView(url: url)
            }
        }
    }
}

struct SafariView: UIViewControllerRepresentable {
    let url: URL
    func makeUIViewController(context: Context) -> SFSafariViewController {
        SFSafariViewController(url: url)
    }
    func updateUIViewController(_ vc: SFSafariViewController, context: Context) {}
}
