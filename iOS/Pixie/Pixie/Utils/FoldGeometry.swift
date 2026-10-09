import UIKit

/// Where the fold of an iPhone Duo lies inside a view while the device is partially open.
/// Regions are read on every call, since they arrive after the first layout pass and change as
/// the device folds, so nothing here caches a result.
enum FoldGeometry {
    enum Orientation {
        case vertical
        case horizontal
    }

    struct Fold {
        let frame: CGRect
        let orientation: Orientation
    }

    static func activeFold(in view: UIView) -> Fold? {
        #if canImport(UIKit, _version: 9127.0.85)
        if #available(iOS 27.1, *) {
            let regions = view.reservedRegions(kind: .division)
            guard let region = regions.first(where: { $0.isActive }) else { return nil }
            return Fold(frame: region.frame, orientation: orientation(of: region.frame, in: view.bounds))
        }
        #endif
        return nil
    }

    private static func orientation(of frame: CGRect, in bounds: CGRect) -> Orientation {
        frame.height >= bounds.height ? .vertical : .horizontal
    }
}
