import PixiepocketCore
import UIKit

/// What the row of ideas under a picked photo shows.
enum PhotoIdeasState: Equatable {
    /// No photo is picked, or ideas are not on offer.
    case hidden
    /// A tap asks for three ideas for one credit.
    case offer
    case loading
    case ideas([String])
    /// Asking failed; a tap asks again.
    case failed
    /// The person has no credit to spend on ideas.
    case needsCredits
}

/// Why a photo got no ideas.
enum PhotoIdeasFailure: Error, Equatable {
    case needsCredits
    case unavailable
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
            return .failure(.needsCredits)
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

/// Holds the ideas for the photo of the current edit. With Plus the ideas are asked for as soon as a photo is
/// picked, because they cost that person nothing; everyone else is offered them for a credit and nothing is sent
/// until they tap. A photo is asked about once: its ideas are kept while it stays picked and come back if it is
/// picked again.
@MainActor
final class PhotoIdeasModel {

    private(set) var state: PhotoIdeasState = .hidden
    /// Called on the main actor whenever `state` changed.
    var onChange: (() -> Void)?

    private let provider: any PhotoIdeasProviding
    private let hasPlus: @MainActor () async -> Bool
    private let language: String
    private var photo: UIImage?
    private var answered: [ObjectIdentifier: [String]] = [:]
    private var generation = 0

    /// The model the app uses: mako and the ledger's Plus, or in a DEBUG demo capture a fixed answer and Plus
    /// unless `PX_IDEAS=offer` asks for the offer.
    static func standard() -> PhotoIdeasModel {
        #if DEBUG
        if DemoMode.isActive {
            let offers = ProcessInfo.processInfo.environment["PX_IDEAS"] == "offer"
            return PhotoIdeasModel(provider: DemoPhotoIdeas(), hasPlus: { !offers })
        }
        #endif
        return PhotoIdeasModel(provider: MakoPhotoIdeas(api: APIService.shared), hasPlus: { await CreditPurchaseManager.shared.hasPlus() })
    }

    init(provider: any PhotoIdeasProviding, language: String = PhotoIdeasModel.languageName, hasPlus: @escaping @MainActor () async -> Bool) {
        self.provider = provider
        self.language = language
        self.hasPlus = hasPlus
    }

    /// The English name of the language the app is shown in, which the ideas are written in.
    static var languageName: String {
        let code = Bundle.main.preferredLocalizations.first ?? "en"
        return Locale(identifier: "en_US").localizedString(forIdentifier: code) ?? "English"
    }

    /// Whether a picked photo is looked at without a further tap: true with Plus, where ideas cost nothing.
    func looksWithoutAsking() async -> Bool {
        await hasPlus()
    }

    /// Tells the model which photo the edit is about, or that there is none.
    func photoChanged(_ newPhoto: UIImage?) {
        guard newPhoto !== photo else { return }
        photo = newPhoto
        generation += 1
        guard let newPhoto else { return set(.hidden) }
        if let ideas = answered[ObjectIdentifier(newPhoto)] { return set(.ideas(ideas)) }
        set(.offer)
        let current = generation
        Task { [weak self] in
            guard let self, await hasPlus(), current == generation else { return }
            ask()
        }
    }

    /// Asks for ideas for the photo, as a tap on the offer or on a failed row does.
    func ask() {
        guard let photo, state != .loading else { return }
        generation += 1
        let current = generation
        set(.loading)
        Task { [weak self, provider, language] in
            let result = await provider.ideas(for: photo, language: language)
            guard let self, current == generation else { return }
            switch result {
            case .success(let ideas):
                answered[ObjectIdentifier(photo)] = ideas
                set(.ideas(ideas))
            case .failure(.needsCredits):
                set(.needsCredits)
            case .failure(.unavailable):
                set(.failed)
            }
        }
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
