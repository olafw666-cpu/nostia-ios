import SwiftUI
import Combine

/// Cold-launch splash. Shown once when the app process starts (wired into `RootView`),
/// never when navigating around the app. The Nostia mark performs one full 360° rotation
/// every second — a brief spin with a rest in between, not a continuous spinner.
/// Honors Reduce Motion (shows the mark static) for accessibility.
struct LaunchView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var rotation: Double = 0

    // Fires one spin per second.
    private let spinTimer = Timer.publish(every: 1.0, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            // The mark sits on solid black in the asset, so a black backdrop blends seamlessly.
            Color.black.ignoresSafeArea()

            VStack(spacing: 28) {
                Image("NostiaMark")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 116, height: 116)
                    .rotationEffect(.degrees(rotation))

                Image("NostiaWordmark")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 168)
            }
        }
        // One spoken element rather than two decorative images.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Nostia")
        .accessibilityAddTraits(.isImage)
        .onAppear {
            guard !reduceMotion else { return }
            spinOnce() // first spin right away so it animates in
        }
        .onReceive(spinTimer) { _ in
            guard !reduceMotion else { return }
            spinOnce()
        }
    }

    private func spinOnce() {
        withAnimation(.easeInOut(duration: 0.7)) {
            rotation += 360
        }
    }
}
