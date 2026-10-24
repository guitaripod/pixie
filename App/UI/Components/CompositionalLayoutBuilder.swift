import UIKit

struct CompositionalLayoutBuilder {
    
    enum SectionLayoutKind {
        case grid(columns: Int, spacing: CGFloat = 8)
        case list(estimatedHeight: CGFloat = 44)
        case horizontal(itemWidth: CGFloat, itemHeight: CGFloat)
        case staggered(columnCount: Int, minimumItemWidth: CGFloat)
        case custom(sectionProvider: (Int, NSCollectionLayoutEnvironment) -> NSCollectionLayoutSection)
    }
    
    static func createLayout(
        sectionProvider: @escaping (Int) -> SectionLayoutKind
    ) -> UICollectionViewCompositionalLayout {
        UICollectionViewCompositionalLayout { sectionIndex, environment in
            let kind = sectionProvider(sectionIndex)
            return createSection(for: kind, environment: environment)
        }
    }
    
    private static func createSection(
        for kind: SectionLayoutKind,
        environment: NSCollectionLayoutEnvironment
    ) -> NSCollectionLayoutSection {
        switch kind {
        case .grid(let columns, let spacing):
            return createGridSection(columns: columns, spacing: spacing, environment: environment)
            
        case .list(let estimatedHeight):
            return createListSection(estimatedHeight: estimatedHeight)
            
        case .horizontal(let itemWidth, let itemHeight):
            return createHorizontalSection(itemWidth: itemWidth, itemHeight: itemHeight)
            
        case .staggered(let columnCount, let minimumItemWidth):
            return createStaggeredSection(
                columnCount: columnCount,
                minimumItemWidth: minimumItemWidth,
                environment: environment
            )
            
        case .custom(let sectionProvider):
            return sectionProvider(0, environment)
        }
    }
    
    private static func createGridSection(
        columns: Int,
        spacing: CGFloat,
        environment: NSCollectionLayoutEnvironment
    ) -> NSCollectionLayoutSection {
        let itemSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0 / CGFloat(columns)),
            heightDimension: .fractionalHeight(1.0)
        )
        let item = NSCollectionLayoutItem(layoutSize: itemSize)
        item.contentInsets = NSDirectionalEdgeInsets(
            top: spacing/2, leading: spacing/2, bottom: spacing/2, trailing: spacing/2
        )
        
        let groupSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0),
            heightDimension: .fractionalWidth(1.0 / CGFloat(columns))
        )
        let group = NSCollectionLayoutGroup.horizontal(
            layoutSize: groupSize,
            repeatingSubitem: item,
            count: columns
        )
        
        let section = NSCollectionLayoutSection(group: group)
        section.contentInsets = NSDirectionalEdgeInsets(
            top: spacing, leading: spacing, bottom: spacing, trailing: spacing
        )
        
        return section
    }
    
    private static func createListSection(
        estimatedHeight: CGFloat
    ) -> NSCollectionLayoutSection {
        let itemSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0),
            heightDimension: .estimated(estimatedHeight)
        )
        let item = NSCollectionLayoutItem(layoutSize: itemSize)
        
        let groupSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0),
            heightDimension: .estimated(estimatedHeight)
        )
        let group = NSCollectionLayoutGroup.vertical(
            layoutSize: groupSize,
            subitems: [item]
        )
        
        let section = NSCollectionLayoutSection(group: group)
        section.interGroupSpacing = 1
        
        return section
    }
    
    private static func createHorizontalSection(
        itemWidth: CGFloat,
        itemHeight: CGFloat
    ) -> NSCollectionLayoutSection {
        let itemSize = NSCollectionLayoutSize(
            widthDimension: .absolute(itemWidth),
            heightDimension: .absolute(itemHeight)
        )
        let item = NSCollectionLayoutItem(layoutSize: itemSize)
        item.contentInsets = NSDirectionalEdgeInsets(
            top: 4, leading: 4, bottom: 4, trailing: 4
        )
        
        let groupSize = NSCollectionLayoutSize(
            widthDimension: .absolute(itemWidth),
            heightDimension: .absolute(itemHeight)
        )
        let group = NSCollectionLayoutGroup.horizontal(
            layoutSize: groupSize,
            subitems: [item]
        )
        
        let section = NSCollectionLayoutSection(group: group)
        section.orthogonalScrollingBehavior = .continuous
        section.contentInsets = NSDirectionalEdgeInsets(
            top: 16, leading: 16, bottom: 16, trailing: 16
        )
        section.interGroupSpacing = 12
        
        return section
    }
    
    private static func createStaggeredSection(
        columnCount: Int,
        minimumItemWidth: CGFloat,
        environment: NSCollectionLayoutEnvironment
    ) -> NSCollectionLayoutSection {
        let columns = max(
            Int(environment.container.effectiveContentSize.width / minimumItemWidth),
            columnCount
        )
        
        let itemSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0 / CGFloat(columns)),
            heightDimension: .estimated(200)
        )
        let item = NSCollectionLayoutItem(layoutSize: itemSize)
        item.contentInsets = NSDirectionalEdgeInsets(
            top: 4, leading: 4, bottom: 4, trailing: 4
        )
        
        let groupSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0),
            heightDimension: .estimated(200)
        )
        let group = NSCollectionLayoutGroup.horizontal(
            layoutSize: groupSize,
            repeatingSubitem: item,
            count: columns
        )
        
        let section = NSCollectionLayoutSection(group: group)
        section.contentInsets = NSDirectionalEdgeInsets(
            top: 16, leading: 16, bottom: 16, trailing: 16
        )
        
        return section
    }
    
    static func createHeader(height: CGFloat = 44) -> NSCollectionLayoutBoundarySupplementaryItem {
        let headerSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0),
            heightDimension: .absolute(height)
        )
        return NSCollectionLayoutBoundarySupplementaryItem(
            layoutSize: headerSize,
            elementKind: UICollectionView.elementKindSectionHeader,
            alignment: .top
        )
    }
    
    static func createFooter(height: CGFloat = 44) -> NSCollectionLayoutBoundarySupplementaryItem {
        let footerSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0),
            heightDimension: .absolute(height)
        )
        return NSCollectionLayoutBoundarySupplementaryItem(
            layoutSize: footerSize,
            elementKind: UICollectionView.elementKindSectionFooter,
            alignment: .bottom
        )
    }
}