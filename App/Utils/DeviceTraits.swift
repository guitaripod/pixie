import UIKit

extension UITraitCollection {
    var isRegularWidth: Bool {
        return horizontalSizeClass == .regular
    }

    var isRegularHeight: Bool {
        return verticalSizeClass == .regular
    }
}

enum AdaptiveLayout {
    case compact
    case regular
    case spacious

    init(traitCollection: UITraitCollection) {
        if traitCollection.isRegularWidth && traitCollection.isRegularHeight {
            self = .spacious
        } else if traitCollection.isRegularWidth {
            self = .regular
        } else {
            self = .compact
        }
    }

    /// Columns for an image grid in a container of this width. Wide containers always get an
    /// even count so no column sits on the fold when the window is divided in book pose.
    func galleryColumns(containerWidth: CGFloat) -> Int {
        let fitted = Int(containerWidth / Self.targetCellWidth)
        switch self {
        case .compact:
            return max(3, fitted)
        case .regular, .spacious:
            let columns = containerWidth < Self.narrowContainerWidth ? max(2, fitted) : max(4, fitted)
            return columns + columns % 2
        }
    }

    var contentInsets: UIEdgeInsets {
        switch self {
        case .compact:
            return .zero
        case .regular:
            return UIEdgeInsets(top: 0, left: 40, bottom: 0, right: 40)
        case .spacious:
            return UIEdgeInsets(top: 0, left: 60, bottom: 0, right: 60)
        }
    }

    private static let targetCellWidth: CGFloat = 150
    private static let narrowContainerWidth: CGFloat = 400
}
