import SwiftUI

// Shown once, immediately after profile setup on first account creation (see RootView).
// Asks whether the user wants to set up Stripe payouts / payment methods now, and routes
// into PaymentMethodsView. Because email is optional at signup but Stripe requires a
// contact_email, this captures an email first when one isn't on file — same gate as the
// "Payment Methods" row in PrivacyView, just reached from onboarding.
struct PaymentSetupPromptView: View {
    /// Called for every exit path (Set up & done, Maybe Later, swipe-dismiss handled by parent binding).
    let onFinish: () -> Void

    @EnvironmentObject private var responsive: ResponsiveLayoutManager

    @State private var user: User?
    @State private var navigateToPaymentMethods = false
    @State private var showEmailPrompt = false
    @State private var promptEmail = ""
    @State private var isSavingEmail = false
    @State private var emailSaveError: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: responsive.spacing(24)) {
                Spacer()

                Image(systemName: "banknote.fill")
                    .font(.system(size: responsive.fontSize(64)))
                    .foregroundStyle(
                        LinearGradient(colors: [Color.nostiaAccent, Color.nostriaPurple],
                                       startPoint: .topLeading, endPoint: .bottomTrailing)
                    )

                VStack(spacing: responsive.spacing(10)) {
                    Text("Set Up Payments")
                        .font(.title.bold()).foregroundColor(Color.nostiaTextPrimary)
                    Text("Connect a payout account and add a card so you can split trip expenses and get reimbursed. You can always do this later in Settings.")
                        .font(.subheadline).foregroundColor(Color.nostiaTextSecond)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, responsive.spacing(8))

                VStack(alignment: .leading, spacing: responsive.spacing(14)) {
                    featureRow(icon: "creditcard.fill", text: "Add a card to pay your share of vault expenses")
                    featureRow(icon: "arrow.down.circle.fill", text: "Receive reimbursements straight to your bank")
                    featureRow(icon: "lock.shield.fill", text: "Powered by Stripe — your details stay secure")
                }
                .padding(responsive.spacing(18))
                .frame(maxWidth: .infinity, alignment: .leading)
                .nostiaCard(in: RoundedRectangle(cornerRadius: 16))

                Spacer()

                Button {
                    startSetup()
                } label: {
                    Text("Set Up Now")
                        .font(.headline.bold()).foregroundColor(.white)
                        .frame(maxWidth: .infinity).padding(responsive.spacing(16))
                        .background(
                            LinearGradient(colors: [Color.nostiaAccent, Color.nostriaPurple],
                                           startPoint: .leading, endPoint: .trailing)
                        )
                        .cornerRadius(14)
                        .shadow(color: Color.nostiaAccent.opacity(0.4), radius: 8)
                }

                Button("Maybe Later") { onFinish() }
                    .font(.subheadline).foregroundColor(Color.nostiaTextSecond)
                    .padding(.bottom, responsive.spacing(8))
            }
            .padding(responsive.spacing(24))
            .frame(maxWidth: responsive.contentMaxWidth)
            .frame(maxWidth: .infinity)
            .background(.clear)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .navigationDestination(isPresented: $navigateToPaymentMethods) {
                PaymentMethodsView()
                    .navigationTitle("Payment Methods")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbarBackground(.hidden, for: .navigationBar)
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Done") { onFinish() }.foregroundColor(Color.nostiaAccent)
                        }
                    }
            }
            .sheet(isPresented: $showEmailPrompt) {
                EmailCaptureSheet(
                    email: $promptEmail,
                    errorMessage: $emailSaveError,
                    isSaving: $isSavingEmail,
                    onSave: { Task { await saveEmailAndContinue() } },
                    onDismiss: { showEmailPrompt = false }
                )
            }
        }
        .presentationBackground(Color.nostiaBackground)
        .task { user = try? await AuthAPI.shared.getMe() }
    }

    private func featureRow(icon: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon).foregroundColor(Color.nostiaAccent).frame(width: 24)
            Text(text).font(.subheadline).foregroundColor(Color.nostiaTextSecond)
            Spacer(minLength: 0)
        }
    }

    private func startSetup() {
        if let email = user?.email, !email.isEmpty {
            navigateToPaymentMethods = true
        } else {
            promptEmail = ""
            emailSaveError = nil
            showEmailPrompt = true
        }
    }

    private func saveEmailAndContinue() async {
        let trimmed = promptEmail.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, trimmed.contains("@"), trimmed.contains(".") else {
            emailSaveError = "Please enter a valid email address."
            return
        }
        isSavingEmail = true
        emailSaveError = nil
        do {
            user = try await AuthAPI.shared.updateMe(["email": trimmed])
            showEmailPrompt = false
            navigateToPaymentMethods = true
        } catch let error as APIError {
            if case .httpError(_, let message) = error {
                emailSaveError = message
            } else {
                emailSaveError = "Failed to save email. Please try again."
            }
        } catch {
            emailSaveError = "Failed to save email. Please try again."
        }
        isSavingEmail = false
    }
}
