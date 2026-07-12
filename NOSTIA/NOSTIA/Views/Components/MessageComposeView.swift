import SwiftUI
import MessageUI

/// UIKit bridge for the native iMessage/SMS compose sheet (`MFMessageComposeViewController`).
/// Present inside a `.sheet` only when `canSendText` is true — the Simulator and iPads
/// without SMS relay can't send texts; callers fall back to a generic `ShareLink` there.
struct MessageComposeView: UIViewControllerRepresentable {
    let messageBody: String
    @Environment(\.dismiss) private var dismiss

    static var canSendText: Bool { MFMessageComposeViewController.canSendText() }

    func makeCoordinator() -> Coordinator { Coordinator(dismiss: dismiss) }

    func makeUIViewController(context: Context) -> MFMessageComposeViewController {
        let vc = MFMessageComposeViewController()
        vc.body = messageBody
        vc.messageComposeDelegate = context.coordinator
        return vc
    }

    func updateUIViewController(_ uiViewController: MFMessageComposeViewController, context: Context) {}

    final class Coordinator: NSObject, MFMessageComposeViewControllerDelegate {
        private let dismiss: DismissAction
        init(dismiss: DismissAction) { self.dismiss = dismiss }

        // Fires on Sent AND Cancel — the compose controller never dismisses itself,
        // so skipping this leaves the sheet stuck on a dead compose view.
        func messageComposeViewController(_ controller: MFMessageComposeViewController,
                                          didFinishWith result: MessageComposeResult) {
            dismiss()
        }
    }
}
