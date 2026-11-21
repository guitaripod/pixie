import Testing
import UIKit

@testable import Pixie

@MainActor
struct SettingsRowTouchTests {

    private func hostedRow(with toggle: UISwitch) -> (SettingsRowView, UIWindow) {
        let row = SettingsRowView(title: "Photo Ideas", subtitle: "Sends a small copy", symbol: "sparkles")
        row.setAccessory(toggle)
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 700, height: 200))
        let root = UIViewController()
        window.rootViewController = root
        root.view.addSubview(row)
        NSLayoutConstraint.activate([
            row.leadingAnchor.constraint(equalTo: root.view.leadingAnchor),
            row.trailingAnchor.constraint(equalTo: root.view.trailingAnchor),
            row.topAnchor.constraint(equalTo: root.view.topAnchor),
        ])
        window.makeKeyAndVisible()
        root.view.layoutIfNeeded()
        return (row, window)
    }

    @Test func aTouchOnTheSwitchReachesTheSwitch() {
        let toggle = UISwitch()
        let (row, window) = hostedRow(with: toggle)
        withExtendedLifetime(window) {
            let inSwitch = CGPoint(x: toggle.bounds.midX, y: toggle.bounds.midY)
            let hit = row.hitTest(row.convert(inSwitch, from: toggle), with: nil)
            #expect(hit != nil)
            #expect(hit === toggle.hitTest(inSwitch, with: nil))
        }
    }

    @Test func aTouchOnTheTitleStaysWithTheRow() {
        let toggle = UISwitch()
        let (row, window) = hostedRow(with: toggle)
        withExtendedLifetime(window) {
            #expect(row.hitTest(CGPoint(x: 80, y: row.bounds.midY), with: nil) === row)
        }
    }
}
