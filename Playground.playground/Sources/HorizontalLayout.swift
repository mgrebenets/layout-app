import Foundation
import CoreGraphics

public typealias HorizontalListLayout = CachedLayout<HorizontalListLayoutStrategy>

public struct HorizontalListLayoutStrategy: LayoutStrategy {
    var itemWidth: CGFloat
    var itemSpacing: CGFloat
    
    init(itemWidth: CGFloat = 100, itemSpacing: CGFloat = 8) {
        self.itemWidth = itemWidth
        self.itemSpacing = itemSpacing
    }
    
    public func computeAttributes(
        for index: Int,
        in context: LayoutContext,
        itemCount: Int
    ) -> LayoutAttributes? {
        guard index >= 0 && index < itemCount else { return nil }
        
        let contentRect = context.contentRect
        let x = contentRect.minX + CGFloat(index) * (itemWidth + itemSpacing)
        
        return LayoutAttributes(
            index: index,
            frame: CGRect(x: x, y: contentRect.minY, width: itemWidth, height: contentRect.height)
        )
    }
    
    public func computeContentSize(in context: LayoutContext, itemCount: Int) -> CGSize {
        guard itemCount > 0 else { return .zero }
        
        let totalWidth = CGFloat(itemCount) * itemWidth +
                        CGFloat(max(0, itemCount - 1)) * itemSpacing
        
        return CGSize(
            width: totalWidth + context.contentInsets.horizontal,
            height: context.bounds.height
        )
    }
}

extension CachedLayout where Strategy == HorizontalListLayoutStrategy {
    convenience init(
        itemWidth: CGFloat = 100,
        itemSpacing: CGFloat = 8,
        dataSource: CollectionLayoutDataSource
    ) {
        let strategy = HorizontalListLayoutStrategy(
            itemWidth: itemWidth,
            itemSpacing: itemSpacing
        )
        self.init(strategy: strategy, dataSource: dataSource)
    }
}
