import SwiftUI
import UIKit

/// Face ID account security (passkey 2FA). Enabling creates a passkey via the
/// system Face ID sheet; from then on, signing in on a new device requires
/// Face ID after the password, and the passkey is the account-recovery factor
/// if the password is forgotten. Disabling requires the current password.
struct PasskeySettingsView: View {
    @EnvironmentObject var responsive: ResponsiveLayoutManager

    @State private var status: PasskeyStatus?
    @State private var isLoading = true
    @State private var isWorking = false
    @State private var errorMessage: String?
    @State private var showDisablePrompt = false
    @State private var disablePassword = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: responsive.spacing(16)) {
                if isLoading {
                    ProgressView().tint(Color.nostiaAccent)
                        .frame(maxWidth: .infinity)
                        .accessibilityLabel("Loading Face ID settings")
                } else if let status {
                    header(enabled: status.enabled)

                    if status.enabled {
                        if !status.credentials.isEmpty {
                            credentialList(status.credentials)
                        }

                        Button(role: .destructive) {
                            disablePassword = ""
                            showDisablePrompt = true
                        } label: {
                            HStack {
                                if isWorking { ProgressView().tint(Color.nostriaDanger) }
                                Text("Turn Off Face ID Security")
                            }
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(Color.nostriaDanger)
                            .frame(maxWidth: .infinity)
                            .padding(responsive.spacing(16))
                            .nostiaCard(in: RoundedRectangle(cornerRadius: 14))
                        }
                        .disabled(isWorking)
                    } else {
                        Button {
                            Task { await enable() }
                        } label: {
                            HStack(spacing: 8) {
                                if isWorking {
                                    ProgressView().tint(.white)
                                } else {
                                    Image(systemName: "faceid")
                                    Text("Enable Face ID Security")
                                }
                            }
                            .font(.system(size: responsive.fontSize(17), weight: .bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(responsive.spacing(16))
                            .background(
                                LinearGradient(colors: [Color.nostiaAccent, Color.nostriaPurple],
                                               startPoint: .leading, endPoint: .trailing)
                            )
                            .cornerRadius(14)
                        }
                        .disabled(isWorking)
                    }

                    Text("Your passkey is stored in iCloud Keychain and synced across your Apple devices. Nostia never sees your face — Apple only tells us the check succeeded.")
                        .font(.caption).foregroundColor(Color.nostiaTextMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if let errorMessage {
                    Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                        .font(.footnote).foregroundColor(Color.nostriaDanger)
                        .accessibilityLabel("Error: \(errorMessage)")
                }
            }
            .padding(responsive.spacing(20))
            .frame(maxWidth: responsive.contentMaxWidth)
            .frame(maxWidth: .infinity)
        }
        .background(.clear)
        .navigationTitle("Face ID & Recovery")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .alert("Turn Off Face ID Security?", isPresented: $showDisablePrompt) {
            SecureField("Current password", text: $disablePassword)
            Button("Turn Off", role: .destructive) { Task { await disable() } }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Your passkeys will be removed and new devices will no longer require Face ID. Enter your password to confirm.")
        }
    }

    private func header(enabled: Bool) -> some View {
        VStack(alignment: .leading, spacing: responsive.spacing(10)) {
            HStack(spacing: 10) {
                Image(systemName: enabled ? "checkmark.shield.fill" : "faceid")
                    .font(.title2)
                    .foregroundColor(enabled ? Color.nostiaSuccess : Color.nostiaAccent)
                Text(enabled ? "Face ID Security is On" : "Face ID Security is Off")
                    .font(.headline).foregroundColor(Color.nostiaTextPrimary)
            }
            Text(enabled
                 ? "Signing in on a new device requires Face ID after your password, and you can use Face ID to reset your password if you forget it."
                 : "Add a Face ID passkey to your account. New devices will need Face ID to sign in, and you'll be able to recover your account with Face ID if you ever forget your password.")
                .font(.subheadline).foregroundColor(Color.nostiaTextSecond)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(responsive.spacing(16))
        .frame(maxWidth: .infinity, alignment: .leading)
        .nostiaCard(in: RoundedRectangle(cornerRadius: 14))
    }

    private func credentialList(_ credentials: [PasskeyStatus.Credential]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Your Passkeys")
                .font(.caption.weight(.semibold)).foregroundColor(Color.nostiaTextMuted)
                .padding(.horizontal, responsive.spacing(16))
                .padding(.top, responsive.spacing(12))
            ForEach(credentials) { cred in
                HStack(spacing: 10) {
                    Image(systemName: "key.fill").foregroundColor(Color.nostiaAccent)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(cred.deviceName ?? "Passkey")
                            .font(.subheadline).foregroundColor(Color.nostiaTextPrimary)
                        if let created = cred.createdAt {
                            Text("Added \(created.prefix(10))")
                                .font(.caption).foregroundColor(Color.nostiaTextMuted)
                        }
                    }
                    Spacer()
                }
                .padding(responsive.spacing(14))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .nostiaCard(in: RoundedRectangle(cornerRadius: 14))
    }

    private func load() async {
        do {
            status = try await PasskeyAPI.shared.status()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private func enable() async {
        isWorking = true
        errorMessage = nil
        do {
            let options = try await PasskeyAPI.shared.registrationOptions()
            let attestation = try await PasskeyManager.shared.register(options: options)
            _ = try await PasskeyAPI.shared.verifyRegistration(
                response: attestation,
                deviceName: UIDevice.current.name
            )
            status = try await PasskeyAPI.shared.status()
        } catch PasskeyManager.PasskeyError.canceled {
            // User backed out of the system sheet — not an error.
        } catch {
            errorMessage = error.localizedDescription
        }
        isWorking = false
    }

    private func disable() async {
        isWorking = true
        errorMessage = nil
        do {
            try await PasskeyAPI.shared.disable(password: disablePassword)
            status = try await PasskeyAPI.shared.status()
        } catch {
            errorMessage = error.localizedDescription
        }
        disablePassword = ""
        isWorking = false
    }
}
