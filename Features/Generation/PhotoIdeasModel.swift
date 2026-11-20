import PixiepocketCore
import UIKit

/// What the row of ideas under a picked photo shows.
enum PhotoIdeasState: Equatable {
    /// No photo is picked, or there is nothing to offer for it.
    case hidden
    /// Ideas are part of what this person has, and they have not yet agreed to a copy of the photo being sent: a
    /// tap agrees and asks.
    case offer
    /// Ideas are not part of what this person has, and they have not yet agreed to a copy of the photo being sent:
    /// a tap agrees and asks for a taste.
    case tasteOffer
    /// mako answered that ideas are not part of what this person has: a tap shows Plus.
    case withPlus
    case loading
    case ideas([String])
    /// A taste for someone without Plus: the first idea, theirs to use, beside the way to the others.
    case taste(idea: String)
    /// Asking failed; a tap asks again.
    case failed
}

/// Why a photo got no ideas.
enum PhotoIdeasFailure: Error, Equatable {
    /// mako answered that ideas are not part of what this person has.
    case notIncluded
    /// Today's allowance of ideas is used.
    case resting
    case unavailable
    /// Midgar's servers refuse model features for the country the device connects from.
    case unavailableInRegion
}

/// Whether the person agreed that a small copy of a picked photo goes to Anthropic's Claude for ideas. It is its own
/// agreement because `CloudAIConsent` names the image providers only; withdrawing that one withdraws this one too.
enum PhotoIdeasConsent {
    private static let key = "photoIdeasConsentGranted"

    static var isGranted: Bool {
        UserDefaults.standard.bool(forKey: key)
    }

    static func grant() {
        UserDefaults.standard.set(true, forKey: key)
    }

    static func withdraw() {
        UserDefaults.standard.set(false, forKey: key)
    }
}

/// Where ideas for a photo come from: mako in the app, a fixed answer in a demo capture and in tests.
protocol PhotoIdeasProviding {
    func ideas(for photo: UIImage, language: String) async -> Result<[String], PhotoIdeasFailure>
}

/// Asks mako's `photo.ideas.v1` alias. Only a copy of the photo downsized to `PhotoIdeas.sentPixels` is sent, and
/// only ideas that pass `PhotoIdeas.settle` come back.
struct MakoPhotoIdeas: PhotoIdeasProviding {
    let api: any APIServiceProtocol

    func ideas(for photo: UIImage, language: String) async -> Result<[String], PhotoIdeasFailure> {
        guard let jpeg = Self.smallCopy(of: photo) else { return .failure(.unavailable) }
        do {
            let reply = try await api.photoIdeas(PhotoIdeasRequest(jpeg: jpeg, language: language, idempotencyKey: UUID().uuidString))
            let ideas = PhotoIdeas.settle(reply: reply.content)
            return ideas.isEmpty ? .failure(.unavailable) : .success(ideas)
        } catch NetworkError.unavailableInRegion {
            return .failure(.unavailableInRegion)
        } catch NetworkError.insufficientCredits {
            return .failure(.notIncluded)
        } catch NetworkError.tooManyRequests {
            return .failure(.resting)
        } catch {
            return .failure(.unavailable)
        }
    }

    /// The photo redrawn upright with its longest side at `PhotoIdeas.sentPixels`, as a JPEG of a few tens of
    /// kilobytes: enough to see what it shows.
    static func smallCopy(of photo: UIImage) -> Data? {
        let pixels = CGSize(width: photo.size.width * photo.scale, height: photo.size.height * photo.scale)
        let longest = max(pixels.width, pixels.height)
        guard longest > 0 else { return nil }
        let factor = min(1, CGFloat(PhotoIdeas.sentPixels) / longest)
        let target = CGSize(width: max(1, (pixels.width * factor).rounded()), height: max(1, (pixels.height * factor).rounded()))
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let small = UIGraphicsImageRenderer(size: target, format: format).image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: target))
            photo.draw(in: CGRect(origin: .zero, size: target))
        }
        return small.jpegData(compressionQuality: 0.7)
    }
}

/// Holds the ideas for the photo of the current edit. Ideas are part of Plus and of the Pixie Week, and cost that
/// person nothing: once they have agreed to a small copy of the photo being sent, ideas are asked for as soon as a
/// photo is picked, and until then the row offers them and nothing is sent. Everyone else gets a taste on the same
/// terms: the model suggests the same three edits, the row shows the first for them to use and keeps the others
/// for Plus, which shows them at once without asking again. A photo is asked about once: its ideas are kept while
/// it stays picked and come back if it is picked again.
@MainActor
final class PhotoIdeasModel {

    private(set) var state: PhotoIdeasState = .hidden
    /// Called on the main actor whenever `state` changed.
    var onChange: (() -> Void)?

    private let provider: any PhotoIdeasProviding
    private let isIncluded: @MainActor () async -> Bool
    private let hasAgreed: @MainActor () -> Bool
    private let agree: @MainActor () -> Void
    private let modelsAvailable: @MainActor () -> Bool
    private let language: String
    private var photo: UIImage?
    private var answered: [(photo: UIImage, ideas: [String], asTaste: Bool)] = []
    private var generation = 0
    private var refusedByServer = false

    /// How many photos keep their ideas, so going back to a photo picked a moment ago asks nothing.
    private static let rememberedPhotos = 4

    /// The model the app uses: mako, the balance's word on Plus and the Pixie Week, and the stored agreement. In a
    /// DEBUG demo capture the answer is fixed and `PX_IDEAS` picks the row: `offer` before the agreement, `plus` the
    /// taste of someone without ideas, anything else the ideas themselves. The capture's agreement lasts for the
    /// launch only (`DemoIdeasAgreement`), so one run on a phone in real use leaves that person's own answer alone.
    static func standard() -> PhotoIdeasModel {
        #if DEBUG
        if DemoMode.isActive {
            let row = ProcessInfo.processInfo.environment["PX_IDEAS"]
            let agreement = DemoIdeasAgreement(isGranted: row != "offer")
            return PhotoIdeasModel(
                provider: DemoPhotoIdeas(),
                isIncluded: { row != "plus" },
                hasAgreed: { agreement.isGranted },
                agree: { agreement.isGranted = true })
        }
        #endif
        return PhotoIdeasModel(provider: MakoPhotoIdeas(api: APIService.shared), isIncluded: {
            await balanceIncludesIdeas()
        })
    }

    /// The balance's word on Plus and the Pixie Week, read from the server first when the app has no balance yet so
    /// a photo picked right after launch is not shown the Plus chip in a Pixie Week; a server too old to say falls
    /// back to the ledger's Plus.
    private static func balanceIncludesIdeas() async -> Bool {
        if CreditBalanceStore.shared.balance == nil { await CreditBalanceStore.shared.refresh() }
        if let edits = CreditBalanceStore.shared.balance?.edits { return edits.includesPhotoIdeas }
        return await CreditPurchaseManager.shared.hasPlus()
    }

    /// What a picked photo's row offers once the answers are in: nothing where model features do not work, the offer
    /// before agreement, of ideas or for someone without them of a taste, and a request once agreed.
    enum Decision: Equatable {
        case hidden
        case tasteOffer
        case offer
        case ask
    }

    static func decision(modelsAvailable: Bool, included: Bool, agreed: Bool) -> Decision {
        guard modelsAvailable else { return .hidden }
        guard agreed else { return included ? .offer : .tasteOffer }
        return .ask
    }

    /// What the row shows for ideas that came back: all of them for someone who has ideas, the first one for
    /// someone given a taste. One idea alone leaves nothing to keep back, so it is simply shown.
    static func shown(_ ideas: [String], asTaste: Bool) -> PhotoIdeasState {
        guard asTaste, ideas.count > 1, let first = ideas.first else { return .ideas(ideas) }
        return .taste(idea: first)
    }

    init(
        provider: any PhotoIdeasProviding,
        language: String = PhotoIdeasModel.languageName,
        isIncluded: @escaping @MainActor () async -> Bool,
        hasAgreed: @escaping @MainActor () -> Bool = { PhotoIdeasConsent.isGranted },
        agree: @escaping @MainActor () -> Void = { PhotoIdeasConsent.grant() },
        modelsAvailable: @escaping @MainActor () -> Bool = { ModelFeatures.isAvailable }
    ) {
        self.provider = provider
        self.language = language
        self.isIncluded = isIncluded
        self.hasAgreed = hasAgreed
        self.agree = agree
        self.modelsAvailable = modelsAvailable
    }

    /// The English name of the language the app is shown in, which the ideas are written in.
    static var languageName: String {
        let code = Bundle.main.preferredLocalizations.first ?? "en"
        return Locale(identifier: "en_US").localizedString(forIdentifier: code) ?? "English"
    }

    /// Whether a picked photo is looked at without a further tap: the person has agreed, whether what comes back is
    /// every idea or a taste.
    func looksWithoutAsking() async -> Bool {
        modelsAvailable() && hasAgreed()
    }

    /// Tells the model which photo the edit is about, or that there is none.
    func photoChanged(_ newPhoto: UIImage?) {
        guard newPhoto !== photo else { return }
        photo = newPhoto
        generation += 1
        refusedByServer = false
        guard let newPhoto, modelsAvailable() else { return set(.hidden) }
        if let known = answered.first(where: { $0.photo === newPhoto }) {
            set(Self.shown(known.ideas, asTaste: known.asTaste))
            if known.asTaste { openTasteIfIncluded() }
            return
        }
        set(.hidden)
        decide()
    }

    /// Decides again what the row offers for the picked photo once what the person has may have changed: Plus just
    /// bought from the chip, a balance that just arrived. A taste on screen opens into every idea, and an offer of a
    /// taste becomes the offer of ideas. A row the server itself refused stays as it is.
    func accessChanged() {
        guard photo != nil, !refusedByServer else { return }
        switch state {
        case .taste: openTasteIfIncluded()
        case .tasteOffer: decide()
        case .hidden, .offer, .withPlus, .loading, .ideas, .failed: break
        }
    }

    /// Shows the offer or asks for the picked photo, by what the person has and has agreed to.
    private func decide() {
        let current = generation
        Task { [weak self] in
            guard let self else { return }
            let included = await isIncluded()
            guard current == generation else { return }
            switch Self.decision(modelsAvailable: modelsAvailable(), included: included, agreed: hasAgreed()) {
            case .hidden: set(.hidden)
            case .tasteOffer: set(.tasteOffer)
            case .offer: set(.offer)
            case .ask: ask()
            }
        }
    }

    /// Shows every idea of the picked photo's taste once ideas are part of what the person has. The ideas were kept
    /// when the taste was given, so nothing is asked again.
    private func openTasteIfIncluded() {
        let current = generation
        Task { [weak self] in
            guard let self, await isIncluded(), current == generation, let photo,
                  let place = answered.firstIndex(where: { $0.photo === photo && $0.asTaste })
            else { return }
            answered[place].asTaste = false
            set(.ideas(answered[place].ideas))
        }
    }

    /// Records that the person agreed to a small copy of the photo being sent and asks: a tap on the offer.
    func agreeAndAsk() {
        agree()
        ask()
    }

    /// Asks for ideas for the photo, as an agreed pick or a tap on a failed row does.
    func ask() {
        guard let photo, state != .loading, hasAgreed(), modelsAvailable() else { return }
        generation += 1
        let current = generation
        set(.loading)
        Task { [weak self, provider, language] in
            let result = await provider.ideas(for: photo, language: language)
            guard let self, current == generation else { return }
            switch result {
            case .success(let ideas):
                let asTaste = !(await isIncluded())
                guard current == generation else { return }
                remember(ideas, for: photo, asTaste: asTaste)
                set(Self.shown(ideas, asTaste: asTaste))
            case .failure(.notIncluded):
                refusedByServer = true
                set(.withPlus)
            case .failure(.resting):
                set(.hidden)
            case .failure(.unavailable):
                set(.failed)
            case .failure(.unavailableInRegion):
                set(.hidden)
            }
        }
    }

    private func remember(_ ideas: [String], for photo: UIImage, asTaste: Bool) {
        answered.removeAll { $0.photo === photo }
        answered.append((photo, ideas, asTaste))
        if answered.count > Self.rememberedPhotos { answered.removeFirst(answered.count - Self.rememberedPhotos) }
    }

    private func set(_ new: PhotoIdeasState) {
        guard new != state else { return }
        state = new
        onChange?()
    }
}

#if DEBUG
/// Whether a demo capture has agreed to a photo being looked at, kept in memory instead of with the stored agreement.
@MainActor
final class DemoIdeasAgreement {
    var isGranted: Bool

    init(isGranted: Bool) {
        self.isGranted = isGranted
    }
}

/// The ideas of a demo capture, written for the demo selfie, so a capture never reaches the network.
struct DemoPhotoIdeas: PhotoIdeasProviding {
    /// How long the capture's answer takes: 600 ms, or `PX_IDEAS_DELAY_MS` when a run on a device wants the row to
    /// arrive only after a profiler has attached.
    private static var delay: Duration {
        .milliseconds(ProcessInfo.processInfo.environment["PX_IDEAS_DELAY_MS"].flatMap(Int.init) ?? 600)
    }

    func ideas(for photo: UIImage, language: String) async -> Result<[String], PhotoIdeasFailure> {
        try? await Task.sleep(for: Self.delay)
        return .success([
            String(localized: "Move her to a rooftop at sunset"),
            String(localized: "Make it a watercolour portrait"),
            String(localized: "Add round reading glasses"),
        ])
    }
}
#endif
