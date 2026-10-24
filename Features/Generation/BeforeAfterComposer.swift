import UIKit

/// Renders an original photo and its edit as one shareable image: side by side for
/// portrait shots, stacked for landscape ones, each labelled, with a small app credit.
enum BeforeAfterComposer {
    private static let panelLongEdge: CGFloat = 1400
    private static let gap: CGFloat = 12
    private static let footerHeight: CGFloat = 96

    static func compose(before: UIImage, after: UIImage) -> UIImage {
        let isLandscape = after.size.width > after.size.height
        let panelSize = panelSize(for: after.size)
        let canvasSize: CGSize
        let beforeRect: CGRect
        let afterRect: CGRect
        if isLandscape {
            canvasSize = CGSize(width: panelSize.width, height: panelSize.height * 2 + gap + footerHeight)
            beforeRect = CGRect(origin: .zero, size: panelSize)
            afterRect = CGRect(origin: CGPoint(x: 0, y: panelSize.height + gap), size: panelSize)
        } else {
            canvasSize = CGSize(width: panelSize.width * 2 + gap, height: panelSize.height + footerHeight)
            beforeRect = CGRect(origin: .zero, size: panelSize)
            afterRect = CGRect(origin: CGPoint(x: panelSize.width + gap, y: 0), size: panelSize)
        }

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        return UIGraphicsImageRenderer(size: canvasSize, format: format).image { context in
            UIColor(red: 0.07, green: 0.05, blue: 0.12, alpha: 1).setFill()
            context.fill(CGRect(origin: .zero, size: canvasSize))
            drawAspectFill(before, in: beforeRect, context: context.cgContext)
            drawAspectFill(after, in: afterRect, context: context.cgContext)
            drawBadge(String(localized: "Before"), in: beforeRect)
            drawBadge(String(localized: "After"), in: afterRect)
            drawFooter(in: CGRect(x: 0, y: canvasSize.height - footerHeight, width: canvasSize.width, height: footerHeight))
        }
    }

    private static func panelSize(for size: CGSize) -> CGSize {
        guard size.width > 0, size.height > 0 else { return CGSize(width: panelLongEdge, height: panelLongEdge) }
        let factor = panelLongEdge / max(size.width, size.height)
        return CGSize(width: (size.width * factor).rounded(), height: (size.height * factor).rounded())
    }

    private static func drawAspectFill(_ image: UIImage, in rect: CGRect, context: CGContext) {
        guard image.size.width > 0, image.size.height > 0 else { return }
        let scale = max(rect.width / image.size.width, rect.height / image.size.height)
        let drawSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let origin = CGPoint(x: rect.midX - drawSize.width / 2, y: rect.midY - drawSize.height / 2)
        context.saveGState()
        context.clip(to: rect)
        image.draw(in: CGRect(origin: origin, size: drawSize))
        context.restoreGState()
    }

    private static func drawBadge(_ text: String, in panel: CGRect) {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 40, weight: .bold),
            .foregroundColor: UIColor.white
        ]
        let textSize = (text as NSString).size(withAttributes: attributes)
        let badge = CGRect(x: panel.minX + 28, y: panel.minY + 28, width: textSize.width + 44, height: textSize.height + 20)
        UIColor.black.withAlphaComponent(0.55).setFill()
        UIBezierPath(roundedRect: badge, cornerRadius: badge.height / 2).fill()
        (text as NSString).draw(at: CGPoint(x: badge.minX + 22, y: badge.minY + 10), withAttributes: attributes)
    }

    private static func drawFooter(in rect: CGRect) {
        let credit = String(localized: "Made with PixiePocket")
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 34, weight: .semibold),
            .foregroundColor: UIColor.white.withAlphaComponent(0.9)
        ]
        let size = (credit as NSString).size(withAttributes: attributes)
        (credit as NSString).draw(
            at: CGPoint(x: rect.midX - size.width / 2, y: rect.midY - size.height / 2),
            withAttributes: attributes
        )
    }
}
