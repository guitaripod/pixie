import PixiepocketCore
import UIKit

/// What the row of ideas under a picked photo shows.
enum PhotoIdeasState: Equatable {
    /// No photo is picked, or there is nothing to offer for it.
    case hidden
    /// Ideas are part of what this person has, and they have not yet agreed to a copy of the photo being sent: a
    /// tap agrees and asks.
    case offer
    /// Ideas are not part of what this person has: a tap shows Plus.
    case withPlus
    case loading
    case ideas([String])
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
/// photo is picked, and until then the row offers them and nothing is sent. Everyone else is shown that ideas come
/// with Plus. A photo is asked about once: its ideas are kept while it stays picked and come back if it is picked
/// again.
@MainActor
final class PhotoIdeasModel {

    private(set) var state: PhotoIdeasState = .hidden
    /// Called on the main actor whenever `state` changed.
    var onChange: (() -> Void)?

    private let provider: any PhotoIdeasProviding
    private let isIncluded: @MainActor () async -> Bool
    private let hasAgreed: @MainActor () -> Bool
    private let agree: @MainActor () -> Void
    private let language: String
    private var photo: UIImage?
    private var answered: [(photo: UIImage, ideas: [String])] = []
    private var generation = 0

    /// How many photos keep their ideas, so going back to a photo picked a moment ago asks nothing.
    private static let rememberedPhotos = 4

    /// The model the app uses: mako, the balance's word on Plus and the Pixie Week, and the stored agreement. In a
    /// DEBUG demo capture the answer is fixed and `PX_IDEAS` picks the row: `offer` before the agreement, `plus` for
    /// someone without ideas, anything else the ideas themselves.
    static func standard() -> PhotoIdeasModel {
        #if DEBUG
        if DemoMode.isActive {
            let row = ProcessInfo.processInfo.environment["PX_IDEAS"]
            if row == "offer" { PhotoIdeasConsent.withdraw() } else { PhotoIdeasConsent.grant() }
            return PhotoIdeasModel(provider: DemoPhotoIdeas(), isIncluded: { row != "plus" })
        }
        #endif
        return PhotoIdeasModel(provider: MakoPhotoIdeas(api: APIService.shared), isIncluded: {
            if let edits = CreditBalanceStore.shared.balance?.edits { return edits.includesPhotoIdeas }
            return await CreditPurchaseManager.shared.hasPlus()
        })
    }

    init(
        provider: any PhotoIdeasProviding,
        language: String = PhotoIdeasModel.languageName,
        isIncluded: @escaping @MainActor () async -> Bool,
        hasAgreed: @escaping @MainActor () -> Bool = { PhotoIdeasConsent.isGranted },
        agree: @escaping @MainActor () -> Void = { PhotoIdeasConsent.grant() }
    ) {
        self.provider = provider
        self.language = language
        self.isIncluded = isIncluded
        self.hasAgreed = hasAgreed
        self.agree = agree
    }

    /// The English name of the language the app is shown in, which the ideas are written in.
    static var languageName: String {
        let code = Bundle.main.preferredLocalizations.first ?? "en"
        return Locale(identifier: "en_US").localizedString(forIdentifier: code) ?? "English"
    }

    /// Whether a picked photo is looked at without a further tap: ideas are part of what the person has and they
    /// have agreed.
    func looksWithoutAsking() async -> Bool {
        guard hasAgreed() else { return false }
        return await isIncluded()
    }

    /// Tells the model which photo the edit is about, or that there is none.
    func photoChanged(_ newPhoto: UIImage?) {
        guard newPhoto !== photo else { return }
        photo = newPhoto
        generation += 1
        guard let newPhoto else { return set(.hidden) }
        if let known = answered.first(where: { $0.photo === newPhoto }) { return set(.ideas(known.ideas)) }
        set(.hidden)
        let current = generation
        Task { [weak self] in
            guard let self else { return }
            let included = await isIncluded()
            guard current == generation else { return }
            if !included {
                set(.withPlus)
            } else if hasAgreed() {
                ask()
            } else {
                set(.offer)
            }
        }
    }

    /// Records that the person agreed to a small copy of the photo being sent and asks: a tap on the offer.
    func agreeAndAsk() {
        agree()
        ask()
    }

    /// Asks for ideas for the photo, as an agreed pick or a tap on a failed row does.
    func ask() {
        guard let photo, state != .loading, hasAgreed() else { return }
        generation += 1
        let current = generation
        set(.loading)
        Task { [weak self, provider, language] in
            let result = await provider.ideas(for: photo, language: language)
            guard let self, current == generation else { return }
            switch result {
            case .success(let ideas):
                remember(ideas, for: photo)
                set(.ideas(ideas))
            case .failure(.notIncluded):
                set(.withPlus)
            case .failure(.resting):
                set(.hidden)
            case .failure(.unavailable):
                set(.failed)
            }
        }
    }

    private func remember(_ ideas: [String], for photo: UIImage) {
        answered.removeAll { $0.photo === photo }
        answered.append((photo, ideas))
        if answered.count > Self.rememberedPhotos { answered.removeFirst(answered.count - Self.rememberedPhotos) }
    }

    private func set(_ new: PhotoIdeasState) {
        guard new != state else { return }
        state = new
        onChange?()
    }
}

#if DEBUG
/// The ideas of a demo capture, written for the demo selfie, so a capture never reaches the network.
struct DemoPhotoIdeas: PhotoIdeasProviding {
    func ideas(for photo: UIImage, language: String) async -> Result<[String], PhotoIdeasFailure> {
        try? await Task.sleep(for: .milliseconds(600))
        return .success([
            String(localized: "Move her to a rooftop at sunset"),
            String(localized: "Make it a watercolour portrait"),
            String(localized: "Add round reading glasses"),
        ])
    }
}
#endif
