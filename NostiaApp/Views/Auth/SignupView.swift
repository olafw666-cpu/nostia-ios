import SwiftUI

struct SignupView: View {
    @StateObject private var vm = AuthViewModel()
    @State private var username = ""
    @State private var password = ""
    @State private var name = ""
    @State private var email = ""
    @State private var showConsent = false
    @State private var consentGranted = false
    @State private var pendingConsent: (location: Bool, data: Bool)?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                LinearGradient(colors: [Color.nostiaAccent, Color.nostriaPurple],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
                    .frame(maxWidth: .infinity).frame(height: 240)
                    .overlay {
                        VStack(spacing: 12) {
                            Image(systemName: "safari.fill")
                                .font(.system(size: 64))
                                .foregroundColor(.white)
                                .shadow(color: .white.opacity(0.3), radius: 20)
                            Text("Join Nostia")
                                .font(.system(size: 34, weight: .bold))
                                .foregroundColor(.white)
                            Text("Start your adventure today")
                                .font(.subheadline)
                                .foregroundColor(Color(hex: "E0E7FF"))
                        }
                    }

                VStack(spacing: 20) {
                    if let err = vm.errorMessage {
                        Text(err).font(.footnote).foregroundColor(Color.nostriaDanger)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(12)
                            .glassEffect(in: RoundedRectangle(cornerRadius: 10))
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.nostriaDanger.opacity(0.5), lineWidth: 1))
                    }

                    NostiaTextField(label: "Full Name *", placeholder: "Enter your name", text: $name)
                        .textInputAutocapitalization(.words)

                    NostiaTextField(label: "Username *", placeholder: "Choose a username (3-30 chars)", text: $username)
                        .autocorrectionDisabled().textInputAutocapitalization(.never)

                    NostiaTextField(label: "Email (optional)", placeholder: "your@email.com", text: $email)
                        .keyboardType(.emailAddress).textInputAutocapitalization(.never)

                    NostiaSecureField(label: "Password *", placeholder: "At least 8 characters", text: $password)

                    if consentGranted {
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.shield.fill").foregroundColor(Color.nostiaSuccess)
                            Text("Privacy consent granted").font(.subheadline).foregroundColor(Color.nostiaSuccess)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                        .glassEffect(in: RoundedRectangle(cornerRadius: 10))
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.nostiaSuccess.opacity(0.4), lineWidth: 1))
                    }

                    Button {
                        let validationError = validate()
                        if let err = validationError { vm.errorMessage = err; return }
                        if !consentGranted { showConsent = true; return }
                        if let c = pendingConsent {
                            Task { await submitSignup(locationConsent: c.location, dataConsent: c.data) }
                        }
                    } label: {
                        HStack(spacing: 8) {
                            if vm.isLoading { ProgressView().tint(.white) }
                            else {
                                Image(systemName: consentGranted ? "person.badge.plus" : "checkmark.shield")
                                Text(consentGranted ? "Create Account" : "Continue to Consent")
                            }
                        }
                        .font(.system(size: 18, weight: .bold)).foregroundColor(.white)
                        .frame(maxWidth: .infinity).padding(18)
                        .background(LinearGradient(colors: [Color.nostiaAccent, Color.nostriaPurple],
                                                   startPoint: .leading, endPoint: .trailing))
                        .cornerRadius(16)
                        .shadow(color: Color.nostiaAccent.opacity(0.4), radius: 12, y: 6)
                    }
                    .disabled(vm.isLoading)

                    Divider().background(Color.nostriaBorder)

                    Button { dismiss() } label: {
                        HStack(spacing: 4) {
                            Text("Already have an account?").foregroundColor(Color.nostiaTextSecond)
                            Text("Login").fontWeight(.bold).foregroundColor(Color.nostiaAccent)
                        }
                        .font(.subheadline)
                    }
                }
                .padding(24)
            }
        }
        .background(.clear)
        .navigationBarHidden(true)
        .sheet(isPresented: $showConsent) {
            ConsentSheet(
                onConsent: { location, data in
                    consentGranted = true
                    pendingConsent = (location, data)
                    showConsent = false
                    Task { await submitSignup(locationConsent: location, dataConsent: data) }
                },
                onDecline: {
                    showConsent = false
                    vm.errorMessage = "Consent is required to create a Nostia account."
                }
            )
        }
    }

    func validate() -> String? {
        let trimName = name.trimmingCharacters(in: .whitespaces)
        let trimUser = username.trimmingCharacters(in: .whitespaces)
        if trimName.isEmpty || trimName.count > 100 { return "Name is required (max 100 characters)" }
        if trimUser.count < 3 || trimUser.count > 30 { return "Username must be 3-30 characters" }
        if !trimUser.allSatisfy({ $0.isLetter || $0.isNumber || $0 == "_" }) {
            return "Username can only contain letters, numbers, and underscores"
        }
        if password.count < 8 { return "Password must be at least 8 characters" }
        return nil
    }

    func submitSignup(locationConsent: Bool, dataConsent: Bool) async {
        _ = await vm.register(username: username, password: password, name: name, email: email,
                              locationConsent: locationConsent, dataCollectionConsent: dataConsent)
    }
}
