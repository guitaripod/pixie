#if DEBUG
import UIKit

enum DemoMode: String {
    case gallery
    case edit
    case create
    case store

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
}

enum DemoContent {
    static let mockURLPrefix = "pixie-demo://art/"

    static let galleryItems: [DemoGalleryItem] = [
        DemoGalleryItem(asset: "art02", prompt: "Cyberpunk anime girl, neon city, rain, blade runner mood", createdAt: minutesAgo(3), credits: 15, quality: "high"),
        DemoGalleryItem(asset: "art01", prompt: "Change her hair into something wild, spiky volumetric", createdAt: minutesAgo(8), credits: 15, quality: "high"),
        DemoGalleryItem(asset: "art03", prompt: "Stunning space scene with galaxies, nebulas, cosmic colors", createdAt: hoursAgo(2), credits: 8, quality: "medium"),
        DemoGalleryItem(asset: "art04", prompt: "Deep space spiral galaxy, vivid purples and teal stars", createdAt: hoursAgo(5), credits: 8, quality: "medium"),
        DemoGalleryItem(asset: "art05", prompt: "Cheerful anime girl enjoying a colorful plated meal", createdAt: hoursAgo(9), credits: 15, quality: "high"),
        DemoGalleryItem(asset: "art06", prompt: "Professional food photography, appetizing presentation", createdAt: daysAgo(1), credits: 62, quality: "high"),
        DemoGalleryItem(asset: "art07", prompt: "Girl at a futuristic EV charging station, clean lines", createdAt: daysAgo(2), credits: 16, quality: "medium"),
        DemoGalleryItem(asset: "art09", prompt: "80s retro synthwave portrait, palm trees, miami sunset", createdAt: daysAgo(3), credits: 15, quality: "high"),
        DemoGalleryItem(asset: "art10", prompt: "Make it green, glowing emerald star, cosmic energy", createdAt: daysAgo(4), credits: 4, quality: "low"),
        DemoGalleryItem(asset: "art11", prompt: "The sun, churning solar plasma surface, intense detail", createdAt: daysAgo(4), credits: 4, quality: "low"),
        DemoGalleryItem(asset: "art12", prompt: "Stunning deep space scene with a distant black hole", createdAt: daysAgo(5), credits: 8, quality: "medium"),
        DemoGalleryItem(asset: "art08", prompt: "Modern architecture photography, minimalist, golden light", createdAt: daysAgo(6), credits: 62, quality: "high")
    ]

    static func mockMetadata() -> [ImageMetadata] {
        galleryItems.map { item in
            let url = mockURLPrefix + item.asset
            return ImageMetadata(
                id: item.asset,
                url: url,
                prompt: item.prompt,
                createdAt: item.createdAt,
                userId: "demo-user",
                thumbnailUrl: url,
                metadata: ImageMetadataDetails(
                    width: 1024,
                    height: 1024,
                    format: "png",
                    sizeBytes: 1_400_000,
                    creditsUsed: item.credits,
                    quality: item.quality,
                    model: "gpt-image-1",
                    revisedPrompt: nil
                ),
                isPublic: false,
                tags: nil
            )
        }
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
            text: "Edit: Change her hair into something wild",
            images: nil,
            isUser: true,
            timestamp: Date().addingTimeInterval(-40),
            metadata: editMetadata,
            editingImage: original
        )

        let response = ChatMessage(
            role: .assistant,
            content: "Here is your edited image:",
            images: [result]
        )

        return [request, response]
    }

    static func createConversation() -> [ChatMessage] {
        let first = ChatMessage(
            id: "demo-create-1",
            text: "Cyberpunk anime girl in a neon-soaked city, rain, blade runner mood",
            images: nil,
            isUser: true,
            timestamp: Date().addingTimeInterval(-90),
            metadata: nil
        )
        let firstResult = ChatMessage(
            role: .assistant,
            content: "Here are your generated images:",
            images: [DemoMode.image("art02")]
        )
        let second = ChatMessage(
            id: "demo-create-2",
            text: "Now make it a stunning deep-space galaxy with vivid nebulas",
            images: nil,
            isUser: true,
            timestamp: Date().addingTimeInterval(-30),
            metadata: nil
        )
        let secondResult = ChatMessage(
            role: .assistant,
            content: "Here are your generated images:",
            images: [DemoMode.image("art04")]
        )
        return [first, firstResult, second, secondResult]
    }
}

enum DemoRootBuilder {
    static func makeRootViewController(for mode: DemoMode) -> UIViewController {
        DemoContent.seedImageCache()
        switch mode {
        case .gallery:
            let galleryVC = GalleryViewController()
            let navigationController = UINavigationController(rootViewController: galleryVC)
            return navigationController
        case .edit:
            let chatVC = ChatGenerationViewController()
            chatVC.demoMode = .edit
            return UINavigationController(rootViewController: chatVC)
        case .create:
            let chatVC = ChatGenerationViewController()
            chatVC.demoMode = .create
            return UINavigationController(rootViewController: chatVC)
        case .store:
            let storeVC = CreditStoreViewController()
            return UINavigationController(rootViewController: storeVC)
        }
    }
}
#endif
