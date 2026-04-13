import SwiftUI

struct LoginView: View {
    @StateObject private var vm = AuthViewModel()
    @State private var username = ""
    @State private var password = ""

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
                .frame(height: 300)
                .overlay {
                    VStack(spacing: 16) {
                        Image(systemName: "safari.fill")
                            .font(.system(size: 72))
                            .foregroundColor(.white)
                            .shadow(color: .white.opacity(0.3), radius: 20)
                        Text("Welcome Back")
                            .font(.system(size: 34, weight: .bold))
                            .foregroundColor(.white)
                        Text("Sign in to continue your adventure")
                            .font(.subheadline)
                            .foregroundColor(Color(hex: "E0E7FF"))
                    }
                }
                .ignoresSafeArea(edges: .top)

                // Form
                VStack(spacing: 20) {
                    if let err = vm.errorMessage {
                        Text(err)
                            .font(.footnote)
                            .foregroundColor(Color.nostriaDanger)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(12)
                            .glassEffect(in: RoundedRectangle(cornerRadius: 10))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color.nostriaDanger.opacity(0.5), lineWidth: 1)
                            )
                    }

                    NostiaTextField(label: "Username", placeholder: "Enter your username", text: $username)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)

                    NostiaSecureField(label: "Password", placeholder: "Enter your password", text: $password)

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
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(18)
                        .background(
                            LinearGradient(colors: [Color.nostiaAccent, Color.nostriaPurple],
                                           startPoint: .leading, endPoint: .trailing)
                        )
                        .cornerRadius(16)
                        .shadow(color: Color.nostiaAccent.opacity(0.4), radius: 12, y: 6)
                    }
                    .disabled(vm.isLoading)

                    Divider().background(Color.nostriaBorder)

                    NavigationLink(destination: SignupView()) {
                        HStack(spacing: 4) {
                            Text("Don't have an account?").foregroundColor(Color.nostiaTextSecond)
                            Text("Sign Up").fontWeight(.bold).foregroundColor(Color.nostiaAccent)
                        }
                        .font(.subheadline)
                    }
                }
                .padding(24)
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

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white.opacity(0.7))
            TextField(placeholder, text: $text)
                .keyboardType(keyboardType)
                .padding(16)
                .glassEffect(in: RoundedRectangle(cornerRadius: 12))
                .foregroundColor(.white)
        }
    }
}

struct NostiaSecureField: View {
    let label: String
    let placeholder: String
    @Binding var text: String
    @State private var show = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white.opacity(0.7))
            HStack {
                Group {
                    if show { TextField(placeholder, text: $text) }
                    else { SecureField(placeholder, text: $text) }
                }
                .foregroundColor(.white)
                Button { show.toggle() } label: {
                    Image(systemName: show ? "eye.slash" : "eye")
                        .foregroundColor(Color.nostiaTextMuted)
                }
            }
            .padding(16)
            .glassEffect(in: RoundedRectangle(cornerRadius: 12))
        }
    }
}
