import UIKit

extension UIImage {
    /// Scales the image down so neither dimension exceeds `maxDimension`.
    /// Returns `self` unchanged if already within bounds.
    func resizedForUpload(maxDimension: CGFloat = 800) -> UIImage {
        let maxSide = max(size.width, size.height)
        guard maxSide > maxDimension else { return self }
        let scale = maxDimension / maxSide
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}
