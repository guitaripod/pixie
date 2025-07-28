import UIKit
import Photos

// MARK: - View State
enum SuggestionsViewState {
    case suggestions
    case chat
}

// MARK: - Full Screen Suggestions View
class FullScreenSuggestionsView: UIView {
    
    // MARK: - Properties
    private lazy var collectionView: UICollectionView = {
        let layout = createLayout()
        let cv = UICollectionView(frame: .zero, collectionViewLayout: layout)
        cv.backgroundColor = .systemBackground
        cv.contentInsetAdjustmentBehavior = .automatic
        cv.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 80, right: 0)
        cv.scrollIndicatorInsets = UIEdgeInsets(top: 0, left: 0, bottom: 80, right: 0)
        cv.delegate = self
        return cv
    }()
    
    private var dataSource: UICollectionViewDiffableDataSource<SuggestionsSection, AnyHashable>!
    var selectedSuggestionsManager: SelectedSuggestionsManager?
    var onPromptSelected: ((String) -> Void)?
    var onImageSelected: ((UIImage) -> Void)?
    var onEditImageTapped: (() -> Void)?
    var onSelectionChanged: (() -> Void)?
    private var recentImages: [UIImage] = []
    private var selectedCreativeCategory = 0
    private var selectedModifierCategory = 0
    
    private let haptics = HapticManager.shared
    
    // MARK: - Quick Actions Data
    private let quickActions = [
        QuickAction(icon: "person.crop.square", title: "Portrait", prompt: "Professional portrait photo of a person, studio lighting, high quality, sharp focus", color: UIColor(red: 0.39, green: 0.40, blue: 0.95, alpha: 1)),
        QuickAction(icon: "bolt.fill", title: "Cyberpunk", prompt: "Cyberpunk cityscape with neon lights, flying cars, rain, blade runner style", color: UIColor(red: 0.88, green: 0.08, blue: 0.28, alpha: 1)),
        QuickAction(icon: "pawprint", title: "Animals", prompt: "Adorable animal portrait, detailed fur texture, expressive eyes, natural lighting", color: UIColor(red: 0.55, green: 0.36, blue: 0.96, alpha: 1)),
        QuickAction(icon: "building.2", title: "Architecture", prompt: "Modern architecture photography, clean lines, minimalist design, professional composition", color: UIColor(red: 0.94, green: 0.27, blue: 0.27, alpha: 1)),
        QuickAction(icon: "mountain.2", title: "Landscape", prompt: "Breathtaking landscape photography, golden hour lighting, dramatic sky, high resolution", color: UIColor(red: 0.06, green: 0.59, blue: 0.53, alpha: 1)),
        QuickAction(icon: "wand.and.stars", title: "Fantasy", prompt: "Epic fantasy landscape with magical elements, dragons, castles, mystical atmosphere", color: UIColor(red: 0.49, green: 0.23, blue: 0.93, alpha: 1)),
        QuickAction(icon: "paintbrush", title: "Digital Art", prompt: "Digital artwork, vibrant colors, detailed illustration, professional quality", color: UIColor(red: 0.96, green: 0.62, blue: 0.04, alpha: 1)),
        QuickAction(icon: "fork.knife", title: "Food", prompt: "Professional food photography, appetizing presentation, restaurant quality, shallow depth of field", color: UIColor(red: 0.93, green: 0.17, blue: 0.60, alpha: 1)),
        QuickAction(icon: "sparkle", title: "Space", prompt: "Stunning space scene with galaxies, nebulas, planets, cosmic colors", color: UIColor(red: 0.12, green: 0.16, blue: 0.22, alpha: 1)),
        QuickAction(icon: "leaf", title: "Macro", prompt: "Extreme macro photography, intricate details, shallow depth of field, professional quality", color: UIColor(red: 0.06, green: 0.46, blue: 0.43, alpha: 1)),
        QuickAction(icon: "moon", title: "Surreal", prompt: "Surreal dreamscape with impossible geometry, floating objects, Salvador Dali style", color: UIColor(red: 0.43, green: 0.16, blue: 0.85, alpha: 1)),
        QuickAction(icon: "camera.filters", title: "Retro", prompt: "80s retro style with synthwave colors, palm trees, sunset, miami vice aesthetic", color: UIColor(red: 0.86, green: 0.15, blue: 0.47, alpha: 1)),
        QuickAction(icon: "drop", title: "Underwater", prompt: "Underwater photography, coral reef, tropical fish, sun rays through water", color: UIColor(red: 0.01, green: 0.52, blue: 0.78, alpha: 1)),
        QuickAction(icon: "square.grid.3x3", title: "Miniature", prompt: "Miniature tilt-shift photography effect, looks like a tiny model world", color: UIColor(red: 0.98, green: 0.45, blue: 0.09, alpha: 1))
    ]
    
    // MARK: - Creative Prompts Data
    private let creativePrompts = [
        CreativePrompt(category: "Fantasy", emoji: "🐉", prompts: [
            "Majestic dragon soaring through cloudy skies, fantasy art style",
            "Futuristic city with flying cars and neon lights at night",
            "Magical forest with glowing mushrooms and fairy lights",
            "Space station orbiting a distant planet with multiple moons",
            "Steampunk airship floating above Victorian London",
            "Enchanted castle on floating island in the clouds"
        ], color: UIColor(red: 0.58, green: 0.2, blue: 0.92, alpha: 1)),
        CreativePrompt(category: "Nature", emoji: "🌿", prompts: [
            "Majestic eagle soaring over mountain peaks at sunrise",
            "Underwater coral reef teeming with colorful tropical fish",
            "Northern lights dancing over a frozen lake in winter",
            "Ancient tree with twisted roots in misty forest",
            "Butterfly garden with hundreds of colorful butterflies",
            "Thunderstorm over dramatic desert landscape"
        ], color: UIColor(red: 0.02, green: 0.59, blue: 0.41, alpha: 1)),
        CreativePrompt(category: "Abstract", emoji: "🎨", prompts: [
            "Vibrant abstract painting with swirling colors and geometric shapes",
            "Minimalist composition with bold colors and clean lines",
            "Surreal dreamscape with floating objects and impossible geometry",
            "Pop art style portrait with bright colors and comic book aesthetics",
            "Impressionist painting of a sunset over lavender fields",
            "Fractal patterns with infinite complexity and vivid colors"
        ], color: UIColor(red: 0.86, green: 0.15, blue: 0.15, alpha: 1)),
        CreativePrompt(category: "Urban", emoji: "🏙️", prompts: [
            "High fashion photoshoot in minimalist studio setting",
            "Cozy coffee shop interior with warm lighting and plants",
            "Street style fashion photography in urban setting",
            "Luxury spa interior with zen garden and natural materials",
            "Modern home office with scandinavian design aesthetic",
            "Bustling city street at night with neon signs"
        ], color: UIColor(red: 0.86, green: 0.15, blue: 0.47, alpha: 1)),
        CreativePrompt(category: "Tech", emoji: "🤖", prompts: [
            "Advanced AI robot assistant helping in modern home",
            "Holographic interface displaying complex data visualization",
            "Electric vehicle charging station of the future",
            "Virtual reality user exploring digital worlds",
            "Quantum computer in high-tech laboratory setting",
            "Cybernetic augmentations on human body"
        ], color: UIColor(red: 0.15, green: 0.39, blue: 0.92, alpha: 1))
    ]
    
    // MARK: - Style Presets Data
    private let stylePresets = [
        StylePreset(name: "Cinematic", description: "Movie-like", prompt: "cinematic shot, movie still, film grain, dramatic lighting, wide angle lens", icon: "film", gradientColors: [UIColor(red: 0.12, green: 0.16, blue: 0.22, alpha: 1), UIColor(red: 0.22, green: 0.26, blue: 0.32, alpha: 1)]),
        StylePreset(name: "Anime", description: "Japanese art", prompt: "anime style, manga art, cel shading, vibrant colors, detailed character design", icon: "star.circle", gradientColors: [UIColor(red: 0.93, green: 0.28, blue: 0.6, alpha: 1), UIColor(red: 0.96, green: 0.45, blue: 0.71, alpha: 1)]),
        StylePreset(name: "3D Render", description: "CGI graphics", prompt: "3D render, octane render, ray tracing, photorealistic, high detail, studio lighting", icon: "cube", gradientColors: [UIColor(red: 0.23, green: 0.51, blue: 0.96, alpha: 1), UIColor(red: 0.38, green: 0.65, blue: 0.98, alpha: 1)]),
        StylePreset(name: "Oil Paint", description: "Classic art", prompt: "oil painting, traditional art, brush strokes visible, museum quality, masterpiece", icon: "paintpalette", gradientColors: [UIColor(red: 0.94, green: 0.27, blue: 0.27, alpha: 1), UIColor(red: 0.97, green: 0.44, blue: 0.44, alpha: 1)]),
        StylePreset(name: "Sketch", description: "Pencil art", prompt: "pencil sketch, detailed drawing, graphite on paper, artistic shading, hand drawn", icon: "pencil", gradientColors: [UIColor(red: 0.42, green: 0.45, blue: 0.50, alpha: 1), UIColor(red: 0.61, green: 0.64, blue: 0.69, alpha: 1)]),
        StylePreset(name: "Watercolor", description: "Soft painting", prompt: "watercolor painting, soft edges, flowing colors, artistic bleeds, paper texture", icon: "paintbrush", gradientColors: [UIColor(red: 0.38, green: 0.65, blue: 0.98, alpha: 1), UIColor(red: 0.58, green: 0.77, blue: 0.99, alpha: 1)]),
        StylePreset(name: "Comic", description: "Comic book", prompt: "comic book style, bold outlines, halftone dots, speech bubbles, superhero aesthetic", icon: "book", gradientColors: [UIColor(red: 0.98, green: 0.75, blue: 0.14, alpha: 1), UIColor(red: 0.99, green: 0.88, blue: 0.28, alpha: 1)]),
        StylePreset(name: "Pixel Art", description: "8-bit style", prompt: "pixel art, 8-bit style, retro game aesthetic, limited color palette, blocky design", icon: "gamecontroller", gradientColors: [UIColor(red: 0.06, green: 0.72, blue: 0.51, alpha: 1), UIColor(red: 0.20, green: 0.83, blue: 0.60, alpha: 1)]),
        StylePreset(name: "Neon", description: "Glowing lights", prompt: "neon lights, glowing effects, cyberpunk aesthetic, dark background, vibrant colors", icon: "lightbulb", gradientColors: [UIColor(red: 0.88, green: 0.11, blue: 0.28, alpha: 1), UIColor(red: 0.95, green: 0.25, blue: 0.37, alpha: 1)]),
        StylePreset(name: "Minimal", description: "Simple clean", prompt: "minimalist style, simple composition, negative space, clean lines, modern aesthetic", icon: "square.dashed", gradientColors: [UIColor(red: 0.22, green: 0.26, blue: 0.32, alpha: 1), UIColor(red: 0.29, green: 0.33, blue: 0.39, alpha: 1)]),
        StylePreset(name: "Vintage", description: "Retro look", prompt: "vintage photography, film grain, faded colors, nostalgic mood, old camera effect", icon: "camera", gradientColors: [UIColor(red: 0.57, green: 0.25, blue: 0.05, alpha: 1), UIColor(red: 0.70, green: 0.33, blue: 0.04, alpha: 1)]),
        StylePreset(name: "HDR", description: "High detail", prompt: "HDR photography, high dynamic range, vivid colors, sharp details, professional quality", icon: "camera.aperture", gradientColors: [UIColor(red: 0.49, green: 0.23, blue: 0.93, alpha: 1), UIColor(red: 0.55, green: 0.36, blue: 0.96, alpha: 1)])
    ]
    
    // MARK: - Modifiers Data
    private let modifierCategories = ["Quality", "Lighting", "Camera", "Mood", "Composition", "Artistic"]
    private let modifiers = [
        ["8K", "4K", "HD", "ultra detailed", "masterpiece", "best quality"],
        ["studio lighting", "golden hour", "dramatic lighting", "soft light", "backlit", "rim lighting"],
        ["DSLR", "35mm lens", "bokeh", "depth of field", "macro lens", "wide angle"],
        ["peaceful", "dramatic", "mysterious", "energetic", "melancholic", "ethereal"],
        ["rule of thirds", "centered", "symmetrical", "dynamic pose", "close-up", "full body"],
        ["trending on artstation", "award winning", "professional", "concept art", "photorealistic", "hyperrealistic"]
    ]
    
    // MARK: - Initialization
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
        setupDataSource()
        checkPhotoPermissions()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Setup
    private func setupUI() {
        backgroundColor = .systemBackground
        
        addSubview(collectionView)
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor),
            collectionView.leadingAnchor.constraint(equalTo: leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
        
        registerCells()
    }
    
    private func registerCells() {
        collectionView.register(SectionHeaderView.self, forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader, withReuseIdentifier: SectionHeaderView.reuseIdentifier)
        collectionView.register(CreativePromptsHeaderView.self, forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader, withReuseIdentifier: CreativePromptsHeaderView.reuseIdentifier)
        collectionView.register(ImageCell.self, forCellWithReuseIdentifier: ImageCell.reuseIdentifier)
        collectionView.register(QuickActionCell.self, forCellWithReuseIdentifier: QuickActionCell.reuseIdentifier)
        collectionView.register(PromptCardCell.self, forCellWithReuseIdentifier: PromptCardCell.reuseIdentifier)
        collectionView.register(StylePresetCell.self, forCellWithReuseIdentifier: StylePresetCell.reuseIdentifier)
        collectionView.register(ModifierChipCell.self, forCellWithReuseIdentifier: ModifierChipCell.reuseIdentifier)
        collectionView.register(CategoryChipCell.self, forCellWithReuseIdentifier: CategoryChipCell.reuseIdentifier)
    }
    
    // MARK: - Layout
    private func createLayout() -> UICollectionViewLayout {
        let layout = UICollectionViewCompositionalLayout { [weak self] sectionIndex, _ in
            guard let self = self,
                  let section = SuggestionsSection(rawValue: sectionIndex) else { return nil }
            
            switch section {
            case .editImage:
                return self.createEditImageSection()
            case .quickActions:
                return self.createQuickActionsSection()
            case .creativePrompts:
                return self.createCreativePromptsSection()
            case .stylePresets:
                return self.createStylePresetsSection()
            case .promptModifiers:
                return self.createPromptModifiersSection()
            }
        }
        
        let config = UICollectionViewCompositionalLayoutConfiguration()
        config.interSectionSpacing = 24
        layout.configuration = config
        
        return layout
    }
    
    private func createEditImageSection() -> NSCollectionLayoutSection {
        let itemSize = NSCollectionLayoutSize(widthDimension: .absolute(120), heightDimension: .absolute(120))
        let item = NSCollectionLayoutItem(layoutSize: itemSize)
        
        let groupSize = NSCollectionLayoutSize(widthDimension: .absolute(120), heightDimension: .absolute(120))
        let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitems: [item])
        
        let section = NSCollectionLayoutSection(group: group)
        section.orthogonalScrollingBehavior = .continuous
        section.interGroupSpacing = 12
        section.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 8, bottom: 0, trailing: 8)
        
        let headerSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .estimated(60))
        let header = NSCollectionLayoutBoundarySupplementaryItem(layoutSize: headerSize, elementKind: UICollectionView.elementKindSectionHeader, alignment: .top)
        section.boundarySupplementaryItems = [header]
        
        return section
    }
    
    private func createQuickActionsSection() -> NSCollectionLayoutSection {
        let itemSize = NSCollectionLayoutSize(widthDimension: .absolute(120), heightDimension: .absolute(40))
        let item = NSCollectionLayoutItem(layoutSize: itemSize)
        let groupSize = NSCollectionLayoutSize(widthDimension: .absolute(120), heightDimension: .absolute(136))
        let group = NSCollectionLayoutGroup.vertical(layoutSize: groupSize, subitem: item, count: 3)
        group.interItemSpacing = .fixed(8)
        
        let section = NSCollectionLayoutSection(group: group)
        section.orthogonalScrollingBehavior = .continuous
        section.interGroupSpacing = 8
        section.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 8, bottom: 0, trailing: 8)
        
        let headerSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .estimated(60))
        let header = NSCollectionLayoutBoundarySupplementaryItem(layoutSize: headerSize, elementKind: UICollectionView.elementKindSectionHeader, alignment: .top)
        section.boundarySupplementaryItems = [header]
        
        return section
    }
    
    private func createCreativePromptsSection() -> NSCollectionLayoutSection {
        let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .absolute(64))
        let item = NSCollectionLayoutItem(layoutSize: itemSize)
        item.contentInsets = NSDirectionalEdgeInsets(top: 2, leading: 2, bottom: 2, trailing: 2)
        
        let groupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(0.55), heightDimension: .absolute(132))
        let group = NSCollectionLayoutGroup.vertical(layoutSize: groupSize, subitem: item, count: 2)
        group.interItemSpacing = .fixed(4)
        
        let section = NSCollectionLayoutSection(group: group)
        section.orthogonalScrollingBehavior = .continuous
        section.interGroupSpacing = 8
        section.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 8, bottom: 0, trailing: 8)
        
        let headerSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .estimated(120))
        let header = NSCollectionLayoutBoundarySupplementaryItem(layoutSize: headerSize, elementKind: UICollectionView.elementKindSectionHeader, alignment: .top)
        section.boundarySupplementaryItems = [header]
        
        return section
    }
    
    private func createStylePresetsSection() -> NSCollectionLayoutSection {
        let itemSize = NSCollectionLayoutSize(widthDimension: .absolute(140), heightDimension: .absolute(56))
        let item = NSCollectionLayoutItem(layoutSize: itemSize)
        
        let groupSize = NSCollectionLayoutSize(widthDimension: .absolute(140), heightDimension: .absolute(120))
        let group = NSCollectionLayoutGroup.vertical(layoutSize: groupSize, subitem: item, count: 2)
        group.interItemSpacing = .fixed(8)
        
        let section = NSCollectionLayoutSection(group: group)
        section.orthogonalScrollingBehavior = .continuous
        section.interGroupSpacing = 8
        section.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 8, bottom: 0, trailing: 8)
        
        let headerSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .estimated(60))
        let header = NSCollectionLayoutBoundarySupplementaryItem(layoutSize: headerSize, elementKind: UICollectionView.elementKindSectionHeader, alignment: .top)
        section.boundarySupplementaryItems = [header]
        
        return section
    }
    
    private func createPromptModifiersSection() -> NSCollectionLayoutSection {
        let itemSize = NSCollectionLayoutSize(widthDimension: .estimated(100), heightDimension: .absolute(32))
        let item = NSCollectionLayoutItem(layoutSize: itemSize)
        
        let groupSize = NSCollectionLayoutSize(widthDimension: .estimated(100), heightDimension: .absolute(32))
        let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitems: [item])
        
        let section = NSCollectionLayoutSection(group: group)
        section.orthogonalScrollingBehavior = .continuous
        section.interGroupSpacing = 8
        section.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 8, bottom: 16, trailing: 8)
        
        let headerSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .estimated(100))
        let header = NSCollectionLayoutBoundarySupplementaryItem(layoutSize: headerSize, elementKind: UICollectionView.elementKindSectionHeader, alignment: .top)
        section.boundarySupplementaryItems = [header]
        
        return section
    }
    
    // MARK: - Data Source
    private func setupDataSource() {
        dataSource = UICollectionViewDiffableDataSource<SuggestionsSection, AnyHashable>(collectionView: collectionView) { [weak self] collectionView, indexPath, item in
            guard let self = self else { return nil }
            
            switch SuggestionsSection(rawValue: indexPath.section) {
            case .editImage:
                let cell = collectionView.dequeueReusableCell(withReuseIdentifier: ImageCell.reuseIdentifier, for: indexPath) as! ImageCell
                if indexPath.item == 0 {
                    cell.configure(with: nil, isAddButton: true)
                } else {
                    let imageIndex = indexPath.item - 1
                    if imageIndex < self.recentImages.count {
                        cell.configure(with: self.recentImages[imageIndex])
                    }
                }
                return cell
                
            case .quickActions:
                let cell = collectionView.dequeueReusableCell(withReuseIdentifier: QuickActionCell.reuseIdentifier, for: indexPath) as! QuickActionCell
                let action = self.quickActions[indexPath.item]
                let isSelected = self.selectedSuggestionsManager?.isSelected(action.title, type: .quickAction) ?? false
                cell.configure(with: action, isSelected: isSelected)
                return cell
                
            case .creativePrompts:
                let cell = collectionView.dequeueReusableCell(withReuseIdentifier: PromptCardCell.reuseIdentifier, for: indexPath) as! PromptCardCell
                let prompts = self.creativePrompts[self.selectedCreativeCategory].prompts
                if indexPath.item < prompts.count {
                    let prompt = prompts[indexPath.item]
                    let isSelected = self.selectedSuggestionsManager?.isSelected(prompt, type: .creativePrompt) ?? false
                    cell.configure(with: prompt, color: self.creativePrompts[self.selectedCreativeCategory].color, isSelected: isSelected)
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
                        cell.configure(with: modifier, isSelected: isSelected)
                        return cell
                    }
                }
                
            default:
                return nil
            }
            
            return nil
        }
        
        dataSource.supplementaryViewProvider = { [weak self] (collectionView: UICollectionView, kind: String, indexPath: IndexPath) -> UICollectionReusableView? in
            guard let self = self else { return UICollectionReusableView() }
            
            switch SuggestionsSection(rawValue: indexPath.section) {
            case .creativePrompts:
                let header = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: CreativePromptsHeaderView.reuseIdentifier, for: indexPath) as! CreativePromptsHeaderView
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
                let header = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: SectionHeaderView.reuseIdentifier, for: indexPath) as! SectionHeaderView
                
                switch SuggestionsSection(rawValue: indexPath.section) {
                case .editImage:
                    header.configure(title: "Edit an Image", subtitle: "Transform your photos with AI", actionTitle: "Browse")
                    header.actionButton.addTarget(self, action: #selector(self.browseTapped), for: .touchUpInside)
                case .quickActions:
                    header.configure(title: "Quick Actions", subtitle: "Start with popular templates")
                case .stylePresets:
                    header.configure(title: "Style Presets", subtitle: "Apply to any prompt with ' + style'")
                case .promptModifiers:
                    header.configure(title: "Prompt Modifiers", subtitle: "Add these to enhance your prompts")
                default:
                    break
                }
                
                return header
            }
        }
        
        applySnapshot()
    }
    
    private func applySnapshot() {
        var snapshot = NSDiffableDataSourceSnapshot<SuggestionsSection, AnyHashable>()
        snapshot.appendSections([.editImage])
        var editItems: [AnyHashable] = ["add_image" as AnyHashable]
        editItems.append(contentsOf: recentImages.prefix(10).map { $0 as AnyHashable })
        snapshot.appendItems(editItems, toSection: .editImage)
        snapshot.appendSections([.quickActions])
        snapshot.appendItems(quickActions.map { $0 as AnyHashable }, toSection: .quickActions)
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
    
    // MARK: - Actions
    @objc private func browseTapped() {
        haptics.impact(.click)
        presentImagePicker()
    }
    
    private func presentImagePicker() {
        PHPhotoLibrary.requestAuthorization(for: .readWrite) { [weak self] status in
            DispatchQueue.main.async {
                switch status {
                case .authorized, .limited:
                    self?.loadRecentImages()
                    if let viewController = self?.window?.rootViewController {
                        let picker = UIImagePickerController()
                        picker.sourceType = .photoLibrary
                        picker.mediaTypes = ["public.image"]
                        picker.delegate = self
                        viewController.present(picker, animated: true)
                    }
                case .denied, .restricted:

                    if let viewController = self?.window?.rootViewController {
                        let alert = UIAlertController(
                            title: "Photo Access Required",
                            message: "Please enable photo access in Settings to select images.",
                            preferredStyle: .alert
                        )
                        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
                        alert.addAction(UIAlertAction(title: "Settings", style: .default) { _ in
                            if let url = URL(string: UIApplication.openSettingsURLString) {
                                UIApplication.shared.open(url)
                            }
                        })
                        viewController.present(alert, animated: true)
                    }
                default:
                    break
                }
            }
        }
    }
    
    // MARK: - Photo Library
    private func checkPhotoPermissions() {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        if status == .authorized || status == .limited {
            loadRecentImages()
        }
    }
    
    private func loadRecentImages() {
        let fetchOptions = PHFetchOptions()
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        fetchOptions.fetchLimit = 20
        
        let fetchResult = PHAsset.fetchAssets(with: .image, options: fetchOptions)
        
        let manager = PHImageManager.default()
        let options = PHImageRequestOptions()
        options.isSynchronous = false
        options.deliveryMode = .opportunistic
        options.resizeMode = .exact
        
        var images: [UIImage] = []
        let targetSize = CGSize(width: 240, height: 240)
        
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

// MARK: - Collection View Delegate
extension FullScreenSuggestionsView: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        haptics.impact(.click)
        
        switch SuggestionsSection(rawValue: indexPath.section) {
        case .editImage:
            if indexPath.item == 0 {
                onEditImageTapped?()
            } else {
                let imageIndex = indexPath.item - 1
                if imageIndex < recentImages.count {
                    onImageSelected?(recentImages[imageIndex])
                }
            }
            
        case .quickActions:
            if indexPath.item < quickActions.count {
                let action = quickActions[indexPath.item]
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
                    icon: creative.emoji
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
            
        default:
            break
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, shouldHighlightItemAt indexPath: IndexPath) -> Bool {
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
        
        UIView.animate(
            withDuration: 0.1,
            delay: 0,
            options: [.beginFromCurrentState, .allowUserInteraction],
            animations: {
                cell.transform = highlighted ? CGAffineTransform(scaleX: 0.95, y: 0.95) : .identity
            }
        )
    }
    func refreshView() {
        applySnapshot()
    }
}

// MARK: - Image Picker Delegate
extension FullScreenSuggestionsView: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        picker.dismiss(animated: true)
        
        if let image = info[.originalImage] as? UIImage {
            haptics.notification(.success)
            onImageSelected?(image)
        }
    }
    
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true)
    }
}

// MARK: - Sections
enum SuggestionsSection: Int, CaseIterable {
    case editImage
    case quickActions
    case creativePrompts
    case stylePresets
    case promptModifiers
}

// MARK: - Data Models
struct QuickAction: Hashable {
    let icon: String
    let title: String
    let prompt: String
    let color: UIColor
}

struct CreativePrompt: Hashable {
    let category: String
    let emoji: String
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