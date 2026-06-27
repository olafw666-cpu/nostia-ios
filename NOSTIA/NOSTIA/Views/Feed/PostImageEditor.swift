import SwiftUI
import UIKit

/// Lets the user decide how a **wide / landscape** photo is attached to a post:
///
/// - **Fit** keeps the whole image (just scaled down) — nothing is cut off.
/// - **Crop** lets them pan & pinch to choose exactly what to keep, in a tall 4:5 frame.
///
/// Portrait / square photos skip this entirely (they already display in full), so the
/// editor is only presented for landscape images where the user has a real choice to make.
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
                        ForEach(Mode.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, 24)
                    .padding(.top, 16)

                    Spacer(minLength: 0)

                    if mode == .fit {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: geo.size.width - 32, maxHeight: cropH + 60)
                            .cornerRadius(12)
                    } else {
                        cropWindow(cropW: cropW, cropH: cropH)
                    }

                    Text(mode == .fit
                         ? "The whole photo will be shown in your post."
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
