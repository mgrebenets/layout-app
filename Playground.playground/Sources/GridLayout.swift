import Foundation
import CoreGraphics

typealias GridLayout = CachedLayout<GridLayoutStrategy>

struct GridLayoutStrategy: LayoutStrategy {
    var numberOfColumns: Int
    var itemSpacing: CGFloat
    var lineSpacing: CGFloat
    var itemAspectRatio: CGFloat
    
    init(
        columns: Int = 3,
        itemSpacing: CGFloat = 8,
        lineSpacing: CGFloat = 8,
        aspectRatio: CGFloat = 1.0
    ) {
        self.numberOfColumns = columns
        self.itemSpacing = itemSpacing
        self.lineSpacing = lineSpacing
        self.itemAspectRatio = aspectRatio
    }
    
    func computeAttributes(
        for index: Int,
        in context: LayoutContext,
        itemCount: Int
    ) -> LayoutAttributes? {
        guard index >= 0 && index < itemCount else { return nil }
        
        let contentRect = context.contentRect
        let totalSpacing = itemSpacing * CGFloat(numberOfColumns - 1)
        let itemWidth = (contentRect.width - totalSpacing) / CGFloat(numberOfColumns)
        let itemHeight = itemWidth / itemAspectRatio
        
        let row = index / numberOfColumns
        let column = index % numberOfColumns
        
        let x = contentRect.minX + CGFloat(column) * (itemWidth + itemSpacing)
        let y = contentRect.minY + CGFloat(row) * (itemHeight + lineSpacing)
        
        return LayoutAttributes(
            index: index,
            frame: CGRect(x: x, y: y, width: itemWidth, height: itemHeight)
        )
    }
    
    func computeContentSize(in context: LayoutContext, itemCount: Int) -> CGSize {
        guard itemCount > 0 else { return .zero }
        
        let contentRect = context.contentRect
        let totalSpacing = itemSpacing * CGFloat(numberOfColumns - 1)
        let itemWidth = (contentRect.width - totalSpacing) / CGFloat(numberOfColumns)
        let itemHeight = itemWidth / itemAspectRatio
        
        let numberOfRows = (itemCount + numberOfColumns - 1) / numberOfColumns
        let totalHeight = CGFloat(numberOfRows) * itemHeight +
                         CGFloat(max(0, numberOfRows - 1)) * lineSpacing
        
        return CGSize(
            width: context.bounds.width,
            height: totalHeight + context.contentInsets.vertical
        )
    }
}

extension CachedLayout where Strategy == GridLayoutStrategy {
    convenience init(
        columns: Int = 3,
        itemSpacing: CGFloat = 8,
        lineSpacing: CGFloat = 8,
        aspectRatio: CGFloat = 1.0,
        dataSource: CollectionLayoutDataSource
    ) {
        let strategy = GridLayoutStrategy(
            columns: columns,
            itemSpacing: itemSpacing,
            lineSpacing: lineSpacing,
            aspectRatio: aspectRatio
        )
        self.init(strategy: strategy, dataSource: dataSource)
    }
}
