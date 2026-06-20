import UIKit
import UserNotifications

/// Owns APNs permission, device-token registration, foreground presentation, and
/// deep-link routing for taps (spec Section 3). Push is additive: in-app notifications
/// are unaffected by the system permission.
final class PushNotificationManager: NSObject, UNUserNotificationCenterDelegate {
    static let shared = PushNotificationManager()

    private(set) var deviceTokenHex: String?
    private override init() { super.init() }

    func startObserving() {
        UNUserNotificationCenter.current().delegate = self
        NotificationCenter.default.addObserver(self, selector: #selector(handleLogin), name: .userDidLogin, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleLogout), name: .userDidLogout, object: nil)
    }

    // MARK: - Permission & registration

    /// Request authorization at an appropriate moment — after the user is in the app,
    /// never on first launch (Section 3.1 "Permission"). Safe to call repeatedly.
    func requestAuthorizationIfAppropriate() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            let status = settings.authorizationStatus
            Task { @MainActor in
                let center = UNUserNotificationCenter.current()
                switch status {
                case .notDetermined:
                    let granted = (try? await center.requestAuthorization(options: [.alert, .badge, .sound])) ?? false
                    if granted { UIApplication.shared.registerForRemoteNotifications() }
                case .authorized, .provisional, .ephemeral:
                    UIApplication.shared.registerForRemoteNotifications()
                default:
                    break // user declined — respect their choice
                }
            }
        }
    }

    /// Called by AppDelegate once APNs returns the device token.
    func didRegister(deviceTokenHex hex: String) {
        deviceTokenHex = hex
        sendTokenToServerIfAuthed()
    }

    private func sendTokenToServerIfAuthed() {
        guard let hex = deviceTokenHex, AuthManager.shared.getToken() != nil else { return }
        Task { try? await NotificationsAPI.shared.savePushToken(hex, platform: "ios") }
    }

    @objc private func handleLogin() { sendTokenToServerIfAuthed() }

    @objc private func handleLogout() {
        guard let hex = deviceTokenHex else { return }
        Task { try? await NotificationsAPI.shared.removePushToken(hex) }
    }

    /// Clear the app icon badge (Section 3.3) — call when the notification tab is viewed.
    func clearBadge() {
        UNUserNotificationCenter.current().setBadgeCount(0)
    }

    // MARK: - UNUserNotificationCenterDelegate
    // nonisolated: the system invokes these off the main actor.

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
                                            willPresent notification: UNNotification,
                                            withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        // Show high-priority pushes even when the app is foregrounded.
        completionHandler([.banner, .badge, .sound])
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
                                            didReceive response: UNNotificationResponse,
                                            withCompletionHandler completionHandler: @escaping () -> Void) {
        let userInfo = response.notification.request.content.userInfo
        Task { @MainActor in DeepLinkRouter.shared.handle(userInfo: userInfo) }
        completionHandler()
    }
}
