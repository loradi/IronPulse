import UIKit

func resizedProfilePhotoData(from image: UIImage, targetSize: CGFloat = 512) -> Data? {
    guard image.size.width > 0, image.size.height > 0 else { return nil }

    let format = UIGraphicsImageRendererFormat()
    format.scale = 1.0
    let renderer = UIGraphicsImageRenderer(size: CGSize(width: targetSize, height: targetSize), format: format)
    return renderer.jpegData(withCompressionQuality: 0.8) { _ in
        let aspectFillScale = max(targetSize / image.size.width, targetSize / image.size.height)
        let scaledSize = CGSize(
            width: image.size.width * aspectFillScale,
            height: image.size.height * aspectFillScale
        )
        let origin = CGPoint(
            x: (targetSize - scaledSize.width) / 2,
            y: (targetSize - scaledSize.height) / 2
        )
        image.draw(in: CGRect(origin: origin, size: scaledSize))
    }
}
