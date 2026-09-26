import UIKit

/// A one-tap edit: a localized title for the user and a tuned English instruction for
/// the model, which follows English best whatever language the app runs in.
struct EditPreset: Hashable {
    let id: String
    let symbol: String
    let tint: UIColor
    let title: String
    let subtitle: String
    let prompt: String
    let imageCount: Int

    static func == (lhs: EditPreset, rhs: EditPreset) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }

    static func preset(id: String) -> EditPreset? {
        catalog.first { $0.id == id }
    }

    /// Every preset in display order, with the seasonal one moved to the front while its
    /// season runs.
    static func all(on date: Date = Date()) -> [EditPreset] {
        guard isHalloweenSeason(date), let index = catalog.firstIndex(where: { $0.id == "halloween" }) else {
            return catalog
        }
        var presets = catalog
        presets.insert(presets.remove(at: index), at: 0)
        return presets
    }

    private static func isHalloweenSeason(_ date: Date) -> Bool {
        let components = Calendar(identifier: .gregorian).dateComponents([.month, .day], from: date)
        return components.month == 10 || (components.month == 11 && (components.day ?? 1) <= 2)
    }

    private static let headshotPrompt = "Turn this photo into a professional corporate headshot of the same person. Keep their face, facial features, skin tone, hairstyle and identity exactly the same. Dress them in a smart dark blazer, soft studio lighting, plain light-grey backdrop, head-and-shoulders framing, sharp focus, photorealistic."

    private static let catalog: [EditPreset] = [
        EditPreset(
            id: "headshot",
            symbol: "person.crop.square.fill",
            tint: .systemIndigo,
            title: String(localized: "Pro headshot"),
            subtitle: String(localized: "A studio portrait for LinkedIn and CVs"),
            prompt: headshotPrompt,
            imageCount: 1
        ),
        EditPreset(
            id: "restore",
            symbol: "clock.arrow.circlepath",
            tint: .systemBrown,
            title: String(localized: "Restore old photo"),
            subtitle: String(localized: "Fix scratches and bring back color"),
            prompt: "Restore this old photograph: remove scratches, dust, creases, stains and fading, recover sharp detail, and colorize it with natural, historically plausible colors. Keep every person's face and identity, the composition and the clothing exactly as they are. Photorealistic.",
            imageCount: 1
        ),
        EditPreset(
            id: "figurine",
            symbol: "cube.fill",
            tint: .systemOrange,
            title: String(localized: "3D figurine"),
            subtitle: String(localized: "You as a collectible figure"),
            prompt: "Turn the person in this photo into a realistic 1/7 scale collectible figurine standing on a round transparent acrylic base on a computer desk. Behind it, show the figurine's retail box with the same character printed on it. Keep the person's face, hairstyle and outfit recognizable. Studio product photography, highly detailed, photorealistic.",
            imageCount: 1
        ),
        EditPreset(
            id: "retouch",
            symbol: "wand.and.stars",
            tint: .systemPink,
            title: String(localized: "Natural retouch"),
            subtitle: String(localized: "Better skin and light, still you"),
            prompt: "Retouch this portrait naturally: even out the skin tone, soften blemishes and under-eye shadows, brighten the eyes slightly and improve the light and color. Keep the person's identity, face shape, features, expression, hair and clothing exactly the same. Subtle and realistic, no beauty-filter look.",
            imageCount: 1
        ),
        EditPreset(
            id: "background",
            symbol: "square.dashed",
            tint: .systemTeal,
            title: String(localized: "White background"),
            subtitle: String(localized: "A clean cutout for listings and profiles"),
            prompt: "Cut out the main subject and place it on a pure white studio background with a soft, natural contact shadow. Keep the subject exactly as it is: same shape, colors, details and proportions. Clean, high-resolution product-photo quality.",
            imageCount: 1
        ),
        EditPreset(
            id: "anime",
            symbol: "sparkles",
            tint: .systemPurple,
            title: String(localized: "Anime style"),
            subtitle: String(localized: "A hand-painted animation look"),
            prompt: "Redraw this photo as a high-quality anime illustration in a soft, hand-painted Japanese animation style with warm light and a detailed painted background. Keep the same people, poses, outfits, hair and composition.",
            imageCount: 1
        ),
        EditPreset(
            id: "headshot-pack",
            symbol: "person.2.crop.square.stack.fill",
            tint: .systemBlue,
            title: String(localized: "Headshot pack"),
            subtitle: String(localized: "Four studio headshots in one go"),
            prompt: headshotPrompt,
            imageCount: 4
        ),
        EditPreset(
            id: "magazine",
            symbol: "book.closed.fill",
            tint: .systemRed,
            title: String(localized: "Magazine cover"),
            subtitle: String(localized: "Your own glossy cover shoot"),
            prompt: "Turn this photo into a glossy fashion magazine cover starring the same person. Keep their face and identity exactly the same, with professional studio lighting, elegant styling, a bold masthead that reads \"PIXIE\" and a few tasteful cover lines. Photorealistic.",
            imageCount: 1
        ),
        EditPreset(
            id: "outfit",
            symbol: "tshirt.fill",
            tint: .systemGreen,
            title: String(localized: "New outfit"),
            subtitle: String(localized: "A fresh smart-casual look"),
            prompt: "Change this person's outfit to a stylish, well-fitted smart-casual look in current fashion that suits them. Keep their face, identity, body shape, pose, hair and the background exactly the same. Photorealistic.",
            imageCount: 1
        ),
        EditPreset(
            id: "hairstyle",
            symbol: "scissors",
            tint: .systemMint,
            title: String(localized: "New hairstyle"),
            subtitle: String(localized: "A cut that suits your face"),
            prompt: "Give this person a flattering, modern salon hairstyle that suits their face shape. Keep their face, identity, skin tone, expression, clothing and the background exactly the same. Photorealistic.",
            imageCount: 1
        ),
        EditPreset(
            id: "travel",
            symbol: "airplane",
            tint: .systemCyan,
            title: String(localized: "Travel photo"),
            subtitle: String(localized: "Golden hour on the Amalfi Coast"),
            prompt: "Place this person in a beautiful golden-hour travel photo on a scenic terrace overlooking the Amalfi Coast, as if shot by a professional photographer. Keep their face, identity, body, pose and outfit exactly the same, and match the lighting naturally. Photorealistic.",
            imageCount: 1
        ),
        EditPreset(
            id: "pet-portrait",
            symbol: "pawprint.fill",
            tint: .systemYellow,
            title: String(localized: "Royal pet portrait"),
            subtitle: String(localized: "Your pet as Renaissance nobility"),
            prompt: "Turn the pet in this photo into a regal Renaissance oil painting: the same animal wearing an ornate royal costume with a velvet cape and gold details, posed like nobility, with dramatic classical lighting and museum-quality brushwork. Keep the animal's face, markings and colors exactly the same.",
            imageCount: 1
        ),
        EditPreset(
            id: "halloween",
            symbol: "moon.stars.fill",
            tint: UIColor(red: 0.93, green: 0.45, blue: 0.09, alpha: 1),
            title: String(localized: "Halloween costume"),
            subtitle: String(localized: "A spooky costume and makeup"),
            prompt: "Dress the person in this photo in a spectacular Halloween costume with matching makeup, a stylish vampire, witch or skeleton look that suits them, in a moody candle-lit setting with carved pumpkins. Keep their face and identity recognizable. Photorealistic, cinematic lighting.",
            imageCount: 1
        )
    ]
}
