import UIKit

extension UIImage {
    /// Scales the image down so neither dimension exceeds `maxDimension`.
    /// Returns `self` unchanged if already within bounds.
    func resizedForUpload(maxDimension: CGFloat = 800) -> UIImage {
        // Measure in actual pixels (size is in points; scale converts to pixels)
        let pixelW = size.width * scale
        let pixelH = size.height * scale
        let maxSide = max(pixelW, pixelH)
        guard maxSide > maxDimension else { return self }
        let ratio = maxDimension / maxSide
        let newSize = CGSize(width: (pixelW * ratio).rounded(), height: (pixelH * ratio).rounded())
        // scale = 1.0 so the renderer produces exactly newSize pixels, not newSize * screenScale
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1.0
        let renderer = UIGraphicsImageRenderer(size: newSize, format: format)
        return renderer.image { _ in draw(in: CGRect(origin: .zero, size: newSize)) }
    }
}
