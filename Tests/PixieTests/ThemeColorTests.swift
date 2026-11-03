import Testing
import UIKit

@testable import Pixie

@MainActor
struct ThemeColorTests {
    @Test func theWindowTintResolvesOffTheMainThreadAsTheShareSheetResolvesIt() async {
        let tint = Theme.Color.accentText
        let (light, dark) = await Task.detached {
            (tint.resolvedColor(with: UITraitCollection(userInterfaceStyle: .light)),
             tint.resolvedColor(with: UITraitCollection(userInterfaceStyle: .dark)))
        }.value

        #expect(light == UIColor(hex: 0x5B38F0))
        #expect(dark == UIColor(hex: 0xA99BFF))
    }
}
