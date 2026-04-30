import Foundation
import CoreGraphics

public typealias WaterfallLayout = CachedLayout<WaterfallLayoutStrategy>

public struct WaterfallLayoutStrategy: LayoutStrategy {
    var numberOfColumns: Int
    var itemSpacing: CGFloat
    var lineSpacing: CGFloat
    var itemHeightProvider: (@Sendable (CGFloat, Int) -> CGFloat)?
    
    init(
        columns: Int = 2,
        itemSpacing: CGFloat = 8,
        lineSpacing: CGFloat = 8,
        itemHeightProvider: (@Sendable (CGFloat, Int) -> CGFloat)? = nil
    ) {
        self.numberOfColumns = columns
        self.itemSpacing = itemSpacing
        self.lineSpacing = lineSpacing
        self.itemHeightProvider = itemHeightProvider
    }
    
    public func computeAttributes(
        for index: Int,
        in context: LayoutContext,
        itemCount: Int
    ) -> LayoutAttributes? {
        // Waterfall is interdependent - must compute all
        computeAllAttributes(in: context, itemCount: itemCount).first { $0.index == index }
    }
    
    public func computeAllAttributes(
        in context: LayoutContext,
        itemCount: Int
    ) -> [LayoutAttributes] {
        guard itemCount > 0 else { return [] }
        
        let contentRect = context.contentRect
        let totalSpacing = itemSpacing * CGFloat(numberOfColumns - 1)
        let itemWidth = (contentRect.width - totalSpacing) / CGFloat(numberOfColumns)
        
        var attributes: [LayoutAttributes] = []
        var columnHeights = Array(repeating: contentRect.minY, count: numberOfColumns)
        
        for index in 0..<itemCount {
            let shortestColumn = columnHeights.enumerated().min(by: { $0.element < $1.element })!.offset
            let itemHeight = itemHeightProvider?(itemWidth, index) ?? itemWidth
            
            let x = contentRect.minX + CGFloat(shortestColumn) * (itemWidth + itemSpacing)
            let y = columnHeights[shortestColumn]
            
            attributes.append(LayoutAttributes(
                index: index,
                frame: CGRect(x: x, y: y, width: itemWidth, height: itemHeight)
            ))
            
            columnHeights[shortestColumn] += itemHeight + lineSpacing
        }
        
        return attributes
    }
}

extension CachedLayout where Strategy == WaterfallLayoutStrategy {
    public convenience init(
        columns: Int = 2,
        itemSpacing: CGFloat = 8,
        lineSpacing: CGFloat = 8,
        itemHeightProvider: (@Sendable (CGFloat, Int) -> CGFloat)? = nil,
        dataSource: CollectionLayoutDataSource
    ) {
        let strategy = WaterfallLayoutStrategy(
            columns: columns,
            itemSpacing: itemSpacing,
            lineSpacing: lineSpacing,
            itemHeightProvider: itemHeightProvider
        )
        self.init(strategy: strategy, dataSource: dataSource)
    }
}
