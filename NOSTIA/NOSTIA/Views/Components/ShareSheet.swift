import SwiftUI
import UIKit

/// System share sheet. Used by plan invites (v2 §4.6/§8 — the invite has to
/// survive leaving the app, so the link goes out through Messages and friends).
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}

/// `.sheet(item:)` needs Identifiable, and URL isn't. Wraps a share target.
struct ShareTarget: Identifiable {
    let url: URL
    var id: String { url.absoluteString }
}
