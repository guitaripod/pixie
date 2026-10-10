#if DEBUG
import UIKit

enum DemoMode: String {
    case gallery
    case edit
    case create
    case empty
    case store
    case onboarding
    case home
    case headshot
    case restore
    case figurine
    case pack
    case pet
    case refine
    case start
    case compose
    case settings
    case credits
    case history
    case help
    case detail
    case consent
    case auth
    case launchfailure
    case splash

    static var current: DemoMode? {
        guard let raw = ProcessInfo.processInfo.environment["PX_DEMO"] else { return nil }
        return DemoMode(rawValue: raw.lowercased())
    }

    static var isActive: Bool { current != nil }

    static func image(_ name: String) -> UIImage {
        UIImage(named: "DemoArt/\(name)") ?? UIImage()
    }
}

struct DemoGalleryItem {
    let asset: String
    let prompt: String
    let createdAt: String
    let credits: Int
    let quality: String
    let model: String
    let width: Int
    let height: Int
}

enum DemoContent {
    static let mockURLPrefix = "pixie-demo://art/"
    static let balance = 1_372

    private static func presetTitle(_ id: String) -> String {
        EditPreset.preset(id: id)?.title ?? id
    }

    static let galleryItems: [DemoGalleryItem] = [
        DemoGalleryItem(asset: "demo_royal_dog", prompt: presetTitle("pet-portrait"), createdAt: minutesAgo(3), credits: 21, quality: "low", model: "gemini-2.5-flash", width: 896, height: 1200),
        DemoGalleryItem(asset: "demo_headshot", prompt: presetTitle("headshot"), createdAt: minutesAgo(11), credits: 21, quality: "low", model: "gemini-2.5-flash", width: 896, height: 1200),
        DemoGalleryItem(asset: "art02", prompt: String(localized: "Cyberpunk anime girl, neon city, rain, blade runner mood"), createdAt: hoursAgo(2), credits: 41, quality: "high", model: "gemini-3-pro-image", width: 1024, height: 697),
        DemoGalleryItem(asset: "demo_figurine", prompt: presetTitle("figurine"), createdAt: hoursAgo(3), credits: 41, quality: "high", model: "gemini-3-pro-image", width: 896, height: 1200),
        DemoGalleryItem(asset: "art03", prompt: String(localized: "Stunning space scene with galaxies, nebulas, cosmic colors"), createdAt: hoursAgo(6), credits: 16, quality: "medium", model: "gpt-image-1", width: 1024, height: 697),
        DemoGalleryItem(asset: "demo_restored", prompt: presetTitle("restore"), createdAt: hoursAgo(9), credits: 21, quality: "low", model: "gemini-2.5-flash", width: 896, height: 1200),
        DemoGalleryItem(asset: "art09", prompt: String(localized: "80s retro synthwave portrait, palm trees, miami sunset"), createdAt: daysAgo(1), credits: 62, quality: "high", model: "gpt-image-1", width: 1024, height: 619),
        DemoGalleryItem(asset: "demo_pack_1", prompt: presetTitle("headshot-pack"), createdAt: daysAgo(1), credits: 84, quality: "low", model: "gemini-2.5-flash", width: 896, height: 1200),
        DemoGalleryItem(asset: "art05", prompt: String(localized: "Cheerful anime girl enjoying a colorful plated meal"), createdAt: daysAgo(2), credits: 16, quality: "medium", model: "gpt-image-1", width: 1024, height: 697),
        DemoGalleryItem(asset: "demo_refined", prompt: String(localized: "Now put her in a bright modern office"), createdAt: daysAgo(2), credits: 21, quality: "low", model: "gemini-2.5-flash", width: 896, height: 1200),
        DemoGalleryItem(asset: "art12", prompt: String(localized: "Stunning deep space scene with a distant black hole"), createdAt: daysAgo(3), credits: 4, quality: "low", model: "gpt-image-1", width: 1024, height: 624),
        DemoGalleryItem(asset: "art08", prompt: String(localized: "Modern architecture photography, minimalist, golden light"), createdAt: daysAgo(3), credits: 62, quality: "high", model: "gpt-image-1", width: 1024, height: 619),
        DemoGalleryItem(asset: "art06", prompt: String(localized: "Professional food photography, appetizing presentation"), createdAt: daysAgo(4), credits: 62, quality: "high", model: "gpt-image-1", width: 1024, height: 697),
        DemoGalleryItem(asset: "art10", prompt: String(localized: "Make it green, glowing emerald star, cosmic energy"), createdAt: daysAgo(4), credits: 4, quality: "low", model: "gpt-image-1", width: 1024, height: 624),
        DemoGalleryItem(asset: "art07", prompt: String(localized: "Girl at a futuristic EV charging station, clean lines"), createdAt: daysAgo(5), credits: 16, quality: "medium", model: "gpt-image-1", width: 1024, height: 619),
        DemoGalleryItem(asset: "art04", prompt: String(localized: "Deep space spiral galaxy, vivid purples and teal stars"), createdAt: daysAgo(5), credits: 16, quality: "medium", model: "gpt-image-1", width: 1024, height: 697),
        DemoGalleryItem(asset: "art11", prompt: String(localized: "The sun, churning solar plasma surface, intense detail"), createdAt: daysAgo(6), credits: 4, quality: "low", model: "gpt-image-1", width: 1024, height: 624),
        DemoGalleryItem(asset: "art01", prompt: String(localized: "Change her hair into something wild, spiky volumetric"), createdAt: daysAgo(6), credits: 21, quality: "low", model: "gemini-2.5-flash", width: 1024, height: 697)
    ]

    static let recentPhotoAssets = ["demo_man", "demo_dog", "demo_oldphoto", "demo_selfie"]

    static func recentPhotos() -> [UIImage] {
        recentPhotoAssets.map(DemoMode.image)
    }

    static func mockMetadata(for item: DemoGalleryItem) -> ImageMetadata {
        let url = mockURLPrefix + item.asset
        return ImageMetadata(
            id: item.asset,
            url: url,
            prompt: item.prompt,
            createdAt: item.createdAt,
            userId: "demo-user",
            thumbnailUrl: url,
            metadata: ImageMetadataDetails(
                width: item.width,
                height: item.height,
                format: "webp",
                sizeBytes: 1_400_000,
                creditsUsed: item.credits,
                quality: item.quality,
                model: item.model,
                revisedPrompt: nil
            ),
            tags: nil
        )
    }

    static func mockTransactions() -> [CreditTransaction] {
        let rows: [(String, Int, String, String)] = [
            ("spend", 21, "One-tap edit: Royal pet portrait", minutesAgo(3)),
            ("spend", 21, "One-tap edit: Pro headshot", minutesAgo(11)),
            ("spend", 41, "Image edit, sharper detail", hoursAgo(3)),
            ("spend", 21, "One-tap edit: Restore old photo", hoursAgo(9)),
            ("spend", 84, "Headshot pack, 4 images", daysAgo(1)),
            ("bonus", 364, "Pack bonus credits", daysAgo(2)),
            ("purchase", 1136, "Credit pack: Popular", daysAgo(2)),
            ("spend", 16, "Image generation, medium quality", daysAgo(3)),
            ("spend", 62, "Image generation, high quality", daysAgo(4)),
            ("spend", 4, "Image generation, low quality", daysAgo(5)),
            ("refund", 21, "Refund: request declined by moderation", daysAgo(6)),
            ("bonus", 63, "Welcome gift: 3 free images", daysAgo(9))
        ]
        var running = balance
        return rows.enumerated().map { index, row in
            let isSpend = row.0 == "spend"
            let after = running
            running += isSpend ? row.1 : -row.1
            return CreditTransaction(
                id: "demo-tx-\(index)",
                userId: "demo-user",
                transactionType: row.0,
                amount: row.1,
                balanceAfter: after,
                description: row.2,
                referenceId: nil,
                createdAt: row.3
            )
        }
    }

    static func mockMetadata() -> [ImageMetadata] {
        galleryItems.map(mockMetadata(for:))
    }

    static func seedImageCache() {
        for item in galleryItems {
            ImageCache.shared.setImage(DemoMode.image(item.asset), for: mockURLPrefix + item.asset)
        }
    }

    private static func iso(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: date)
    }

    private static func minutesAgo(_ value: Int) -> String { iso(Date().addingTimeInterval(TimeInterval(-value * 60))) }
    private static func hoursAgo(_ value: Int) -> String { iso(Date().addingTimeInterval(TimeInterval(-value * 3600))) }
    private static func daysAgo(_ value: Int) -> String { iso(Date().addingTimeInterval(TimeInterval(-value * 86400))) }
}

enum DemoChatBuilder {
    static func editConversation() -> [ChatMessage] {
        let original = DemoMode.image("hero_girl")
        let result = DemoMode.image("hero_wild")

        let editMetadata = ChatMessage.MessageMetadata(
            model: "gpt-image-1",
            size: "Auto (Optimal)",
            quality: "low",
            credits: nil,
            sizeDisplay: "Auto (Optimal)",
            background: "auto",
            format: "png",
            compression: nil,
            moderation: nil,
            isEditMode: true
        )

        let request = ChatMessage(
            id: "demo-edit-request",
            text: String(localized: "Edit: Change her hair into something wild"),
            images: nil,
            isUser: true,
            timestamp: Date().addingTimeInterval(-40),
            metadata: editMetadata,
            editingImage: original
        )

        let response = ChatMessage(
            role: .assistant,
            content: String(localized: "Here is your edited image:"),
            images: [result]
        )

        return [request, response]
    }

    static func createConversation() -> [ChatMessage] {
        let first = ChatMessage(
            id: "demo-create-1",
            text: String(localized: "Cyberpunk anime girl in a neon-soaked city, rain, blade runner mood"),
            images: nil,
            isUser: true,
            timestamp: Date().addingTimeInterval(-90),
            metadata: nil
        )
        let firstResult = ChatMessage(
            role: .assistant,
            content: String(localized: "Here are your generated images:"),
            images: [DemoMode.image("art02")]
        )
        let second = ChatMessage(
            id: "demo-create-2",
            text: String(localized: "Now make it a stunning deep-space galaxy with vivid nebulas"),
            images: nil,
            isUser: true,
            timestamp: Date().addingTimeInterval(-30),
            metadata: nil
        )
        let secondResult = ChatMessage(
            role: .assistant,
            content: String(localized: "Here are your generated images:"),
            images: [DemoMode.image("art04")]
        )
        return [first, firstResult, second, secondResult]
    }
}

extension DemoChatBuilder {
    static func presetConversation(presetID: String, before: String, after: [String]) -> [ChatMessage] {
        let preset = EditPreset.preset(id: presetID)
        let source = DemoMode.image(before)
        let request = ChatMessage(
            id: "demo-preset-\(presetID)",
            text: preset?.title,
            images: nil,
            isUser: true,
            timestamp: Date().addingTimeInterval(-30),
            metadata: nil,
            editingImage: source
        )
        let result = ChatMessage(
            role: .assistant,
            content: String(localized: "Here are your generated images:"),
            images: after.map(DemoMode.image),
            sourceImage: source
        )
        return [request, result]
    }

    static func refineConversation() -> [ChatMessage] {
        let first = presetConversation(presetID: "headshot", before: "demo_selfie", after: ["demo_headshot"])
        let headshot = DemoMode.image("demo_headshot")
        let followUp = ChatMessage(
            id: "demo-refine",
            text: String(localized: "Now put her in a bright modern office"),
            images: nil,
            isUser: true,
            timestamp: Date().addingTimeInterval(-10),
            metadata: nil,
            editingImage: headshot
        )
        let refined = ChatMessage(
            role: .assistant,
            content: String(localized: "Here are your generated images:"),
            images: [DemoMode.image("demo_refined")],
            sourceImage: headshot
        )
        return first + [followUp, refined]
    }
}

struct DemoLaunch {
    var scenario: ChatGenerationViewController.DemoScenario?
    var section: SidebarSection = .chat
    var afterLaunch: ((MainSplitViewController, UINavigationController) -> Void)?
}

@MainActor
enum DemoRootBuilder {
    static func makeRootViewController(for mode: DemoMode) -> UIViewController {
        DemoContent.seedImageCache()
        seedConsent(for: mode)
        switch mode {
        case .onboarding:
            return OnboardingViewController()
        case .auth:
            let navigation = UINavigationController(rootViewController: AuthenticationViewController())
            navigation.navigationBar.isHidden = true
            return navigation
        case .launchfailure:
            return LaunchFailureViewController(onRetry: { false }, onSignIn: {})
        case .splash:
            let controller = UIViewController()
            controller.view = SplashView()
            return controller
        case .gallery:
            return split(DemoLaunch(section: .gallery))
        case .edit:
            return split(DemoLaunch(scenario: .edit))
        case .create:
            return split(DemoLaunch(scenario: .create))
        case .empty:
            return split(DemoLaunch(scenario: .empty))
        case .start:
            return split(DemoLaunch(scenario: .fresh))
        case .home:
            return split(DemoLaunch(scenario: .home(DemoMode.image("demo_selfie"))))
        case .compose:
            return split(DemoLaunch(scenario: .compose(DemoMode.image("demo_selfie"), String(localized: "Now put her in a bright modern office"))))
        case .headshot:
            return split(DemoLaunch(scenario: .conversation(DemoChatBuilder.presetConversation(presetID: "headshot", before: "demo_selfie", after: ["demo_headshot"]))))
        case .restore:
            return split(DemoLaunch(scenario: .conversation(DemoChatBuilder.presetConversation(presetID: "restore", before: "demo_oldphoto", after: ["demo_restored"]))))
        case .figurine:
            return split(DemoLaunch(scenario: .conversation(DemoChatBuilder.presetConversation(presetID: "figurine", before: "demo_man", after: ["demo_figurine"]))))
        case .pack:
            return split(DemoLaunch(scenario: .conversation(DemoChatBuilder.presetConversation(presetID: "headshot-pack", before: "demo_man", after: ["demo_pack_1", "demo_pack_2", "demo_pack_3", "demo_pack_4"]))))
        case .pet:
            return split(DemoLaunch(scenario: .conversation(DemoChatBuilder.presetConversation(presetID: "pet-portrait", before: "demo_dog", after: ["demo_royal_dog"]))))
        case .refine:
            return split(DemoLaunch(scenario: .conversation(DemoChatBuilder.refineConversation())))
        case .store:
            return split(DemoLaunch(scenario: .home(DemoMode.image("demo_selfie"))) { split, _ in
                CreditStoreViewController.present(from: split)
            })
        case .credits:
            return split(DemoLaunch(section: .credits))
        case .history:
            return split(DemoLaunch(section: .credits) { _, navigation in
                navigation.pushViewController(TransactionHistoryViewController(viewModel: CreditsViewModel()), animated: false)
            })
        case .settings:
            return split(DemoLaunch(section: .settings))
        case .help:
            return split(DemoLaunch(section: .settings) { _, navigation in
                navigation.pushViewController(HelpViewController(), animated: false)
            })
        case .detail:
            return split(DemoLaunch(section: .gallery) { _, navigation in
                guard let gallery = navigation.topViewController as? GalleryViewController,
                      let item = DemoContent.galleryItems.first(where: { $0.asset == "demo_figurine" }) else { return }
                gallery.presentDetail(for: DemoContent.mockMetadata(for: item))
            })
        case .consent:
            return split(DemoLaunch(scenario: .home(DemoMode.image("demo_selfie"))) { split, _ in
                _ = AIConsentViewController.presentIfNeeded(from: split, onContinue: {})
            })
        }
    }

    private static func split(_ launch: DemoLaunch) -> MainSplitViewController {
        let controller = MainSplitViewController()
        controller.demoLaunch = launch
        return controller
    }

    private static func split(_ launch: DemoLaunch, afterLaunch: @escaping (MainSplitViewController, UINavigationController) -> Void) -> MainSplitViewController {
        var launch = launch
        launch.afterLaunch = afterLaunch
        return split(launch)
    }

    private static func seedConsent(for mode: DemoMode) {
        switch mode {
        case .onboarding, .consent:
            CloudAIConsent.withdraw()
        default:
            CloudAIConsent.grant()
        }
    }
}
#endif
