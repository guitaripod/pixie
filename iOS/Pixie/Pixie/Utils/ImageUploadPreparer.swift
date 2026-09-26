import UIKit

/// Shrinks a picked photo to what the image models actually use before it is uploaded.
/// A full-resolution iPhone photo encoded as PNG is 15–25 MB, slow on cellular and past
/// Gemini's 20 MB inline-request limit, while the models work at about 1–2K anyway.
enum ImageUploadPreparer {
    struct Prepared {
        let data: Data
        let mimeType: String
        let fileExtension: String
    }

    static let maxLongEdge: CGFloat = 2048

    static func prepare(_ image: UIImage) -> Prepared? {
        let normalized = normalized(image)
        if hasAlpha(normalized), let png = normalized.pngData() {
            return Prepared(data: png, mimeType: "image/png", fileExtension: "png")
        }
        guard let jpeg = normalized.jpegData(compressionQuality: 0.9) else { return nil }
        return Prepared(data: jpeg, mimeType: "image/jpeg", fileExtension: "jpg")
    }

    static func mimeType(forFileExtension fileExtension: String) -> String {
        switch fileExtension.lowercased() {
        case "jpg", "jpeg": return "image/jpeg"
        case "webp": return "image/webp"
        case "heic": return "image/heic"
        default: return "image/png"
        }
    }

    /// Redraws the image upright and no larger than `maxLongEdge` pixels, so the encoded
    /// file carries no orientation flag the server could ignore.
    private static func normalized(_ image: UIImage) -> UIImage {
        let pixelSize = CGSize(width: image.size.width * image.scale, height: image.size.height * image.scale)
        let longEdge = max(pixelSize.width, pixelSize.height)
        guard longEdge > 0 else { return image }
        guard longEdge > maxLongEdge || image.imageOrientation != .up else { return image }
        let factor = min(1, maxLongEdge / longEdge)
        let target = CGSize(width: (pixelSize.width * factor).rounded(), height: (pixelSize.height * factor).rounded())
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = !hasAlpha(image)
        return UIGraphicsImageRenderer(size: target, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: target))
        }
    }

    private static func hasAlpha(_ image: UIImage) -> Bool {
        switch image.cgImage?.alphaInfo {
        case .first, .last, .premultipliedFirst, .premultipliedLast: return true
        default: return false
        }
    }
}
