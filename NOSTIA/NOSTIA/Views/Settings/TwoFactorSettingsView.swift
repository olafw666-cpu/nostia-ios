import SwiftUI

/// 2FA hub in Settings (Section 2.2 step 1). Shows status, launches setup, lists
/// recognized devices, and disables 2FA (password-confirmed).
struct TwoFactorSettingsView: View {
    @EnvironmentObject var responsive: ResponsiveLayoutManager

    @State private var status: TwoFactorStatus?
    @State private var devices: [RecognizedDevice] = []
    @State private var userEmail: String?
    @State private var isLoading = true
    @State private var showSetup = false
    @State private var showDisable = false
    @State private var disablePassword = ""
    @State private var errorMessage: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: responsive.spacing(20)) {
                if isLoading {
                    ProgressView()
                        .tint(Color.nostiaAccent)
                        .frame(maxWidth: .infinity)
                        .accessibilityLabel("Loading two-factor settings")
                } else if let status {
                    statusCard(status)
                    if status.twoFactorEnabled {
                        devicesSection
                        disableButton
                    } else {
                        enableButton
                    }
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
        .navigationTitle("Two-Factor Auth")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .sheet(isPresented: $showSetup) {
            NavigationStack {
                TwoFactorSetupView(existingEmail: userEmail) {
                    Task { await load() }
                }
            }
            .presentationBackground(.ultraThinMaterial)
        }
        .alert("Turn off 2FA", isPresented: $showDisable) {
            SecureField("Current password", text: $disablePassword)
            Button("Turn off", role: .destructive) { Task { await disable() } }
            Button("Cancel", role: .cancel) { disablePassword = "" }
        } message: {
            Text("Enter your password to disable two-factor authentication.")
        }
    }

    private func statusCard(_ s: TwoFactorStatus) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: s.twoFactorEnabled ? "lock.shield.fill" : "lock.open")
                    .foregroundColor(s.twoFactorEnabled ? Color.nostiaAccent : Color.nostiaTextMuted)
                    .accessibilityHidden(true)
                Text(s.twoFactorEnabled ? "Two-factor is ON" : "Two-factor is OFF")
                    .font(.headline).foregroundColor(.white)
            }
            if let phone = s.phoneHint {
                Label("Phone \(phone)\(s.phoneVerified ? " · verified" : "")", systemImage: "phone.fill")
                    .font(.subheadline).foregroundColor(Color.nostiaTextSecond)
            }
            if let email = s.emailHint {
                Label("Email \(email)\(s.emailVerified ? " · verified" : "")", systemImage: "envelope.fill")
                    .font(.subheadline).foregroundColor(Color.nostiaTextSecond)
            }
        }
        .padding(responsive.spacing(16))
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(in: RoundedRectangle(cornerRadius: 14))
        .accessibilityElement(children: .combine)
    }

    private var enableButton: some View {
        TwoFactorPrimaryButton(title: "Set up two-factor authentication") { showSetup = true }
            .accessibilityHint("Verify your phone and email to turn on 2FA")
    }

    private var disableButton: some View {
        Button(role: .destructive) {
            disablePassword = ""; showDisable = true
        } label: {
            Text("Turn off two-factor authentication")
                .font(.system(size: responsive.fontSize(16), weight: .semibold))
                .foregroundColor(Color.nostriaDanger)
                .frame(maxWidth: .infinity)
                .frame(minHeight: 44)
                .padding(responsive.spacing(12))
                .glassEffect(in: RoundedRectangle(cornerRadius: 14))
        }
    }

    private var devicesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Recognized devices")
                .font(.headline).foregroundColor(.white)
            if devices.isEmpty {
                Text("No devices remembered yet.")
                    .font(.subheadline).foregroundColor(Color.nostiaTextMuted)
            } else {
                ForEach(devices) { device in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(device.deviceName ?? "Device")
                                .foregroundColor(.white)
                            if let seen = device.lastSeenAt {
                                Text("Last seen \(seen.prefix(10))")
                                    .font(.caption).foregroundColor(Color.nostiaTextMuted)
                            }
                        }
                        Spacer()
                        Button {
                            Task { await forget(device.id) }
                        } label: {
                            Image(systemName: "trash")
                                .foregroundColor(Color.nostriaDanger)
                                .frame(minWidth: 44, minHeight: 44)
                        }
                        .accessibilityLabel("Remove \(device.deviceName ?? "device")")
                    }
                    .padding(responsive.spacing(12))
                    .glassEffect(in: RoundedRectangle(cornerRadius: 12))
                    .accessibilityElement(children: .combine)
                }
            }
        }
    }

    // MARK: Actions

    private func load() async {
        errorMessage = nil
        do {
            let s = try await TwoFactorAPI.shared.status()
            status = s
            if userEmail == nil { userEmail = try? await AuthAPI.shared.getMe().email }
            if s.twoFactorEnabled { devices = (try? await TwoFactorAPI.shared.devices()) ?? [] }
            isLoading = false
        } catch {
            isLoading = false
            errorMessage = error.localizedDescription
        }
    }

    private func disable() async {
        do {
            try await TwoFactorAPI.shared.disable(password: disablePassword)
            disablePassword = ""
            a11yAnnounce("Two-factor authentication turned off.")
            await load()
        } catch {
            errorMessage = error.localizedDescription
            a11yAnnounce(error.localizedDescription)
        }
    }

    private func forget(_ id: Int) async {
        do {
            try await TwoFactorAPI.shared.forgetDevice(id)
            devices.removeAll { $0.id == id }
        } catch { errorMessage = error.localizedDescription }
    }
}
