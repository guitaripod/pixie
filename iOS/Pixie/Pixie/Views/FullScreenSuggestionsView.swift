import UIKit
import Photos


enum SuggestionsViewState {
    case suggestions
    case chat
}


class FullScreenSuggestionsView: UIView {
    static let topBarClearance: CGFloat = 76
    static let composerClearance: CGFloat = 120
    private static let sectionSpacing: CGFloat = 28
    private static let chipRowHeight: CGFloat = 44

    private let contentHost = UIView()
    private let topFade = CAGradientLayer()
    private lazy var collectionView: UICollectionView = {
        let layout = createLayout()
        let cv = UICollectionView(frame: .zero, collectionViewLayout: layout)
        cv.backgroundColor = .clear
        cv.contentInsetAdjustmentBehavior = .never
        cv.alwaysBounceVertical = true
        cv.delegate = self
        return cv
    }()
    private var appliedTopInset: CGFloat = 0
    private static let compactEnterHeight: CGFloat = 560
    private static let compactExitHeight: CGFloat = 600
    private static let compactSideBySideWidth: CGFloat = 400
    private static let bottomFadeLength: CGFloat = 18
    private static let veryShortEnterHeight: CGFloat = 300
    private static let veryShortExitHeight: CGFloat = 340
    private static let veryShortCardHeight: CGFloat = 104
    private static let veryShortCardChrome: CGFloat = 40
    private var isCompactHeight = false
    private var isVeryShort = false
    private var dataSource: UICollectionViewDiffableDataSource<SuggestionsSection, AnyHashable>!
    var selectedSuggestionsManager: SelectedSuggestionsManager?
    var onPromptSelected: ((String) -> Void)?
    var onImageSelected: ((UIImage) -> Void)?
    var onEditImageTapped: (() -> Void)?
    var onSelectionChanged: (() -> Void)?
    var onImageTapped: ((UIImage) -> Void)?
    var onPresetSelected: ((EditPreset) -> Void)?
    var onSampleTapped: (() -> Void)?
    var onPhotoRemoved: (() -> Void)?
    private static let addImageItem = "add_image"
    private static let sampleTileItem = "sample_tile"
    private static let selectedPhotoItem = "selected_photo"
    private var recentImages: [UIImage] = []
    private var selectedPhoto: UIImage?
    private var editSectionItems: [AnyHashable] = []
    private let popularPresets = EditPreset.popular()
    private let moreEditPresets = EditPreset.moreEdits()
    private var selectedCreativeCategory = 0
    private var selectedModifierCategory = 0
    private var isEditMode = false
    private let haptics = HapticManager.shared
    private let quickActions = [
        QuickAction(icon: "person.crop.square", title: String(localized: "Portrait"), prompt: "Professional portrait photo of a person, studio lighting, high quality, sharp focus", color: UIColor(red: 0.39, green: 0.40, blue: 0.95, alpha: 1)),
        QuickAction(icon: "bolt.fill", title: String(localized: "Cyberpunk"), prompt: "Cyberpunk cityscape with neon lights, flying cars, rain, blade runner style", color: UIColor(red: 0.88, green: 0.08, blue: 0.28, alpha: 1)),
        QuickAction(icon: "pawprint", title: String(localized: "Animals"), prompt: "Adorable animal portrait, detailed fur texture, expressive eyes, natural lighting", color: UIColor(red: 0.55, green: 0.36, blue: 0.96, alpha: 1)),
        QuickAction(icon: "building.2", title: String(localized: "Architecture"), prompt: "Modern architecture photography, clean lines, minimalist design, professional composition", color: UIColor(red: 0.94, green: 0.27, blue: 0.27, alpha: 1)),
        QuickAction(icon: "mountain.2", title: String(localized: "Landscape"), prompt: "Breathtaking landscape photography, golden hour lighting, dramatic sky, high resolution", color: UIColor(red: 0.06, green: 0.59, blue: 0.53, alpha: 1)),
        QuickAction(icon: "wand.and.stars", title: String(localized: "Fantasy"), prompt: "Epic fantasy landscape with magical elements, dragons, castles, mystical atmosphere", color: UIColor(red: 0.49, green: 0.23, blue: 0.93, alpha: 1)),
        QuickAction(icon: "paintbrush", title: String(localized: "Digital Art"), prompt: "Digital artwork, vibrant colors, detailed illustration, professional quality", color: UIColor(red: 0.96, green: 0.62, blue: 0.04, alpha: 1)),
        QuickAction(icon: "fork.knife", title: String(localized: "Food"), prompt: "Professional food photography, appetizing presentation, restaurant quality, shallow depth of field", color: UIColor(red: 0.93, green: 0.17, blue: 0.60, alpha: 1)),
        QuickAction(icon: "sparkle", title: String(localized: "Space"), prompt: "Stunning space scene with galaxies, nebulas, planets, cosmic colors", color: UIColor(red: 0.12, green: 0.16, blue: 0.22, alpha: 1)),
        QuickAction(icon: "leaf", title: String(localized: "Macro"), prompt: "Extreme macro photography, intricate details, shallow depth of field, professional quality", color: UIColor(red: 0.06, green: 0.46, blue: 0.43, alpha: 1)),
        QuickAction(icon: "moon", title: String(localized: "Surreal"), prompt: "Surreal dreamscape with impossible geometry, floating objects, Salvador Dali style", color: UIColor(red: 0.43, green: 0.16, blue: 0.85, alpha: 1)),
        QuickAction(icon: "camera.filters", title: String(localized: "Retro"), prompt: "80s retro style with synthwave colors, palm trees, sunset, miami vice aesthetic", color: UIColor(red: 0.86, green: 0.15, blue: 0.47, alpha: 1)),
        QuickAction(icon: "drop", title: String(localized: "Underwater"), prompt: "Underwater photography, coral reef, tropical fish, sun rays through water", color: UIColor(red: 0.01, green: 0.52, blue: 0.78, alpha: 1)),
        QuickAction(icon: "square.grid.3x3", title: String(localized: "Miniature"), prompt: "Miniature tilt-shift photography effect, looks like a tiny model world", color: UIColor(red: 0.98, green: 0.45, blue: 0.09, alpha: 1))
    ]
    private let editModeQuickActions = [
        QuickAction(icon: "paintpalette", title: String(localized: "Recolor"), prompt: "Change the color scheme to vibrant warm tones", color: UIColor(red: 0.96, green: 0.26, blue: 0.21, alpha: 1)),
        QuickAction(icon: "light.max", title: String(localized: "Lighting"), prompt: "Add dramatic lighting with strong shadows and highlights", color: UIColor(red: 0.95, green: 0.77, blue: 0.06, alpha: 1)),
        QuickAction(icon: "paintbrush.pointed", title: String(localized: "Art Style"), prompt: "Transform into oil painting style with visible brush strokes", color: UIColor(red: 0.55, green: 0.27, blue: 0.07, alpha: 1)),
        QuickAction(icon: "minus.circle", title: String(localized: "Remove"), prompt: "Remove all unwanted objects and distractions from the background", color: UIColor(red: 0.96, green: 0.27, blue: 0.27, alpha: 1)),
        QuickAction(icon: "wand.and.stars", title: String(localized: "Enhance"), prompt: "Enhance the image quality, make it sharper and more vibrant", color: UIColor(red: 0.55, green: 0.36, blue: 0.96, alpha: 1)),
        QuickAction(icon: "moon.stars", title: String(localized: "Night"), prompt: "Transform this into a beautiful nighttime scene with stars and moonlight", color: UIColor(red: 0.12, green: 0.25, blue: 0.69, alpha: 1)),
        QuickAction(icon: "cloud.rain", title: String(localized: "Weather"), prompt: "Add dramatic storm clouds and rain to create a moody atmosphere", color: UIColor(red: 0.39, green: 0.45, blue: 0.52, alpha: 1)),
        QuickAction(icon: "tree", title: String(localized: "Season"), prompt: "Transform this into a beautiful autumn scene with fall colors", color: UIColor(red: 0.86, green: 0.15, blue: 0.15, alpha: 1)),
        QuickAction(icon: "face.smiling", title: String(localized: "Expression"), prompt: "Make the person smile naturally and look happy", color: UIColor(red: 0.96, green: 0.62, blue: 0.04, alpha: 1)),
        QuickAction(icon: "rectangle.landscape", title: String(localized: "Background"), prompt: "Replace the background with a beautiful beach sunset", color: UIColor(red: 0.01, green: 0.52, blue: 0.78, alpha: 1)),
        QuickAction(icon: "blur", title: String(localized: "Blur"), prompt: "Add professional bokeh blur to the background", color: UIColor(red: 0.65, green: 0.34, blue: 0.84, alpha: 1)),
        QuickAction(icon: "sparkles", title: String(localized: "Dreamy"), prompt: "Add a dreamy, ethereal quality with soft light and glow", color: UIColor(red: 0.93, green: 0.51, blue: 0.93, alpha: 1)),
        QuickAction(icon: "film", title: String(localized: "Vintage"), prompt: "Apply vintage film photography style with grain and faded colors", color: UIColor(red: 0.48, green: 0.31, blue: 0.24, alpha: 1)),
        QuickAction(icon: "bolt", title: String(localized: "Cyberpunk"), prompt: "Transform into cyberpunk style with neon lights and futuristic elements", color: UIColor(red: 0.88, green: 0.08, blue: 0.72, alpha: 1)),
        QuickAction(icon: "square.dashed", title: String(localized: "Minimal"), prompt: "Simplify to minimalist style with clean lines and reduced colors", color: UIColor(red: 0.24, green: 0.24, blue: 0.26, alpha: 1)),
        QuickAction(icon: "theatermasks", title: String(localized: "Dramatic"), prompt: "Add dramatic mood with high contrast and intense emotions", color: UIColor(red: 0.64, green: 0.08, blue: 0.08, alpha: 1))
    ]
    private let creativePrompts = [
        CreativePrompt(category: String(localized: "Fantasy"), symbol: "moon.stars.fill", prompts: [
            "Majestic dragon soaring through cloudy skies, fantasy art style",
            "Futuristic city with flying cars and neon lights at night",
            "Magical forest with glowing mushrooms and fairy lights",
            "Space station orbiting a distant planet with multiple moons",
            "Steampunk airship floating above Victorian London",
            "Enchanted castle on floating island in the clouds"
        ], color: UIColor(red: 0.58, green: 0.2, blue: 0.92, alpha: 1)),
        CreativePrompt(category: String(localized: "Nature"), symbol: "leaf.fill", prompts: [
            "Majestic eagle soaring over mountain peaks at sunrise",
            "Underwater coral reef teeming with colorful tropical fish",
            "Northern lights dancing over a frozen lake in winter",
            "Ancient tree with twisted roots in misty forest",
            "Butterfly garden with hundreds of colorful butterflies",
            "Thunderstorm over dramatic desert landscape"
        ], color: UIColor(red: 0.02, green: 0.59, blue: 0.41, alpha: 1)),
        CreativePrompt(category: String(localized: "Abstract"), symbol: "paintpalette.fill", prompts: [
            "Vibrant abstract painting with swirling colors and geometric shapes",
            "Minimalist composition with bold colors and clean lines",
            "Surreal dreamscape with floating objects and impossible geometry",
            "Pop art style portrait with bright colors and comic book aesthetics",
            "Impressionist painting of a sunset over lavender fields",
            "Fractal patterns with infinite complexity and vivid colors"
        ], color: UIColor(red: 0.86, green: 0.15, blue: 0.15, alpha: 1)),
        CreativePrompt(category: String(localized: "Urban"), symbol: "building.2.fill", prompts: [
            "High fashion photoshoot in minimalist studio setting",
            "Cozy coffee shop interior with warm lighting and plants",
            "Street style fashion photography in urban setting",
            "Luxury spa interior with zen garden and natural materials",
            "Modern home office with scandinavian design aesthetic",
            "Bustling city street at night with neon signs"
        ], color: UIColor(red: 0.86, green: 0.15, blue: 0.47, alpha: 1)),
        CreativePrompt(category: String(localized: "Tech"), symbol: "cpu.fill", prompts: [
            "Advanced AI robot assistant helping in modern home",
            "Holographic interface displaying complex data visualization",
            "Electric vehicle charging station of the future",
            "Virtual reality user exploring digital worlds",
            "Quantum computer in high-tech laboratory setting",
            "Cybernetic augmentations on human body"
        ], color: UIColor(red: 0.15, green: 0.39, blue: 0.92, alpha: 1))
    ]
    private let stylePresets = [
        StylePreset(name: String(localized: "Cinematic"), description: String(localized: "Movie-like"), prompt: "cinematic shot, movie still, film grain, dramatic lighting, wide angle lens", icon: "film", gradientColors: [UIColor(red: 0.12, green: 0.16, blue: 0.22, alpha: 1), UIColor(red: 0.22, green: 0.26, blue: 0.32, alpha: 1)]),
        StylePreset(name: String(localized: "Anime"), description: String(localized: "Japanese art"), prompt: "anime style, manga art, cel shading, vibrant colors, detailed character design", icon: "star.circle", gradientColors: [UIColor(red: 0.93, green: 0.28, blue: 0.6, alpha: 1), UIColor(red: 0.96, green: 0.45, blue: 0.71, alpha: 1)]),
        StylePreset(name: String(localized: "3D Render"), description: String(localized: "CGI graphics"), prompt: "3D render, octane render, ray tracing, photorealistic, high detail, studio lighting", icon: "cube", gradientColors: [UIColor(red: 0.23, green: 0.51, blue: 0.96, alpha: 1), UIColor(red: 0.38, green: 0.65, blue: 0.98, alpha: 1)]),
        StylePreset(name: String(localized: "Oil Paint"), description: String(localized: "Classic art"), prompt: "oil painting, traditional art, brush strokes visible, museum quality, masterpiece", icon: "paintpalette", gradientColors: [UIColor(red: 0.94, green: 0.27, blue: 0.27, alpha: 1), UIColor(red: 0.97, green: 0.44, blue: 0.44, alpha: 1)]),
        StylePreset(name: String(localized: "Sketch"), description: String(localized: "Pencil art"), prompt: "pencil sketch, detailed drawing, graphite on paper, artistic shading, hand drawn", icon: "pencil", gradientColors: [UIColor(red: 0.42, green: 0.45, blue: 0.50, alpha: 1), UIColor(red: 0.61, green: 0.64, blue: 0.69, alpha: 1)]),
        StylePreset(name: String(localized: "Watercolor"), description: String(localized: "Soft painting"), prompt: "watercolor painting, soft edges, flowing colors, artistic bleeds, paper texture", icon: "paintbrush", gradientColors: [UIColor(red: 0.38, green: 0.65, blue: 0.98, alpha: 1), UIColor(red: 0.58, green: 0.77, blue: 0.99, alpha: 1)]),
        StylePreset(name: String(localized: "Comic"), description: String(localized: "Comic book"), prompt: "comic book style, bold outlines, halftone dots, speech bubbles, superhero aesthetic", icon: "book", gradientColors: [UIColor(red: 0.98, green: 0.75, blue: 0.14, alpha: 1), UIColor(red: 0.99, green: 0.88, blue: 0.28, alpha: 1)]),
        StylePreset(name: String(localized: "Pixel Art"), description: String(localized: "8-bit style"), prompt: "pixel art, 8-bit style, retro game aesthetic, limited color palette, blocky design", icon: "gamecontroller", gradientColors: [UIColor(red: 0.06, green: 0.72, blue: 0.51, alpha: 1), UIColor(red: 0.20, green: 0.83, blue: 0.60, alpha: 1)]),
        StylePreset(name: String(localized: "Neon"), description: String(localized: "Glowing lights"), prompt: "neon lights, glowing effects, cyberpunk aesthetic, dark background, vibrant colors", icon: "lightbulb", gradientColors: [UIColor(red: 0.88, green: 0.11, blue: 0.28, alpha: 1), UIColor(red: 0.95, green: 0.25, blue: 0.37, alpha: 1)]),
        StylePreset(name: String(localized: "Minimal"), description: String(localized: "Simple clean"), prompt: "minimalist style, simple composition, negative space, clean lines, modern aesthetic", icon: "square.dashed", gradientColors: [UIColor(red: 0.22, green: 0.26, blue: 0.32, alpha: 1), UIColor(red: 0.29, green: 0.33, blue: 0.39, alpha: 1)]),
        StylePreset(name: String(localized: "Vintage"), description: String(localized: "Retro look"), prompt: "vintage photography, film grain, faded colors, nostalgic mood, old camera effect", icon: "camera", gradientColors: [UIColor(red: 0.57, green: 0.25, blue: 0.05, alpha: 1), UIColor(red: 0.70, green: 0.33, blue: 0.04, alpha: 1)]),
        StylePreset(name: String(localized: "HDR"), description: String(localized: "High detail"), prompt: "HDR photography, high dynamic range, vivid colors, sharp details, professional quality", icon: "camera.aperture", gradientColors: [UIColor(red: 0.49, green: 0.23, blue: 0.93, alpha: 1), UIColor(red: 0.55, green: 0.36, blue: 0.96, alpha: 1)])
    ]
    private let modifierCategories = [String(localized: "Quality"), String(localized: "Lighting"), String(localized: "Camera"), String(localized: "Mood"), String(localized: "Composition"), String(localized: "Artistic")]
    private let modifiers = [
        ["8K", "4K", "HD", "ultra detailed", "masterpiece", "best quality"],
        ["studio lighting", "golden hour", "dramatic lighting", "soft light", "backlit", "rim lighting"],
        ["DSLR", "35mm lens", "bokeh", "depth of field", "macro lens", "wide angle"],
        ["peaceful", "dramatic", "mysterious", "energetic", "melancholic", "ethereal"],
        ["rule of thirds", "centered", "symmetrical", "dynamic pose", "close-up", "full body"],
        ["trending on artstation", "award winning", "professional", "concept art", "photorealistic", "hyperrealistic"]
    ]
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
        setupDataSource()
        checkPhotoPermissions()
    }
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    private func setupUI() {
        backgroundColor = Theme.Color.canvas
        contentHost.translatesAutoresizingMaskIntoConstraints = false
        contentHost.backgroundColor = .clear
        addSubview(contentHost)
        contentHost.pinEdges(to: self)
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        contentHost.addSubview(collectionView)
        collectionView.pinEdges(to: contentHost)
        topFade.colors = [UIColor.clear.cgColor, UIColor.black.cgColor]
        contentHost.layer.mask = topFade
        registerCells()
        updateInsets()
    }
    private func registerCells() {
        collectionView.register(SuggestionsSectionHeaderView.self, forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader, withReuseIdentifier: SuggestionsSectionHeaderView.reuseIdentifier)
        collectionView.register(CreativePromptsHeaderView.self, forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader, withReuseIdentifier: CreativePromptsHeaderView.reuseIdentifier)
        collectionView.register(ImageCell.self, forCellWithReuseIdentifier: ImageCell.reuseIdentifier)
        collectionView.register(SelectedPhotoCell.self, forCellWithReuseIdentifier: SelectedPhotoCell.reuseIdentifier)
        collectionView.register(PhotoDropZoneCell.self, forCellWithReuseIdentifier: PhotoDropZoneCell.reuseIdentifier)
        collectionView.register(SampleTileCell.self, forCellWithReuseIdentifier: SampleTileCell.reuseIdentifier)
        collectionView.register(PresetCell.self, forCellWithReuseIdentifier: PresetCell.reuseIdentifier)
        collectionView.register(MoreEditCell.self, forCellWithReuseIdentifier: MoreEditCell.reuseIdentifier)
        collectionView.register(QuickActionCell.self, forCellWithReuseIdentifier: QuickActionCell.reuseIdentifier)
        collectionView.register(PromptCardCell.self, forCellWithReuseIdentifier: PromptCardCell.reuseIdentifier)
        collectionView.register(StylePresetCell.self, forCellWithReuseIdentifier: StylePresetCell.reuseIdentifier)
        collectionView.register(ModifierChipCell.self, forCellWithReuseIdentifier: ModifierChipCell.reuseIdentifier)
        collectionView.register(CategoryChipCell.self, forCellWithReuseIdentifier: CategoryChipCell.reuseIdentifier)
    }
    override func layoutSubviews() {
        super.layoutSubviews()
        updateInsets()
        updateCompactHeight()
        updateEdgeFades()
    }
    override func safeAreaInsetsDidChange() {
        super.safeAreaInsetsDidChange()
        updateInsets()
    }
    /// The floating top bar sits over the first rows, so content starts one bar-height below the
    /// safe area and the bottom leaves room for the composer.
    private func updateInsets() {
        let top = safeAreaInsets.top + Self.topBarClearance
        guard abs(top - appliedTopInset) > 0.5 else { return }
        let wasAtTop = collectionView.contentOffset.y <= -appliedTopInset + 1
        appliedTopInset = top
        collectionView.contentInset = UIEdgeInsets(top: top, left: 0, bottom: Self.composerClearance, right: 0)
        collectionView.verticalScrollIndicatorInsets = UIEdgeInsets(top: top, left: 0, bottom: Self.composerClearance, right: 0)
        if wasAtTop {
            collectionView.contentOffset = CGPoint(x: 0, y: -top)
        }
    }
    /// The scrollable band between the top bar and the composer; the home layout adapts to its height.
    private var visibleHeight: CGFloat {
        bounds.height - collectionView.contentInset.top - collectionView.contentInset.bottom
    }
    /// A short band (a folded display, landscape, a small phone) drops the Recent strip and tightens the
    /// hero so the Popular edits stay above the composer. Entering and leaving use different heights so a
    /// growing composer cannot flip the layout back and forth.
    private func updateCompactHeight() {
        let height = visibleHeight
        guard height > 0 else { return }
        let compact = isCompactHeight ? height < Self.compactExitHeight : height < Self.compactEnterHeight
        let veryShort = isVeryShort ? height < Self.veryShortExitHeight : height < Self.veryShortEnterHeight
        guard compact != isCompactHeight || veryShort != isVeryShort else { return }
        isCompactHeight = compact
        isVeryShort = veryShort
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.applySnapshot()
            var snapshot = self.dataSource.snapshot()
            snapshot.reloadSections([.editImage, .presets])
            self.dataSource.apply(snapshot, animatingDifferences: false)
            self.collectionView.collectionViewLayout.invalidateLayout()
        }
    }
    /// Rows scrolling up under the top bar dissolve over its height, and rows scrolling down under the
    /// composer dissolve just above it, instead of being cut off or showing through the capsule.
    private func updateEdgeFades() {
        topFade.frame = bounds
        let height = max(1, bounds.height)
        let start = min(1, safeAreaInsets.top / height)
        let end = min(1, (safeAreaInsets.top + 56) / height)
        let bottomStart = min(1, max(end, (height - collectionView.contentInset.bottom - safeAreaInsets.bottom) / height))
        let bottomEnd = min(1, bottomStart + Self.bottomFadeLength / height)
        topFade.colors = [UIColor.clear.cgColor, UIColor.clear.cgColor, UIColor.black.cgColor, UIColor.black.cgColor, UIColor.clear.cgColor]
        topFade.locations = [0, NSNumber(value: Double(start)), NSNumber(value: Double(end)), NSNumber(value: Double(bottomStart)), NSNumber(value: Double(bottomEnd))]
    }
    private func section(at index: Int) -> SuggestionsSection? {
        guard let identifiers = dataSource?.snapshot().sectionIdentifiers, identifiers.indices.contains(index) else { return nil }
        return identifiers[index]
    }

    private struct Metrics {
        let width: CGFloat
        let contentWidth: CGFloat
        let sideInset: CGFloat

        init(width: CGFloat, traits: UITraitCollection, maxWidth: CGFloat = Theme.Width.grid) {
            self.width = width
            let margin = Theme.screenMargin(for: traits)
            contentWidth = max(0, min(width - margin * 2, maxWidth))
            sideInset = max(0, (width - contentWidth) / 2)
        }

        init(_ environment: NSCollectionLayoutEnvironment, maxWidth: CGFloat = Theme.Width.grid) {
            self.init(width: environment.container.effectiveContentSize.width, traits: environment.traitCollection, maxWidth: maxWidth)
        }
    }

    private static func maxContentWidth(of section: SuggestionsSection) -> CGFloat {
        section == .editImage ? Theme.Width.form : Theme.Width.grid
    }

    private func createLayout() -> UICollectionViewLayout {
        let layout = UICollectionViewCompositionalLayout { [weak self] sectionIndex, environment in
            guard let self = self, let section = self.section(at: sectionIndex) else { return Self.placeholderSection() }
            switch section {
            case .editImage:
                return self.createEditImageSection(environment: environment)
            case .recents:
                return self.createRecentsSection(environment: environment)
            case .presets:
                return self.createPopularSection(environment: environment)
            case .moreEdits:
                return self.createMoreEditsSection(environment: environment)
            case .quickActions:
                return self.createQuickActionsSection(environment: environment)
            case .creativePrompts:
                return self.createCreativePromptsSection(environment: environment)
            case .stylePresets:
                return self.createStylePresetsSection(environment: environment)
            case .promptModifiers:
                return self.createPromptModifiersSection(environment: environment)
            }
        }
        let config = UICollectionViewCompositionalLayoutConfiguration()
        config.interSectionSpacing = Self.sectionSpacing
        layout.configuration = config
        return layout
    }
    private static func placeholderSection() -> NSCollectionLayoutSection {
        let size = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .absolute(1))
        let group = NSCollectionLayoutGroup.horizontal(layoutSize: size, subitems: [NSCollectionLayoutItem(layoutSize: size)])
        return NSCollectionLayoutSection(group: group)
    }
    private func isTextEnlarged(_ environment: NSCollectionLayoutEnvironment) -> Bool {
        environment.traitCollection.preferredContentSizeCategory > .large
    }
    /// `base` points at the default text size, growing with Dynamic Type up to `cap` times so a
    /// tile keeps room for its label without taking over the screen.
    private func scaledSize(_ base: CGFloat, _ environment: NSCollectionLayoutEnvironment, cap: CGFloat = 2) -> CGFloat {
        let scaled = UIFontMetrics.default.scaledValue(for: base, compatibleWith: environment.traitCollection)
        return min(max(base, scaled), base * cap)
    }
    /// A fixed height at the default text size, and a self-sizing one when the text is larger
    /// so a label never clips inside its tile.
    private func rowHeight(_ base: CGFloat, _ environment: NSCollectionLayoutEnvironment) -> NSCollectionLayoutDimension {
        isTextEnlarged(environment) ? .estimated(base) : .absolute(base)
    }
    private func sectionHeader(estimatedHeight: CGFloat = 56) -> NSCollectionLayoutBoundarySupplementaryItem {
        let size = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .estimated(estimatedHeight))
        return NSCollectionLayoutBoundarySupplementaryItem(layoutSize: size, elementKind: UICollectionView.elementKindSectionHeader, alignment: .top)
    }
    /// In a short window the drop zone sits beside the sample card when the row is wide enough for both.
    private var sharesRowWithSample: Bool {
        let width = bounds.width - 2 * Theme.screenMargin(for: traitCollection)
        let hasSample = editSectionItems.contains { ($0 as? String) == Self.sampleTileItem }
        return isCompactHeight && hasSample && min(width, Theme.Width.form) >= Self.compactSideBySideWidth
    }
    private func createEditImageSection(environment: NSCollectionLayoutEnvironment) -> NSCollectionLayoutSection {
        let metrics = Metrics(environment, maxWidth: Theme.Width.form)
        let compact = isCompactHeight
        let sideBySide = sharesRowWithSample
        let group: NSCollectionLayoutGroup
        if sideBySide {
            let gap = Theme.Space.md
            let rowHeight = max(SampleTileCell.height(forWidth: (metrics.contentWidth - gap) / 2), isVeryShort ? PhotoDropZoneCell.compactRowHeight : PhotoDropZoneCell.compactHeight)
            let item = NSCollectionLayoutItem(layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(0.5), heightDimension: .fractionalHeight(1.0)))
            let groupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .absolute(rowHeight))
            group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, repeatingSubitem: item, count: 2)
            group.interItemSpacing = .fixed(gap)
        } else {
            let items = editSectionItems.map { item -> NSCollectionLayoutItem in
                let height: CGFloat
                if (item as? String) == Self.sampleTileItem {
                    height = SampleTileCell.height(forWidth: metrics.contentWidth)
                } else if (item as? String) == Self.selectedPhotoItem {
                    height = SelectedPhotoCell.height(forWidth: metrics.contentWidth, compact: compact)
                } else {
                    height = compact ? PhotoDropZoneCell.compactRowHeight : metrics.contentWidth * 9 / 16
                }
                let isDropZone = (item as? String) == Self.addImageItem
                return NSCollectionLayoutItem(layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: isDropZone && !compact ? .estimated(height) : .absolute(height)))
            }
            let groupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .estimated(240))
            group = NSCollectionLayoutGroup.vertical(layoutSize: groupSize, subitems: items) // duo-audit:ignore vertical group: the hero card and the sample card stack on top of each other
            group.interItemSpacing = .fixed(Theme.Space.md)
        }
        let section = NSCollectionLayoutSection(group: group)
        section.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: metrics.sideInset, bottom: 0, trailing: metrics.sideInset)
        section.boundarySupplementaryItems = [sectionHeader()]
        return section
    }
    private func createRecentsSection(environment: NSCollectionLayoutEnvironment) -> NSCollectionLayoutSection {
        let metrics = Metrics(environment, maxWidth: Theme.Width.form)
        let side = scaledSize(72, environment, cap: 1.4)
        let itemSize = NSCollectionLayoutSize(widthDimension: .absolute(side), heightDimension: .absolute(side))
        let item = NSCollectionLayoutItem(layoutSize: itemSize)
        let group = NSCollectionLayoutGroup.horizontal(layoutSize: itemSize, subitems: [item])
        let section = NSCollectionLayoutSection(group: group)
        section.orthogonalScrollingBehavior = .continuous
        section.interGroupSpacing = Theme.Space.sm
        section.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: metrics.sideInset, bottom: 0, trailing: metrics.sideInset)
        section.boundarySupplementaryItems = [sectionHeader(estimatedHeight: 28)]
        return section
    }
    private func createPopularSection(environment: NSCollectionLayoutEnvironment) -> NSCollectionLayoutSection {
        let metrics = Metrics(environment)
        let isRegular = environment.traitCollection.horizontalSizeClass == .regular
        let baseWidth: CGFloat = isCompactHeight ? 132 : (isRegular ? 176 : 150)
        let width = scaledSize(baseWidth, environment, cap: 1.5)
        var height = (width * 4 / 3).rounded()
        var cardWidth = width
        if isVeryShort && !isTextEnlarged(environment) {
            height = max(Self.veryShortCardHeight, min(height, visibleHeight - Self.veryShortCardChrome)).rounded()
            cardWidth = max(width, height * 1.1).rounded()
        }
        let size = NSCollectionLayoutSize(widthDimension: .absolute(cardWidth), heightDimension: .absolute(height))
        let item = NSCollectionLayoutItem(layoutSize: size)
        let group = NSCollectionLayoutGroup.horizontal(layoutSize: size, subitems: [item])
        let section = NSCollectionLayoutSection(group: group)
        section.orthogonalScrollingBehavior = .continuousGroupLeadingBoundary
        section.interGroupSpacing = Theme.Space.md
        section.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: metrics.sideInset, bottom: Theme.Space.sm, trailing: metrics.sideInset)
        section.boundarySupplementaryItems = [sectionHeader()]
        return section
    }
    private func createMoreEditsSection(environment: NSCollectionLayoutEnvironment) -> NSCollectionLayoutSection {
        let metrics = Metrics(environment)
        let gap = Theme.Space.md
        let columns: Int
        if isTextEnlarged(environment) {
            columns = 1
        } else if environment.traitCollection.horizontalSizeClass == .regular {
            columns = max(2, min(4, Int((metrics.contentWidth + gap) / 232)))
        } else {
            columns = 2
        }
        let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0 / CGFloat(columns)), heightDimension: .fractionalHeight(1.0))
        let item = NSCollectionLayoutItem(layoutSize: itemSize)
        item.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: gap / 2, bottom: 0, trailing: gap / 2)
        let tileHeight = MoreEditCell.height(titleLines: isTextEnlarged(environment) ? 2 : 1)
        let groupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .absolute(tileHeight))
        let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, repeatingSubitem: item, count: columns)
        let section = NSCollectionLayoutSection(group: group)
        section.interGroupSpacing = gap
        section.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: metrics.sideInset - gap / 2, bottom: 0, trailing: metrics.sideInset - gap / 2)
        let header = sectionHeader()
        header.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: gap / 2, bottom: 0, trailing: gap / 2)
        section.boundarySupplementaryItems = [header]
        return section
    }
    private func createQuickActionsSection(environment: NSCollectionLayoutEnvironment) -> NSCollectionLayoutSection {
        let metrics = Metrics(environment)
        let actions = isEditMode ? editModeQuickActions : quickActions
        let widths = actions.map { ChipSizing.width(title: $0.title, symbol: $0.icon) }
        let group = wrappedChipsGroup(widths: widths, available: metrics.contentWidth, breakBefore: nil, environment: environment)
        let section = NSCollectionLayoutSection(group: group)
        section.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: metrics.sideInset, bottom: 0, trailing: metrics.sideInset)
        section.boundarySupplementaryItems = [sectionHeader()]
        return section
    }
    private func createCreativePromptsSection(environment: NSCollectionLayoutEnvironment) -> NSCollectionLayoutSection {
        let metrics = Metrics(environment)
        let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: rowHeight(64, environment))
        let item = NSCollectionLayoutItem(layoutSize: itemSize)
        item.contentInsets = NSDirectionalEdgeInsets(top: 2, leading: 0, bottom: 2, trailing: 0)
        let groupWidth: NSCollectionLayoutDimension = isTextEnlarged(environment) ? .fractionalWidth(0.8) : .absolute(min(metrics.contentWidth * 0.62, 340))
        let groupSize = NSCollectionLayoutSize(widthDimension: groupWidth, heightDimension: rowHeight(136, environment))
        let group = NSCollectionLayoutGroup.vertical(layoutSize: groupSize, repeatingSubitem: item, count: 2) // duo-audit:ignore vertical group: each item spans the group width and the two stack on top of each other
        group.interItemSpacing = .fixed(Theme.Space.sm)
        let section = NSCollectionLayoutSection(group: group)
        section.orthogonalScrollingBehavior = .continuous
        section.interGroupSpacing = Theme.Space.md
        section.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: metrics.sideInset, bottom: 0, trailing: metrics.sideInset)
        section.boundarySupplementaryItems = [sectionHeader(estimatedHeight: 140)]
        return section
    }
    private func createStylePresetsSection(environment: NSCollectionLayoutEnvironment) -> NSCollectionLayoutSection {
        let metrics = Metrics(environment)
        let width = scaledSize(176, environment)
        let itemSize = NSCollectionLayoutSize(widthDimension: .absolute(width), heightDimension: rowHeight(60, environment))
        let item = NSCollectionLayoutItem(layoutSize: itemSize)
        let groupSize = NSCollectionLayoutSize(widthDimension: .absolute(width), heightDimension: rowHeight(128, environment))
        let group = NSCollectionLayoutGroup.vertical(layoutSize: groupSize, repeatingSubitem: item, count: 2) // duo-audit:ignore vertical group: each item spans the group width and the two stack on top of each other
        group.interItemSpacing = .fixed(Theme.Space.sm)
        let section = NSCollectionLayoutSection(group: group)
        section.orthogonalScrollingBehavior = .continuous
        section.interGroupSpacing = Theme.Space.sm
        section.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: metrics.sideInset, bottom: 0, trailing: metrics.sideInset)
        section.boundarySupplementaryItems = [sectionHeader()]
        return section
    }
    private func createPromptModifiersSection(environment: NSCollectionLayoutEnvironment) -> NSCollectionLayoutSection {
        let metrics = Metrics(environment)
        let categoryWidths = modifierCategories.map { ChipSizing.width(title: $0, symbol: nil) }
        let modifierWidths = modifiers[selectedModifierCategory].map { ChipSizing.width(title: $0, symbol: nil) }
        let group = wrappedChipsGroup(widths: categoryWidths + modifierWidths, available: metrics.contentWidth, breakBefore: categoryWidths.count, environment: environment)
        let section = NSCollectionLayoutSection(group: group)
        section.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: metrics.sideInset, bottom: 0, trailing: metrics.sideInset)
        section.boundarySupplementaryItems = [sectionHeader()]
        return section
    }
    /// Chips laid out in reading order (the layout mirrors them for right-to-left) and wrapped onto new rows by their measured widths. Each cell is a
    /// 44-point-tall touch target around a smaller pill; `breakBefore` starts a fresh row at that index.
    private func wrappedChipsGroup(widths: [CGFloat], available: CGFloat, breakBefore: Int?, environment: NSCollectionLayoutEnvironment) -> NSCollectionLayoutGroup {
        let rowHeight = Self.chipRowHeight
        let columnSpacing = Theme.Space.sm
        var frames: [CGRect] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        for (index, rawWidth) in widths.enumerated() {
            let width = min(rawWidth, available)
            if x > 0 && (x + width > available || index == breakBefore) {
                x = 0
                y += rowHeight
            }
            frames.append(CGRect(x: x, y: y, width: width, height: rowHeight))
            x += width + columnSpacing
        }
        let height = frames.isEmpty ? 1 : y + rowHeight
        let size = NSCollectionLayoutSize(widthDimension: .absolute(available), heightDimension: .absolute(height))
        return NSCollectionLayoutGroup.custom(layoutSize: size) { _ in
            frames.map { NSCollectionLayoutGroupCustomItem(frame: $0) }
        }
    }
    private func setupDataSource() {
        dataSource = UICollectionViewDiffableDataSource<SuggestionsSection, AnyHashable>(collectionView: collectionView) { [weak self] collectionView, indexPath, item in
            guard let self = self else { return nil }
            switch self.section(at: indexPath.section) {
            case .editImage:
                if let marker = item as? String, marker == Self.sampleTileItem {
                    return collectionView.dequeueReusableCell(withReuseIdentifier: SampleTileCell.reuseIdentifier, for: indexPath)
                }
                if let marker = item as? String, marker == Self.selectedPhotoItem {
                    let cell = collectionView.dequeueReusableCell(withReuseIdentifier: SelectedPhotoCell.reuseIdentifier, for: indexPath) as! SelectedPhotoCell
                    cell.configure(with: self.selectedPhoto, canRemove: self.onPhotoRemoved != nil, compact: self.isCompactHeight)
                    cell.onChange = { [weak self] in self?.onEditImageTapped?() }
                    cell.onRemove = { [weak self] in self?.onPhotoRemoved?() }
                    return cell
                }
                let dropZone = collectionView.dequeueReusableCell(withReuseIdentifier: PhotoDropZoneCell.reuseIdentifier, for: indexPath) as! PhotoDropZoneCell
                dropZone.configure(compact: self.isCompactHeight, stacksVertically: self.sharesRowWithSample && !self.isVeryShort)
                return dropZone
            case .recents:
                let cell = collectionView.dequeueReusableCell(withReuseIdentifier: ImageCell.reuseIdentifier, for: indexPath) as! ImageCell
                cell.configure(with: item as? UIImage)
                return cell
            case .presets:
                let cell = collectionView.dequeueReusableCell(withReuseIdentifier: PresetCell.reuseIdentifier, for: indexPath) as! PresetCell
                if let preset = item as? EditPreset {
                    cell.configure(with: preset)
                }
                return cell
            case .moreEdits:
                let cell = collectionView.dequeueReusableCell(withReuseIdentifier: MoreEditCell.reuseIdentifier, for: indexPath) as! MoreEditCell
                if let preset = item as? EditPreset {
                    cell.configure(with: preset)
                }
                return cell
            case .quickActions:
                let cell = collectionView.dequeueReusableCell(withReuseIdentifier: QuickActionCell.reuseIdentifier, for: indexPath) as! QuickActionCell
                let actions = self.isEditMode ? self.editModeQuickActions : self.quickActions
                let action = actions[indexPath.item]
                let isSelected = self.selectedSuggestionsManager?.isSelected(action.title, type: .quickAction) ?? false
                let category = self.isEditMode ? String(localized: "Edit") : String(localized: "Template")
                cell.configure(with: action, isSelected: isSelected, category: category)
                return cell
            case .creativePrompts:
                let cell = collectionView.dequeueReusableCell(withReuseIdentifier: PromptCardCell.reuseIdentifier, for: indexPath) as! PromptCardCell
                let prompts = self.creativePrompts[self.selectedCreativeCategory].prompts
                if indexPath.item < prompts.count {
                    let prompt = prompts[indexPath.item]
                    let isSelected = self.selectedSuggestionsManager?.isSelected(prompt, type: .creativePrompt) ?? false
                    cell.configure(with: prompt, color: self.creativePrompts[self.selectedCreativeCategory].color, isSelected: isSelected, category: self.creativePrompts[self.selectedCreativeCategory].category)
                }
                return cell
            case .stylePresets:
                let cell = collectionView.dequeueReusableCell(withReuseIdentifier: StylePresetCell.reuseIdentifier, for: indexPath) as! StylePresetCell
                let style = self.stylePresets[indexPath.item]
                let isSelected = self.selectedSuggestionsManager?.isSelected(style.name, type: .stylePreset) ?? false
                cell.configure(with: style, isSelected: isSelected)
                return cell
            case .promptModifiers:
                if indexPath.item < self.modifierCategories.count {
                    let cell = collectionView.dequeueReusableCell(withReuseIdentifier: CategoryChipCell.reuseIdentifier, for: indexPath) as! CategoryChipCell
                    cell.configure(with: self.modifierCategories[indexPath.item])
                    cell.isSelected = indexPath.item == self.selectedModifierCategory
                    return cell
                } else {
                    let modifierIndex = indexPath.item - self.modifierCategories.count
                    let modifiers = self.modifiers[self.selectedModifierCategory]
                    if modifierIndex < modifiers.count {
                        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: ModifierChipCell.reuseIdentifier, for: indexPath) as! ModifierChipCell
                        let modifier = modifiers[modifierIndex]
                        let isSelected = self.selectedSuggestionsManager?.isSelected(modifier, type: .promptModifier) ?? false
                        cell.configure(with: modifier, isSelected: isSelected, category: self.modifierCategories[self.selectedModifierCategory])
                        return cell
                    }
                }
            case .none:
                return nil
            }
            return nil
        }
        dataSource.supplementaryViewProvider = { [weak self] (collectionView: UICollectionView, kind: String, indexPath: IndexPath) -> UICollectionReusableView? in
            guard let self = self, let section = self.section(at: indexPath.section) else { return UICollectionReusableView() }
            let inset = Metrics(width: collectionView.bounds.width, traits: collectionView.traitCollection, maxWidth: Self.maxContentWidth(of: section)).sideInset
            switch section {
            case .creativePrompts:
                let header = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: CreativePromptsHeaderView.reuseIdentifier, for: indexPath) as! CreativePromptsHeaderView
                header.horizontalInset = inset
                header.configure(
                    categories: self.creativePrompts,
                    selectedIndex: self.selectedCreativeCategory,
                    onCategorySelected: { [weak self] index in
                        self?.haptics.selectionChanged()
                        self?.selectedCreativeCategory = index
                        self?.applySnapshot()
                    }
                )
                return header
            default:
                let header = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: SuggestionsSectionHeaderView.reuseIdentifier, for: indexPath) as! SuggestionsSectionHeaderView
                                switch section {
                case .editImage:
                    if self.selectedPhoto != nil {
                        header.configure(title: String(localized: "Your photo"), subtitle: nil, prominence: self.isCompactHeight ? .section : .hero)
                    } else {
                        header.configure(title: String(localized: "Start with a photo"), subtitle: String(localized: "Pick one, then tap an edit"), prominence: self.isCompactHeight ? .section : .hero)
                    }
                case .recents:
                    header.configure(title: String(localized: "Recent"), subtitle: nil, prominence: .label)
                case .presets:
                    header.configure(title: String(localized: "Popular edits"), subtitle: nil, prominence: self.isVeryShort ? .label : .section)
                case .moreEdits:
                    header.configure(title: String(localized: "More edits"), subtitle: nil)
                case .quickActions:
                    if self.isEditMode {
                        header.configure(title: String(localized: "Mix your own edit"), subtitle: String(localized: "Tap ideas to build a prompt"))
                    } else {
                        header.configure(title: String(localized: "Create from text"), subtitle: String(localized: "Start from a template"))
                    }
                case .stylePresets:
                    header.configure(title: String(localized: "Style Presets"), subtitle: String(localized: "Apply to any prompt with ' + style'"))
                case .promptModifiers:
                    header.configure(title: String(localized: "Prompt Modifiers"), subtitle: String(localized: "Add these to enhance your prompts"))
                default:
                    break
                }
                return header
            }
        }
        applySnapshot()
    }
    /// The sample photo is for people who have not made an image yet, and only while no photo of
    /// their own is already picked.
    private var showsSampleTile: Bool {
        selectedPhoto == nil && ReviewPrompt.successfulGenerationCount == 0
    }
    private func applySnapshot() {
        var snapshot = NSDiffableDataSourceSnapshot<SuggestionsSection, AnyHashable>()
        let popularFirst = isVeryShort && selectedPhoto != nil
        if popularFirst {
            snapshot.appendSections([.presets])
            snapshot.appendItems(popularPresets.map { $0 as AnyHashable }, toSection: .presets)
        }
        snapshot.appendSections([.editImage])
        var editItems: [AnyHashable] = []
        if selectedPhoto != nil {
            editItems.append(Self.selectedPhotoItem as AnyHashable)
        } else {
            editItems.append(Self.addImageItem as AnyHashable)
            if showsSampleTile {
                editItems.append(Self.sampleTileItem as AnyHashable)
            }
        }
        editSectionItems = editItems
        snapshot.appendItems(editItems, toSection: .editImage)
        if !recentImages.isEmpty && !isCompactHeight {
            snapshot.appendSections([.recents])
            snapshot.appendItems(recentImages.prefix(10).map { $0 as AnyHashable }, toSection: .recents)
        }
        if !popularFirst {
            snapshot.appendSections([.presets])
            snapshot.appendItems(popularPresets.map { $0 as AnyHashable }, toSection: .presets)
        }
        snapshot.appendSections([.moreEdits])
        snapshot.appendItems(moreEditPresets.map { $0 as AnyHashable }, toSection: .moreEdits)
        snapshot.appendSections([.quickActions])
        let actions = isEditMode ? editModeQuickActions : quickActions
        snapshot.appendItems(actions.map { $0 as AnyHashable }, toSection: .quickActions)
        snapshot.appendSections([.creativePrompts])
        let creativeItems = creativePrompts[selectedCreativeCategory].prompts.map { $0 as AnyHashable }
        snapshot.appendItems(creativeItems, toSection: .creativePrompts)
        snapshot.appendSections([.stylePresets])
        snapshot.appendItems(stylePresets.map { $0 as AnyHashable }, toSection: .stylePresets)
        snapshot.appendSections([.promptModifiers])
        var modifierItems: [AnyHashable] = modifierCategories.map { $0 as AnyHashable }
        modifierItems.append(contentsOf: modifiers[selectedModifierCategory].map { $0 as AnyHashable })
        snapshot.appendItems(modifierItems, toSection: .promptModifiers)
        dataSource.apply(snapshot, animatingDifferences: true)
    }
    private func checkPhotoPermissions() {
        #if DEBUG
        if DemoMode.isActive {
            recentImages = DemoContent.recentPhotos()
            applySnapshot()
            return
        }
        #endif
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        if status == .authorized || status == .limited {
            loadRecentImages()
        }
    }
    
    func refreshRecentImages() {
        checkPhotoPermissions()
        applySnapshot()
    }
    private func loadRecentImages() {
        let fetchOptions = PHFetchOptions()
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        fetchOptions.fetchLimit = 20
        let fetchResult = PHAsset.fetchAssets(with: .image, options: fetchOptions)
        let manager = PHImageManager.default()
        let options = PHImageRequestOptions()
        options.isSynchronous = false
        options.deliveryMode = .highQualityFormat
        options.resizeMode = .fast
        options.isNetworkAccessAllowed = true
        var images: [UIImage] = []
        let scale = traitCollection.displayScale
        let targetSize = CGSize(width: 240 * scale, height: 240 * scale)
        fetchResult.enumerateObjects { asset, _, _ in
            manager.requestImage(for: asset, targetSize: targetSize, contentMode: .aspectFill, options: options) { image, _ in
                if let image = image {
                    images.append(image)
                    if images.count == fetchResult.count || images.count == 10 {
                        DispatchQueue.main.async { [weak self] in
                            self?.recentImages = images
                            self?.applySnapshot()
                        }
                    }
                }
            }
        }
    }
}


extension FullScreenSuggestionsView: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        haptics.impact(.click)
        switch section(at: indexPath.section) {
        case .editImage:
            let item = dataSource.itemIdentifier(for: indexPath)
            if let marker = item as? String, marker == Self.addImageItem {
                onEditImageTapped?()
            } else if let marker = item as? String, marker == Self.sampleTileItem {
                onSampleTapped?()
            }
        case .recents:
            if let image = dataSource.itemIdentifier(for: indexPath) as? UIImage {
                onImageTapped?(image)
            }
        case .presets, .moreEdits:
            if let preset = dataSource.itemIdentifier(for: indexPath) as? EditPreset {
                onPresetSelected?(preset)
            }
        case .quickActions:
            let actions = isEditMode ? editModeQuickActions : quickActions
            if indexPath.item < actions.count {
                let action = actions[indexPath.item]
                let suggestion = SelectedSuggestion(
                    type: .quickAction,
                    title: action.title,
                    prompt: action.prompt,
                    color: action.color,
                    icon: action.icon
                )
                selectedSuggestionsManager?.toggleSelection(suggestion)
                applySnapshot()
                onSelectionChanged?()
            }
        case .creativePrompts:
            let prompts = creativePrompts[selectedCreativeCategory].prompts
            if indexPath.item < prompts.count {
                let creative = creativePrompts[selectedCreativeCategory]
                let suggestion = SelectedSuggestion(
                    type: .creativePrompt,
                    title: prompts[indexPath.item],
                    prompt: prompts[indexPath.item],
                    color: creative.color,
                    icon: creative.symbol
                )
                selectedSuggestionsManager?.toggleSelection(suggestion)
                applySnapshot()
                onSelectionChanged?()
            }
        case .stylePresets:
            if indexPath.item < stylePresets.count {
                let style = stylePresets[indexPath.item]
                let suggestion = SelectedSuggestion(
                    type: .stylePreset,
                    title: style.name,
                    prompt: style.prompt,
                    color: style.gradientColors.first ?? .systemBlue,
                    icon: style.icon
                )
                selectedSuggestionsManager?.toggleSelection(suggestion)
                applySnapshot()
                onSelectionChanged?()
            }
        case .promptModifiers:
            if indexPath.item < modifierCategories.count {
                selectedModifierCategory = indexPath.item
                applySnapshot()
            } else {
                let modifierIndex = indexPath.item - modifierCategories.count
                let modifiers = self.modifiers[selectedModifierCategory]
                if modifierIndex < modifiers.count {
                    let modifier = modifiers[modifierIndex]
                    let suggestion = SelectedSuggestion(
                        type: .promptModifier,
                        title: modifier,
                        prompt: modifier,
                        color: .systemGray,
                        icon: nil
                    )
                    selectedSuggestionsManager?.toggleSelection(suggestion)
                    applySnapshot()
                    onSelectionChanged?()
                }
            }
        case .none:
            break
        }
    }
    func collectionView(_ collectionView: UICollectionView, shouldHighlightItemAt indexPath: IndexPath) -> Bool {
        if let marker = dataSource.itemIdentifier(for: indexPath) as? String, marker == Self.selectedPhotoItem {
            return false
        }
        return true
    }
    func collectionView(_ collectionView: UICollectionView, shouldSelectItemAt indexPath: IndexPath) -> Bool {
        if let marker = dataSource.itemIdentifier(for: indexPath) as? String, marker == Self.selectedPhotoItem {
            return false
        }
        return true
    }
    func collectionView(_ collectionView: UICollectionView, didHighlightItemAt indexPath: IndexPath) {
        animateCell(at: indexPath, highlighted: true)
    }
    func collectionView(_ collectionView: UICollectionView, didUnhighlightItemAt indexPath: IndexPath) {
        animateCell(at: indexPath, highlighted: false)
    }
    private func animateCell(at indexPath: IndexPath, highlighted: Bool) {
        guard let cell = collectionView.cellForItem(at: indexPath) else { return }
        Motion.animate(0.1, options: [.beginFromCurrentState, .allowUserInteraction]) {
            if Motion.isReduced {
                cell.alpha = highlighted ? 0.7 : 1
            } else {
                cell.transform = highlighted ? CGAffineTransform(scaleX: 0.97, y: 0.97) : .identity
            }
        }
    }
    func refreshView() {
        applySnapshot()
    }
    func setEditMode(_ editMode: Bool, photo: UIImage? = nil) {
        isEditMode = editMode
        selectedPhoto = editMode ? photo : nil
        applySnapshot()
        var snapshot = dataSource.snapshot()
        snapshot.reloadSections([.editImage, .quickActions])
        dataSource.apply(snapshot, animatingDifferences: false)
        if editMode {
            collectionView.setContentOffset(CGPoint(x: 0, y: -collectionView.adjustedContentInset.top), animated: true)
        }
    }
    
    var contentInset: UIEdgeInsets {
        get { collectionView.contentInset }
        set { 
            collectionView.contentInset = newValue
            collectionView.scrollIndicatorInsets = UIEdgeInsets.zero
            setNeedsLayout()
        }
    }
    
    var scrollIndicatorInsets: UIEdgeInsets {
        get { collectionView.scrollIndicatorInsets }
        set { collectionView.scrollIndicatorInsets = newValue }
    }
}




enum SuggestionsSection: Int, CaseIterable {
    case editImage
    case recents
    case presets
    case moreEdits
    case quickActions
    case creativePrompts
    case stylePresets
    case promptModifiers
}


struct QuickAction: Hashable {
    let icon: String
    let title: String
    let prompt: String
    let color: UIColor
}

struct CreativePrompt: Hashable {
    let category: String
    let symbol: String
    let prompts: [String]
    let color: UIColor
}

struct StylePreset: Hashable {
    let name: String
    let description: String
    let prompt: String
    let icon: String
    let gradientColors: [UIColor]
}
