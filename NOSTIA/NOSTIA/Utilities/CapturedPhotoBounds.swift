import UIKit

/// Bounds a freshly captured JPEG before it leaves the device.
///
/// Security audit F-04 / D7.3: the completion-photo endpoint is the app's first
/// untrusted-binary ingest path, and the client is the one place that can keep
/// the binary small by construction instead of validating it after the fact.
/// Three things follow from bounding here:
///
///  * The server's `sanity()` 10 MB rejection lands AFTER the capture nonce is
///    consumed, so an oversize original burns the token and sends the user back
///    through the camera for nothing. A bounded upload makes that unreachable.
///  * A ~1600px long edge is all the photo judge and the perceptual hash need;
///    shipping a full-resolution original is pure decode surface (and cellular
///    data) for no verification benefit.
///  * Re-encoding through a renderer strips the capture's EXIF, so no camera
///    metadata rides along to a third-party AI service (D9.5).
///
/// This is a client-side reduction of risk, not a control: the server must still
/// validate independently (magic bytes, pixel ceiling, size), because nothing
/// stops a modified client from posting whatever it likes.
enum CapturedPhotoBounds {
    /// Long edge in pixels. Comfortably above the server's `MIN_SHORT_SIDE`
    /// floor even for a 4:3 frame.
    static let maxLongEdge: CGFloat = 1600
    /// Well under the server's 10 MB ceiling, so a bounded photo can never be
    /// the reason a nonce is spent.
    static let maxBytes = 4 * 1024 * 1024

    /// Returns a downscaled, size-capped JPEG. Falls back to the original only
    /// when the data isn't decodable as an image at all — in which case the
    /// server's own validation is the right place for it to fail.
    static func bound(_ jpeg: Data) -> Data {
        guard let image = UIImage(data: jpeg) else { return jpeg }
        let scaled = downscaled(image, longEdge: maxLongEdge)

        // Step quality down until it fits. Bounded loop, and the last entry is
        // also the floor — we never ship something worse than 0.4.
        let qualities: [CGFloat] = [0.8, 0.7, 0.6, 0.5, 0.4]
        var smallest: Data?
        for quality in qualities {
            guard let out = scaled.jpegData(compressionQuality: quality) else { break }
            smallest = out
            if out.count <= maxBytes { return out }
        }
        return smallest ?? jpeg
    }

    private static func downscaled(_ image: UIImage, longEdge: CGFloat) -> UIImage {
        let width = image.size.width
        let height = image.size.height
        let longest = max(width, height)
        guard longest > longEdge, longest > 0 else { return image }

        let ratio = longEdge / longest
        let size = CGSize(width: (width * ratio).rounded(), height: (height * ratio).rounded())
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1          // size is already in pixels, not points
        format.opaque = true      // a camera frame has no alpha
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
    }
}
