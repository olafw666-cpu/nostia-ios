import SwiftUI
import UIKit

/// Lets the user decide how a photo outside the feed's "shown in full" shape is attached:
///
/// - **Fit / Auto** keeps the original bytes. The feed renders photos at their own aspect
///   ratio clamped to 1.91:1 … 3:4 (Instagram model), so in-range photos show whole and
///   out-of-range ones are center-cropped — the preview here mirrors that exactly.
/// - **Crop** lets them pan & pinch to choose exactly what to keep, in a tall 4:5 frame.
///
/// Presented for landscape photos (fit-vs-crop is a stylistic choice) and for photos
/// taller than 3:4 (which the feed would otherwise auto-crop). Portrait/square photos
/// inside the range skip the editor — they already display in full.
struct PostImageEditor: View {
    let image: UIImage
    /// Called with the final image to attach (the original for *Fit*, the cropped region for *Crop*).
    let onDone: (UIImage) -> Void
    let onCancel: () -> Void

    enum Mode: String, CaseIterable, Identifiable {
        case fit = "Whole photo"
        case crop = "Crop"
        var id: String { rawValue }
    }
    @State private var mode: Mode = .fit

    /// Whether the feed can show this photo without trimming (PostCard clamps
    /// display ratios to 1.91:1 … 3:4).
    private var isWithinFeedRange: Bool {
        guard image.size.height > 0 else { return true }
        let ratio = image.size.width / image.size.height
        return ratio >= 3.0 / 4.0 && ratio <= 1.91
    }

    /// Display ratio the feed will actually use for this photo.
    private var feedDisplayRatio: CGFloat {
        guard image.size.height > 0 else { return 1 }
        return min(max(image.size.width / image.size.height, 3.0 / 4.0), 1.91)
    }

    // Interactive crop transform (only used in `.crop` mode).
    @State private var scale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @GestureState private var gestureScale: CGFloat = 1
    @GestureState private var gestureDrag: CGSize = .zero

    var body: some View {
        GeometryReader { geo in
            let cropW = min(geo.size.width - 48, 320)
            let cropH = cropW * 5 / 4   // 4:5 portrait crop window

            ZStack {
                Color.black.ignoresSafeArea()

                VStack(spacing: 18) {
                    Picker("", selection: $mode) {
                        ForEach(Mode.allCases) { m in
                            // "Whole photo" would be a lie for out-of-range photos —
                            // the feed center-crops them, so the mode reads "Auto".
                            Text(m == .fit && !isWithinFeedRange ? "Auto" : m.rawValue).tag(m)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, 24)
                    .padding(.top, 16)

                    Spacer(minLength: 0)

                    if mode == .fit {
                        // Rendered at the feed's clamped ratio so the preview is exactly
                        // what PostCard will show (identical to the whole photo when the
                        // ratio is in range, center-cropped when it isn't).
                        Color.clear
                            .aspectRatio(feedDisplayRatio, contentMode: .fit)
                            .frame(maxWidth: geo.size.width - 32, maxHeight: cropH + 60)
                            .overlay(
                                Image(uiImage: image)
                                    .resizable()
                                    .scaledToFill()
                                    .allowsHitTesting(false)
                            )
                            .clipped()
                            .cornerRadius(12)
                    } else {
                        cropWindow(cropW: cropW, cropH: cropH)
                    }

                    Text(mode == .fit
                         ? (isWithinFeedRange
                            ? "The whole photo will be shown in your post."
                            : "The feed trims photos this shape — the middle is kept. Use Crop to choose exactly what's shown.")
                         : "Drag and pinch to choose what to keep.")
                        .font(.footnote)
                        .foregroundColor(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)

                    Spacer(minLength: 0)

                    HStack(spacing: 12) {
                        Button { onCancel() } label: {
                            Text("Cancel")
                                .font(.body.weight(.medium)).foregroundColor(.white)
                                .frame(maxWidth: .infinity).padding(16)
                                .background(Color.white.opacity(0.12)).cornerRadius(14)
                        }
                        Button {
                            onDone(mode == .fit ? image : renderCrop(cropW: cropW, cropH: cropH))
                        } label: {
                            Text("Use Photo")
                                .font(.headline).foregroundColor(.white)
                                .frame(maxWidth: .infinity).padding(16)
                                .background(Color.nostiaAccent).cornerRadius(14)
                        }
                    }
                    .padding(.horizontal, 24).padding(.bottom, 32)
                }
            }
        }
    }

    // MARK: - Crop window

    private func cropWindow(cropW: CGFloat, cropH: CGFloat) -> some View {
        Image(uiImage: image)
            .resizable()
            .scaledToFill()
            .scaleEffect(scale * gestureScale, anchor: .center)
            .offset(x: offset.width + gestureDrag.width,
                    y: offset.height + gestureDrag.height)
            .frame(width: cropW, height: cropH)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.white.opacity(0.65), lineWidth: 1.5))
            .gesture(
                DragGesture()
                    .updating($gestureDrag) { v, state, _ in state = v.translation }
                    .onEnded { v in
                        offset = clamped(CGSize(width: offset.width + v.translation.width,
                                                height: offset.height + v.translation.height),
                                         cropW: cropW, cropH: cropH)
                    }
            )
            .simultaneousGesture(
                MagnificationGesture()
                    .updating($gestureScale) { v, state, _ in state = v }
                    .onEnded { v in
                        scale = min(5, max(1, scale * v))
                        offset = clamped(offset, cropW: cropW, cropH: cropH)
                    }
            )
    }

    // MARK: - Geometry helpers

    /// Scale that makes the image exactly fill the crop window at `scale == 1`
    /// (matches SwiftUI's `scaledToFill` inside the crop frame).
    private func baseScale(cropW: CGFloat, cropH: CGFloat) -> CGFloat {
        max(cropW / image.size.width, cropH / image.size.height)
    }

    private func clamped(_ proposed: CGSize, cropW: CGFloat, cropH: CGFloat) -> CGSize {
        let displayW = image.size.width * baseScale(cropW: cropW, cropH: cropH) * scale
        let displayH = image.size.height * baseScale(cropW: cropW, cropH: cropH) * scale
        let maxX = max(0, (displayW - cropW) / 2)
        let maxY = max(0, (displayH - cropH) / 2)
        return CGSize(width: min(max(proposed.width, -maxX), maxX),
                      height: min(max(proposed.height, -maxY), maxY))
    }

    private func renderCrop(cropW: CGFloat, cropH: CGFloat) -> UIImage {
        let outputSize = CGSize(width: cropW, height: cropH)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 2   // sharper than 1pt-per-px; resizedForUpload still caps the size
        let renderer = UIGraphicsImageRenderer(size: outputSize, format: format)
        let base = baseScale(cropW: cropW, cropH: cropH)
        return renderer.image { _ in
            let dW = image.size.width * base * scale
            let dH = image.size.height * base * scale
            let x = (cropW - dW) / 2 + offset.width
            let y = (cropH - dH) / 2 + offset.height
            image.draw(in: CGRect(x: x, y: y, width: dW, height: dH))
        }
    }
}
