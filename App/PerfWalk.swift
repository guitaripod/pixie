#if DEBUG
import MidgarCore
import MidgarUI
import UIKit

/// A capture walk for a frame-watch run: with `PX_WALK=<screen>` in the launch environment it
/// names the screen in the frame watch once it is up and pages the first long list down once, so
/// the per-row work lands inside that screen's stretch in pixie.log.
@MainActor
enum PerfWalk {
    private static var walk: Task<Void, Never>?

    static func startIfRequested(environment: [String: String] = ProcessInfo.processInfo.environment) {
        guard let name = environment["PX_WALK"], MidgarFrameWatch.shared.isRunning else { return }
        walk = Task { await run(named: name) }
    }

    private static func run(named name: String) async {
        guard await waitForFirstScreen() else { return }
        MidgarLog.notice("Perf walk \(name) begins", category: .ui)
        try? await Task.sleep(nanoseconds: 1_200_000_000)
        MidgarFrameWatch.shared.report(name)
        for _ in 0..<2 {
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            guard let scrollView = longestScrollView(in: topViewController()?.view) else {
                MidgarLog.notice("Perf walk \(name) found no scroll view", category: .ui)
                return
            }
            let lowest = scrollView.contentSize.height - scrollView.bounds.height + scrollView.contentInset.bottom
            let target = min(lowest, scrollView.contentOffset.y + scrollView.bounds.height * 0.7)
            MidgarLog.notice(
                "Perf walk \(name) scrolls \(type(of: scrollView)) \(Int(scrollView.contentSize.height)) to \(Int(target))",
                category: .ui)
            guard target > scrollView.contentOffset.y + 40 else { return }
            scrollView.setContentOffset(CGPoint(x: scrollView.contentOffset.x, y: target), animated: false)
        }
    }

    /// Waits until the launch's first screen has a window, so the report names the screen rather
    /// than the launch itself.
    private static func waitForFirstScreen() async -> Bool {
        for _ in 0..<40 {
            if let controller = topViewController(), controller.viewIfLoaded?.window != nil {
                return true
            }
            try? await Task.sleep(nanoseconds: 100_000_000)
        }
        return false
    }

    private static var keyWindow: UIWindow? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first(where: \.isKeyWindow)
    }

    private static func topViewController() -> UIViewController? {
        keyWindow?.rootViewController.map(topmost(in:))
    }

    private static func topmost(in controller: UIViewController) -> UIViewController {
        if let presented = controller.presentedViewController { return topmost(in: presented) }
        if let navigation = controller as? UINavigationController, let top = navigation.topViewController {
            return topmost(in: top)
        }
        if let tab = controller as? UITabBarController, let selected = tab.selectedViewController {
            return topmost(in: selected)
        }
        if let split = controller as? UISplitViewController, let last = split.viewControllers.last {
            return topmost(in: last)
        }
        for child in controller.children where child.viewIfLoaded?.window != nil {
            return topmost(in: child)
        }
        return controller
    }

    private static func longestScrollView(in view: UIView?) -> UIScrollView? {
        guard let view else { return nil }
        var found: UIScrollView?
        var pending = [view]
        while let next = pending.popLast() {
            if let scrollView = next as? UIScrollView,
               scrollView.contentSize.height > scrollView.bounds.height + 100,
               scrollView.contentSize.height > (found?.contentSize.height ?? 0) {
                found = scrollView
            }
            pending.append(contentsOf: next.subviews)
        }
        return found
    }
}
#endif
