import Testing
import UIKit

@testable import Pixie

@MainActor
struct ComposerOptionsPanelTests {

    private func hostedBar() -> (ChatInputBar, ComposerOptionsPanel, UIWindow) {
        let bar = ChatInputBar()
        bar.translatesAutoresizingMaskIntoConstraints = false
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 420, height: 900))
        let root = UIViewController()
        window.rootViewController = root
        root.view.addSubview(bar)
        NSLayoutConstraint.activate([
            bar.leadingAnchor.constraint(equalTo: root.view.leadingAnchor),
            bar.trailingAnchor.constraint(equalTo: root.view.trailingAnchor),
            bar.bottomAnchor.constraint(equalTo: root.view.bottomAnchor),
        ])
        window.makeKeyAndVisible()
        root.view.layoutIfNeeded()
        return (bar, panel(in: bar)!, window)
    }

    private func panel(in view: UIView) -> ComposerOptionsPanel? {
        if let panel = view as? ComposerOptionsPanel { return panel }
        for subview in view.subviews {
            if let found = panel(in: subview) { return found }
        }
        return nil
    }

    private func settle(_ seconds: TimeInterval = 0.7) async {
        try? await Task.sleep(for: .seconds(seconds))
    }

    private func optionsButton(in view: UIView) -> ComposerOptionsButton? {
        if let button = view as? ComposerOptionsButton { return button }
        for subview in view.subviews {
            if let found = optionsButton(in: subview) { return found }
        }
        return nil
    }

    @Test(arguments: [0.0, 0.05, 0.2, 0.45, 0.8])
    func thePanelOpensAtItsContentHeightHoweverFastTheButtonIsTapped(gap: Double) async {
        let (bar, panel, window) = hostedBar()
        bar.setEditMode(true, selectedImage: UIImage())
        let button = optionsButton(in: bar)!
        for _ in 0..<5 {
            button.sendActions(for: .touchUpInside)
            await settle(gap)
        }
        await settle(1.5)
        #expect(bar.isExpanded)
        #expect(panel.bounds.height > 150)
        withExtendedLifetime(window) {}
    }

    @Test(arguments: [0.0, 0.05, 0.2, 0.45])
    func thePanelOpensAfterSendingWhileItWasOpen(gap: Double) async {
        let (bar, panel, window) = hostedBar()
        bar.setEditMode(true, selectedImage: UIImage())
        let button = optionsButton(in: bar)!
        button.sendActions(for: .touchUpInside)
        await settle(gap)
        bar.setText("x")
        bar.collapse()
        bar.setGenerating(true)
        await settle(gap)
        bar.setGenerating(false)
        bar.setEditMode(true, selectedImage: UIImage())
        bar.clear()
        await settle(gap)
        button.sendActions(for: .touchUpInside)
        await settle(1.5)
        #expect(bar.isExpanded)
        #expect(panel.bounds.height > 150)
        withExtendedLifetime(window) {}
    }

    @Test func thePanelOpensAtItsContentHeightAfterAnEditWasSent() async {
        let (bar, panel, window) = hostedBar()
        bar.setEditMode(true, selectedImage: UIImage())
        bar.setText("make him smile")
        bar.collapse()
        bar.setGenerating(true)
        await settle()
        bar.setGenerating(false)
        bar.setEditMode(true, selectedImage: UIImage())
        bar.clear()
        await settle()
        bar.expand()
        await settle()
        #expect(!panel.isHidden)
        #expect(panel.bounds.height > 150)
        #expect(!panel.isShortOfItsContent)
        withExtendedLifetime(window) {}
    }

    @Test func thePanelOpensAtItsContentHeightAfterOpeningAndSendingTwice() async {
        let (bar, panel, window) = hostedBar()
        bar.setEditMode(true, selectedImage: UIImage())
        for _ in 0..<2 {
            bar.expand()
            await settle()
            bar.collapse()
            bar.setGenerating(true)
            await settle(0.1)
            bar.setGenerating(false)
            await settle()
        }
        bar.expand()
        await settle()
        #expect(!panel.isHidden)
        #expect(panel.bounds.height > 150)
        withExtendedLifetime(window) {}
    }

    private func cutAnimationsShort(in view: UIView) {
        view.layer.removeAllAnimations()
        view.subviews.forEach(cutAnimationsShort)
    }

    /// Sending closes the panel twice in a row, once for the send and once for the generation starting, and an
    /// alert or the keyboard can cut both animations short: that left the panel at its grabber's height for good.
    @Test func thePanelOpensAfterASendWhoseClosingAnimationsWereCutShort() async {
        let (bar, panel, window) = hostedBar()
        bar.setEditMode(true, selectedImage: UIImage())
        bar.collapse()
        cutAnimationsShort(in: window)
        bar.setGenerating(true)
        cutAnimationsShort(in: window)
        await settle(1)
        bar.setGenerating(false)
        await settle(0.5)
        optionsButton(in: bar)!.sendActions(for: .touchUpInside)
        await settle(1.5)
        #expect(!panel.isHidden)
        #expect(panel.bounds.height > 150)
        #expect(!panel.isShortOfItsContent)
        withExtendedLifetime(window) {}
    }

    @Test func closingThePanelGivesItsSpaceBack() async {
        let (bar, panel, window) = hostedBar()
        let resting = bar.bounds.height
        bar.expand()
        await settle()
        #expect(bar.bounds.height > resting + 150)
        #expect(bar.frame.minY <= bar.convert(panel.frame.origin, to: bar.superview).y + 0.5)
        bar.collapse()
        await settle(1.5)
        #expect(panel.isHidden)
        #expect(abs(bar.bounds.height - resting) < 0.5)
        withExtendedLifetime(window) {}
    }
}
