import Foundation
import MidgarCore
import Testing
import UIKit

@testable import Pixie

@MainActor
struct ModelFeaturesTests {

    /// A provider that answers what it is told and counts how often it was asked.
    private final class CountingIdeas: PhotoIdeasProviding {
        var answer: Result<[String], PhotoIdeasFailure> = .failure(.unavailableInRegion)
        var asked = 0

        func ideas(for photo: UIImage, language: String) async -> Result<[String], PhotoIdeasFailure> {
            asked += 1
            return answer
        }
    }

    private func photo() -> UIImage {
        UIGraphicsImageRenderer(size: CGSize(width: 40, height: 30)).image { context in
            UIColor.systemTeal.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 40, height: 30))
        }
    }

    @Test func theRegionDecidesBeforeAnythingElseAboutPhotoIdeas() {
        #expect(PhotoIdeasModel.decision(modelsAvailable: false, included: true, agreed: true) == .hidden)
        #expect(PhotoIdeasModel.decision(modelsAvailable: false, included: false, agreed: false) == .hidden)
        #expect(PhotoIdeasModel.decision(modelsAvailable: true, included: false, agreed: true) == .withPlus)
        #expect(PhotoIdeasModel.decision(modelsAvailable: true, included: true, agreed: false) == .offer)
        #expect(PhotoIdeasModel.decision(modelsAvailable: true, included: true, agreed: true) == .ask)
    }

    @Test func aPickedPhotoIsNeverSentWhereModelFeaturesDoNotWork() async {
        let stub = CountingIdeas()
        stub.answer = .success(["Make it autumn"])
        let model = PhotoIdeasModel(
            provider: stub,
            isIncluded: { true },
            hasAgreed: { true },
            agree: {},
            modelsAvailable: { false }
        )
        model.photoChanged(photo())
        #expect(model.state == .hidden)
        #expect(await model.looksWithoutAsking() == false)
        model.ask()
        for _ in 0..<50 {
            try? await Task.sleep(for: .milliseconds(10))
        }
        #expect(stub.asked == 0)
        #expect(model.state == .hidden)
    }

    @Test func aRefusalFromMakoHidesThePhotoIdeasRowWithoutCountingAnything() async {
        let stub = CountingIdeas()
        let model = PhotoIdeasModel(
            provider: stub,
            isIncluded: { true },
            hasAgreed: { true },
            agree: {},
            modelsAvailable: { true }
        )
        model.photoChanged(photo())
        for _ in 0..<200 where stub.asked == 0 {
            try? await Task.sleep(for: .milliseconds(10))
        }
        for _ in 0..<200 where model.state == .loading {
            try? await Task.sleep(for: .milliseconds(10))
        }
        #expect(stub.asked == 1)
        #expect(model.state == .hidden)
    }

    @Test func aRefusedGenerationSaysTheNeutralLineAndIsNotAnOrdinaryFailure() {
        let refused = GenerationError.unavailableInRegion
        #expect(refused.isUnavailableInRegion)
        #expect(refused.localizedDescription == MidgarModelRegion.unavailableMessage)
        #expect(GenerationError.networkError.isUnavailableInRegion == false)
        #expect(GenerationError.serverError(code: 500).isUnavailableInRegion == false)
    }
}
