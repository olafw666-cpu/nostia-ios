import SwiftUI
import UserNotifications
import UIKit

/// Single all-or-nothing push toggle (Section 3.3). When off, the backend skips push
/// but still records in-app notifications.
struct NotificationSettingsView: View {
    @EnvironmentObject var responsive: ResponsiveLayoutManager

    @State private var pushEnabled = true
    @State private var isLoading = true
    @State private var systemDenied = false
    @State private var errorMessage: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: responsive.spacing(16)) {
                if isLoading {
                    ProgressView().tint(Color.nostiaAccent)
                        .frame(maxWidth: .infinity)
                        .accessibilityLabel("Loading notification settings")
                } else {
                    Toggle(isOn: Binding(
                        get: { pushEnabled },
                        set: { newValue in pushEnabled = newValue; Task { await save(newValue) } }
                    )) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Push Notifications").foregroundColor(.white)
                            Text("Get notified about reminders, follows, invites, and payments.")
                                .font(.caption).foregroundColor(Color.nostiaTextMuted)
                        }
                    }
                    .tint(Color.nostiaAccent)
                    .padding(responsive.spacing(16))
                    .glassEffect(in: RoundedRectangle(cornerRadius: 14))
                    .accessibilityHint("Turns all push notifications on or off")

                    if systemDenied {
                        Label("Notifications are turned off in iOS Settings. Enable them in Settings to receive pushes.",
                              systemImage: "exclamationmark.triangle.fill")
                            .font(.footnote).foregroundColor(.yellow)
                            .fixedSize(horizontal: false, vertical: true)
                        Button("Open iOS Settings") {
                            if let url = URL(string: UIApplication.openSettingsURLString) {
                                UIApplication.shared.open(url)
                            }
                        }
                        .foregroundColor(Color.nostiaAccent)
                    }

                    Text("In-app notifications always appear in your notifications tab, regardless of this setting.")
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
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
    }

    private func load() async {
        do {
            pushEnabled = try await NotificationsAPI.shared.getPushEnabled()
        } catch {
            errorMessage = error.localizedDescription
        }
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        systemDenied = settings.authorizationStatus == .denied
        isLoading = false
    }

    private func save(_ enabled: Bool) async {
        do {
            try await NotificationsAPI.shared.setPushEnabled(enabled)
            if enabled { PushNotificationManager.shared.requestAuthorizationIfAppropriate() }
        } catch {
            errorMessage = error.localizedDescription
            pushEnabled.toggle() // revert on failure
        }
    }
}
