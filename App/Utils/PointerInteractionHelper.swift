import UIKit

@available(iOS 13.4, *)
class PointerInteractionHelper {
    
    static func addPointerInteraction(to button: UIButton) {
        button.isPointerInteractionEnabled = true
        button.pointerStyleProvider = { button, proposedEffect, proposedShape -> UIPointerStyle? in
            var rect = button.bounds.insetBy(dx: -8, dy: -8)
            rect = button.convert(rect, to: proposedEffect.preview.target.container)
            return UIPointerStyle(effect: proposedEffect, shape: .roundedRect(rect, radius: 8))
        }
    }
    
    static func addPointerInteraction(to view: UIView, scale: CGFloat = 1.05) {
        let interaction = UIPointerInteraction(delegate: PointerInteractionDelegate(scale: scale))
        view.addInteraction(interaction)
    }
    
    static func configureForCollection(_ collectionView: UICollectionView) {
    }
}

@available(iOS 13.4, *)
private class PointerInteractionDelegate: NSObject, UIPointerInteractionDelegate {
    let scale: CGFloat
    
    init(scale: CGFloat) {
        self.scale = scale
    }
    
    func pointerInteraction(_ interaction: UIPointerInteraction, regionFor request: UIPointerRegionRequest, defaultRegion: UIPointerRegion) -> UIPointerRegion? {
        return defaultRegion
    }
    
    func pointerInteraction(_ interaction: UIPointerInteraction, styleFor region: UIPointerRegion) -> UIPointerStyle? {
        guard let view = interaction.view else { return nil }
        
        let preview = UITargetedPreview(view: view)
        let effect = UIPointerEffect.lift(preview)
        let shape = UIPointerShape.roundedRect(view.bounds, radius: 8)
        
        return UIPointerStyle(effect: effect, shape: shape)
    }
}

extension UIButton {
    func setupPointerInteraction() {
        if #available(iOS 13.4, *) {
            PointerInteractionHelper.addPointerInteraction(to: self)
        }
    }
}

extension UICollectionViewCell {
    func setupPointerInteraction() {
        if #available(iOS 13.4, *) {
            PointerInteractionHelper.addPointerInteraction(to: self)
        }
    }
}