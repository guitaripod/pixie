import Foundation
import Testing

@testable import Pixie

@MainActor
struct ConfigurationManagerTests {
    @Test func theBaseURLIsTheGatewayWhateverAnOldBuildStored() {
        UserDefaults.standard.set("https://mako.midgarcorp.cc", forKey: "pixie.baseURL")

        ConfigurationManager.shared.load()

        #expect(ConfigurationManager.shared.baseURL == "https://api.midgarcorp.cc/v1/intelligence")
        #expect(UserDefaults.standard.object(forKey: "pixie.baseURL") == nil)
    }
}
