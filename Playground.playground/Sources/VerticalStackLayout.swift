import Foundation
import CoreGraphics

public typealias VerticalStackLayout = CachedLayout<VerticalStackLayoutStrategy>

public struct VerticalStackLayoutStrategy: LayoutStrategy {
    var itemHeight: CGFloat
    var itemSpacing: CGFloat
    
    init(itemHeight: CGFloat = 44, itemSpacing: CGFloat = 0) {
        self.itemHeight = itemHeight
        self.itemSpacing = itemSpacing
    }
    
    public func computeAttributes(
        for index: Int,
        in context: LayoutContext,
        itemCount: Int
    ) -> LayoutAttributes? {
        guard index >= 0 && index < itemCount else { return nil }
        
        let contentRect = context.contentRect
        let y = contentRect.minY + CGFloat(index) * (itemHeight + itemSpacing)
        
        return LayoutAttributes(
            index: index,
            frame: CGRect(x: contentRect.minX, y: y, width: contentRect.width, height: itemHeight)
        )
    }
    
    public func computeContentSize(in context: LayoutContext, itemCount: Int) -> CGSize {
        guard itemCount > 0 else { return .zero }
        
        let totalHeight = CGFloat(itemCount) * itemHeight +
                         CGFloat(max(0, itemCount - 1)) * itemSpacing
        
        return CGSize(
            width: context.bounds.width,
            height: totalHeight + context.contentInsets.vertical
        )
    }
}

extension CachedLayout where Strategy == VerticalStackLayoutStrategy {
    public convenience init(
        itemHeight: CGFloat = 44,
        itemSpacing: CGFloat = 0,
        dataSource: CollectionLayoutDataSource
    ) {
        let strategy = VerticalStackLayoutStrategy(
            itemHeight: itemHeight,
            itemSpacing: itemSpacing
        )
        self.init(strategy: strategy, dataSource: dataSource)
    }
}
