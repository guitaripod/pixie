import UIKit

/// What the home edge fade is drawn from: the mask holds what a layout pass gives it, and
/// rewriting the same colours and stops again makes the compositor re-mask the whole grid for
/// nothing.
struct EdgeFadeInputs: Equatable {
    let height: CGFloat
    let top: CGFloat
    let bottom: CGFloat
}
