import MidgarUI
import UIKit

/// The About screen behind the Support section of Settings: MidgarUI's plain rows for the legal links and the
/// version, drawn with Pixie's colors.
enum AboutSettings {
    static let privacyPolicyURL = URL(string: "https://midgarcorp.cc/legal/pixiepocket/privacy/")!
    static let termsOfUseURL = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!

    @MainActor
    static func makeViewController() -> UIViewController {
        MidgarSettingsViewController(
            title: String(localized: "About"),
            sections: [
                MidgarSettingsSection(id: "legal", rows: [.privacyPolicy(url: privacyPolicyURL), .termsOfUse(url: termsOfUseURL)]),
                MidgarSettingsSection(id: "version", rows: [.version()]),
            ],
            theme: .pixie
        )
    }
}

extension MidgarTheme {
    /// Pixie's look: the violet accent on the app's own canvas and surface colors, light and dark.
    nonisolated static let pixie = MidgarTheme(
        accent: MidgarColor(lightHex: 0x5B38F0, darkHex: 0xA99BFF),
        background: MidgarColor(lightHex: 0xF6F4FA, darkHex: 0x0B0A12),
        surface: MidgarColor(lightHex: 0xFFFFFF, darkHex: 0x15131F)
    )
}
