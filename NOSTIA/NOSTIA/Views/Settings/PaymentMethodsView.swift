import SwiftUI

struct PaymentMethodsView: View {
    @StateObject private var vm = PaymentsViewModel()
    @EnvironmentObject var responsive: ResponsiveLayoutManager

    var body: some View {
        ScrollView {
            LazyVStack(spacing: responsive.spacing(16)) {
                if vm.isLoading {
                    ProgressView().tint(Color.nostiaAccent).padding(40)
                } else {
                    // Saved cards
                    GlassSection(title: "Saved Cards") {
                        if vm.paymentMethods.isEmpty {
                            Text("No saved payment methods")
                                .font(.subheadline).foregroundColor(Color.nostiaTextSecond)
                                .padding(responsive.spacing(16))
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
                                .padding(responsive.spacing(16))
                                Divider().background(Color.nostriaBorder)
                            }
                        }

                        if vm.onboardingStatus?.complete == true {
                            Button {
                                Task { await vm.startAddCard() }
                            } label: {
                                HStack {
                                    if vm.isLoading {
                                        ProgressView().tint(.white)
                                    } else {
                                        Image(systemName: "plus.circle.fill").foregroundColor(Color.nostiaAccent)
                                        Text("Add Card").font(.subheadline.bold()).foregroundColor(Color.nostiaAccent)
                                    }
                                }
                                .frame(maxWidth: .infinity).padding(responsive.spacing(14))
                                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.nostiaAccent.opacity(0.5), lineWidth: 1))
                            }
                            .padding(.horizontal, responsive.spacing(16)).padding(.bottom, 12)
                            .disabled(vm.isLoading)
                        } else {
                            Text("Complete payout setup below to enable card payments.")
                                .font(.caption).foregroundColor(Color.nostiaTextMuted)
                                .padding(.horizontal, responsive.spacing(16)).padding(.bottom, 12)
                        }
                    }

                    // Stripe Connect — for receiving payments
                    GlassSection(title: "Receive Payments") {
                        VStack(alignment: .leading, spacing: responsive.spacing(8)) {
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
                            .padding(responsive.spacing(16))

                            if vm.onboardingStatus?.complete != true {
                                Button {
                                    Task { await vm.startOnboarding() }
                                } label: {
                                    Text("Set Up Payouts with Stripe")
                                        .font(.subheadline.bold()).foregroundColor(.white)
                                        .frame(maxWidth: .infinity).padding(responsive.spacing(14))
                                        .background(Color.nostiaAccent).cornerRadius(10)
                                }
                                .padding(.horizontal, responsive.spacing(16)).padding(.bottom, 12)

                                Text("Required to receive reimbursements from trip expenses.")
                                    .font(.caption).foregroundColor(Color.nostiaTextMuted)
                                    .padding(.horizontal, responsive.spacing(16)).padding(.bottom, 4)
                                Text("Stripe will open below. Confirm your account type and complete the identity form, then close to return to Nostia.")
                                    .font(.caption).foregroundColor(Color.nostiaTextMuted)
                                    .padding(.horizontal, responsive.spacing(16)).padding(.bottom, 12)
                            }
                        }
                    }
                }

                if let err = vm.errorMessage {
                    Text(err).font(.footnote).foregroundColor(Color.nostriaDanger)
                        .padding(12).background(Color.nostriaDanger.opacity(0.1)).cornerRadius(8)
                }
            }
            .padding(responsive.spacing(16))
            .frame(maxWidth: responsive.contentMaxWidth)
            .frame(maxWidth: .infinity)
        }
        .background(.clear)
        .task { await vm.load() }
        .refreshable { await vm.load() }
    }
}
