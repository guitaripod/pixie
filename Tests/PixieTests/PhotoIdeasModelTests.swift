import Foundation
import Testing
import UIKit

@testable import Pixie

@MainActor
struct PhotoIdeasModelTests {

    /// A provider that answers what it is told and counts how often it was asked.
    private final class StubIdeas: PhotoIdeasProviding {
        var answer: Result<[String], PhotoIdeasFailure> = .success(["Make it autumn", "Paint it in oils", "Add a red scarf"])
        var asked = 0
        var languages: [String] = []

        func ideas(for photo: UIImage, language: String) async -> Result<[String], PhotoIdeasFailure> {
            asked += 1
            languages.append(language)
            return answer
        }
    }

    private func photo() -> UIImage {
        UIGraphicsImageRenderer(size: CGSize(width: 40, height: 30)).image { context in
            UIColor.systemTeal.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 40, height: 30))
        }
    }

    /// An agreement kept in memory, so a test never writes the app's own.
    private final class Agreement {
        var given: Bool
        init(_ given: Bool) { self.given = given }
    }

    private let ideas = ["Make it autumn", "Paint it in oils", "Add a red scarf"]

    private func model(_ stub: StubIdeas, included: Bool, agreement: Agreement, language: String = "English") -> PhotoIdeasModel {
        PhotoIdeasModel(provider: stub, language: language, isIncluded: { included }, hasAgreed: { agreement.given }, agree: { agreement.given = true })
    }

    /// Waits until the model leaves `state`, or two seconds.
    private func settle(_ model: PhotoIdeasModel, leaving state: PhotoIdeasState) async {
        for _ in 0..<200 where model.state == state {
            try? await Task.sleep(for: .milliseconds(10))
        }
    }

    @Test func onceAgreedAPickedPhotoIsLookedAtAtOnce() async {
        let stub = StubIdeas()
        let model = model(stub, included: true, agreement: Agreement(true), language: "Finnish")
        model.photoChanged(photo())
        await settle(model, leaving: .hidden)
        await settle(model, leaving: .loading)
        #expect(model.state == .ideas(ideas))
        #expect(stub.asked == 1)
        #expect(stub.languages == ["Finnish"])
        #expect(await model.looksWithoutAsking())
    }

    @Test func nothingIsSentBeforeThePersonAgreesAndTheAgreementIsKept() async {
        let stub = StubIdeas()
        let agreement = Agreement(false)
        let model = model(stub, included: true, agreement: agreement)
        model.photoChanged(photo())
        await settle(model, leaving: .hidden)
        try? await Task.sleep(for: .milliseconds(80))
        #expect(model.state == .offer)
        #expect(stub.asked == 0)
        #expect(await model.looksWithoutAsking() == false)
        model.ask()
        #expect(model.state == .offer)
        #expect(stub.asked == 0)
        model.agreeAndAsk()
        #expect(agreement.given)
        #expect(model.state == .loading)
        await settle(model, leaving: .loading)
        #expect(model.state == .ideas(ideas))
        #expect(stub.asked == 1)
        #expect(await model.looksWithoutAsking())
    }

    @Test func withoutPlusOrThePixieWeekTheRowShowsPlusAndSendsNothing() async {
        let stub = StubIdeas()
        let model = model(stub, included: false, agreement: Agreement(true))
        model.photoChanged(photo())
        await settle(model, leaving: .hidden)
        #expect(model.state == .withPlus)
        try? await Task.sleep(for: .milliseconds(80))
        #expect(stub.asked == 0)
        #expect(await model.looksWithoutAsking() == false)
    }

    @Test func aPhotoIsAskedAboutOnceAndItsIdeasComeBackWhenItIsPickedAgain() async {
        let stub = StubIdeas()
        let model = model(stub, included: true, agreement: Agreement(true))
        let first = photo()
        model.photoChanged(first)
        await settle(model, leaving: .hidden)
        await settle(model, leaving: .loading)
        model.photoChanged(first)
        #expect(stub.asked == 1)
        model.photoChanged(nil)
        #expect(model.state == .hidden)
        model.photoChanged(first)
        #expect(model.state == .ideas(ideas))
        #expect(stub.asked == 1)
        model.photoChanged(photo())
        await settle(model, leaving: .hidden)
        await settle(model, leaving: .loading)
        #expect(stub.asked == 2)
    }

    @Test func aFailureCanBeTriedAgain() async {
        let stub = StubIdeas()
        stub.answer = .failure(.unavailable)
        let model = model(stub, included: true, agreement: Agreement(true))
        model.photoChanged(photo())
        await settle(model, leaving: .hidden)
        await settle(model, leaving: .loading)
        #expect(model.state == .failed)
        stub.answer = .success(["Make it winter"])
        model.ask()
        await settle(model, leaving: .loading)
        #expect(model.state == .ideas(["Make it winter"]))
        #expect(stub.asked == 2)
    }

    @Test func aServerThatSaysIdeasAreNotIncludedShowsPlusAndAUsedUpDayShowsNothing() async {
        let stub = StubIdeas()
        stub.answer = .failure(.notIncluded)
        let model = model(stub, included: true, agreement: Agreement(true))
        model.photoChanged(photo())
        await settle(model, leaving: .hidden)
        await settle(model, leaving: .loading)
        #expect(model.state == .withPlus)
        stub.answer = .failure(.resting)
        model.photoChanged(photo())
        await settle(model, leaving: .withPlus)
        await settle(model, leaving: .loading)
        #expect(model.state == .hidden)
    }

    @Test func ideasForAPhotoThatIsNoLongerPickedAreDropped() async {
        let stub = StubIdeas()
        let model = model(stub, included: true, agreement: Agreement(true))
        model.photoChanged(photo())
        await settle(model, leaving: .hidden)
        model.photoChanged(nil)
        try? await Task.sleep(for: .milliseconds(80))
        #expect(model.state == .hidden)
    }

    @Test func withdrawingCloudAIConsentWithdrawsTheAgreementToIdeasToo() {
        let cloud = CloudAIConsent.isGranted
        let photoIdeas = PhotoIdeasConsent.isGranted
        defer {
            if cloud { CloudAIConsent.grant() } else { CloudAIConsent.withdraw() }
            if photoIdeas { PhotoIdeasConsent.grant() } else { PhotoIdeasConsent.withdraw() }
        }
        CloudAIConsent.grant()
        PhotoIdeasConsent.grant()
        #expect(PhotoIdeasConsent.isGranted)
        CloudAIConsent.withdraw()
        #expect(!PhotoIdeasConsent.isGranted)
        CloudAIConsent.grant()
        #expect(!PhotoIdeasConsent.isGranted)
    }

    @Test func theCopySentIsSmallUprightAndAJPEG() throws {
        let large = UIGraphicsImageRenderer(size: CGSize(width: 3000, height: 2000)).image { context in
            UIColor.systemOrange.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 3000, height: 2000))
        }
        let data = try #require(MakoPhotoIdeas.smallCopy(of: large))
        let small = try #require(UIImage(data: data))
        #expect(max(small.size.width * small.scale, small.size.height * small.scale) == 512)
        #expect(data.prefix(3) == Data([0xFF, 0xD8, 0xFF]))
        #expect(data.count < 60_000)
    }

    @Test func everyStateOfTheRowHasItsWords() {
        #expect(PhotoIdeasCopy.title(of: .idea("Make it autumn")) == "Make it autumn")
        #expect(PhotoIdeasCopy.title(of: .offer) == "Suggest 3 Edits")
        #expect(PhotoIdeasCopy.title(of: .plus) == "See Plus")
        #expect(PhotoIdeasCopy.subtitle(for: .offer) == PhotoIdeasCopy.sharing)
        #expect(PhotoIdeasCopy.sharing.contains("Anthropic"))
        #expect(PhotoIdeasCopy.subtitle(for: .withPlus) == "With Plus, Pixie looks at your photo and suggests three edits")
        #expect(PhotoIdeasCopy.subtitle(for: .ideas(["x"])) == "Pixie looked at your photo. Tap one to use it")
        #expect(PhotoIdeasCopy.subtitle(for: .loading) == nil)
    }
}
