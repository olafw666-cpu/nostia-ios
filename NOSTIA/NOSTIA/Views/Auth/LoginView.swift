import AuthenticationServices
import SwiftUI

struct LoginView: View {
    @StateObject private var vm = AuthViewModel()
    @State private var username = ""
    @State private var password = ""
    @EnvironmentObject var responsive: ResponsiveLayoutManager

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Header
                LinearGradient(
                    colors: [Color.nostiaAccent, Color.nostriaPurple],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .frame(maxWidth: .infinity)
                .frame(height: responsive.spacing(300))
                .overlay {
                    VStack(spacing: responsive.spacing(16)) {
                        Image(systemName: "safari.fill")
                            .font(.nostiaBody(responsive.fontSize(72)))
                            .foregroundColor(.white)
                            .shadow(color: .white.opacity(0.3), radius: 20)
                        Text("Welcome Back")
                            .font(.nostiaBody(responsive.fontSize(34), weight: .bold))
                            .foregroundColor(.white)
                        Text("Sign in to continue your adventure")
                            .font(.subheadline)
                            .foregroundColor(Color(hex: "E0E7FF"))
                    }
                }
                .ignoresSafeArea(edges: .top)

                // Form
                VStack(spacing: responsive.spacing(20)) {
                    if let err = vm.errorMessage {
                        Text(err)
                            .font(.footnote)
                            .foregroundColor(Color.nostriaDanger)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(12)
                            .nostiaCard(in: RoundedRectangle(cornerRadius: 10))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color.nostriaDanger.opacity(0.5), lineWidth: 1)
                            )
                    }

                    NostiaTextField(label: "Username", placeholder: "Enter your username", text: $username)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)

                    NostiaSecureField(label: "Password", placeholder: "Enter your password", text: $password)

                    NavigationLink(destination: ForgotPasswordView()) {
                        Text("Forgot password?")
                            .font(.footnote.weight(.semibold))
                            .foregroundColor(Color.nostiaAccent)
                    }
                    .frame(maxWidth: .infinity, alignment: .trailing)

                    Button {
                        Task { await vm.login(username: username, password: password) }
                    } label: {
                        HStack(spacing: 8) {
                            if vm.isLoading {
                                ProgressView().tint(.white)
                            } else {
                                Image(systemName: "arrow.right.circle.fill")
                                Text("Login")
                            }
                        }
                        .font(.nostiaBody(responsive.fontSize(18), weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(responsive.spacing(18))
                        .background(
                            LinearGradient(colors: [Color.nostiaAccent, Color.nostriaPurple],
                                           startPoint: .leading, endPoint: .trailing)
                        )
                        .cornerRadius(16)
                        .shadow(color: Color.nostiaAccent.opacity(0.4), radius: 12, y: 6)
                    }
                    .disabled(vm.isLoading)

                    // v2 §4.1 minimal auth: one tap in, no form. Works for both
                    // returning and brand-new accounts (find-or-create by the
                    // token's stable sub claim).
                    SignInWithAppleButton(.signIn) { request in
                        request.requestedScopes = [.fullName, .email]
                    } onCompletion: { result in
                        guard case .success(let auth) = result,
                              let credential = auth.credential as? ASAuthorizationAppleIDCredential,
                              let tokenData = credential.identityToken,
                              let token = String(data: tokenData, encoding: .utf8) else { return }
                        let name = [credential.fullName?.givenName, credential.fullName?.familyName]
                            .compactMap { $0 }.joined(separator: " ")
                        Task { await vm.appleSignIn(identityToken: token, name: name.isEmpty ? nil : name) }
                    }
                    .signInWithAppleButtonStyle(.black)
                    .frame(height: 50)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .accessibilityLabel("Sign in with Apple")

                    Divider().background(Color.nostriaBorder)

                    NavigationLink(destination: SignupView()) {
                        HStack(spacing: 4) {
                            Text("Don't have an account?").foregroundColor(Color.nostiaTextSecond)
                            Text("Sign Up").fontWeight(.bold).foregroundColor(Color.nostiaAccent)
                        }
                        .font(.subheadline)
                    }
                }
                .padding(responsive.spacing(24))
                .frame(maxWidth: responsive.contentMaxWidth)
                .frame(maxWidth: .infinity)
            }
        }
        .background(.clear)
        .scrollBounceBehavior(.basedOnSize)
        .navigationBarHidden(true)
    }
}

// MARK: - Shared Input Components

struct NostiaTextField: View {
    let label: String
    let placeholder: String
    @Binding var text: String
    var keyboardType: UIKeyboardType = .default
    @EnvironmentObject var responsive: ResponsiveLayoutManager

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.nostiaBody(responsive.fontSize(14), weight: .semibold))
                .foregroundColor(Color.nostiaTextSecond)
            TextField(placeholder, text: $text)
                .keyboardType(keyboardType)
                .padding(responsive.spacing(16))
                .nostiaCard(in: RoundedRectangle(cornerRadius: 12))
                .foregroundColor(Color.nostiaTextPrimary)
        }
    }
}

struct NostiaSecureField: View {
    let label: String
    let placeholder: String
    @Binding var text: String
    @State private var show = false
    @EnvironmentObject var responsive: ResponsiveLayoutManager

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.nostiaBody(responsive.fontSize(14), weight: .semibold))
                .foregroundColor(Color.nostiaTextSecond)
            HStack {
                Group {
                    if show { TextField(placeholder, text: $text) }
                    else { SecureField(placeholder, text: $text) }
                }
                .foregroundColor(Color.nostiaTextPrimary)
                Button { show.toggle() } label: {
                    Image(systemName: show ? "eye.slash" : "eye")
                        .foregroundColor(Color.nostiaTextMuted)
                        .frame(width: 36, height: 36)
                }
                .buttonStyle(.nostiaTap)
                .accessibilityLabel(show ? "Hide password" : "Show password")
            }
            .padding(responsive.spacing(16))
            .nostiaCard(in: RoundedRectangle(cornerRadius: 12))
        }
    }
}
