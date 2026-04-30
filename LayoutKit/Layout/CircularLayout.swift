import Foundation
import CoreGraphics

public typealias CircularLayout = CachedLayout<CircularLayoutStrategy>

public struct CircularLayoutStrategy: LayoutStrategy {
    var itemSizing: RelativeSizing?
    var itemSize: CGSize
    var radius: CGFloat?
    var startAnglePercentage: CGFloat  // 0.0 to 1.0, maps to 0° to 360°
    var radiusGapPercentage: CGFloat   // 0.0 = overlap, 1.0 = one item-width apart along radius
    var zOrder: ZOrder

    public init(
        itemSizing: RelativeSizing? = nil,
        itemSize: CGSize = CGSize(width: 60, height: 60),
        radius: CGFloat? = nil,
        startAnglePercentage: CGFloat = 0.0,
        radiusGapPercentage: CGFloat = 0.0,
        zOrder: ZOrder = .ascending
    ) {
        self.itemSizing = itemSizing
        self.itemSize = itemSize
        self.radius = radius
        self.startAnglePercentage = startAnglePercentage
        self.radiusGapPercentage = radiusGapPercentage
        self.zOrder = zOrder
    }

    public func computeAttributes(
        for index: Int,
        in context: LayoutContext,
        itemCount: Int
    ) -> LayoutAttributes? {
        guard index >= 0 && index < itemCount else { return nil }

        let contentRect = context.contentRect
        let center = CGPoint(x: contentRect.midX, y: contentRect.midY)

        // Calculate effective item size
        let effectiveItemSize = itemSizing?.size(for: contentRect.size) ?? itemSize

        // Calculate maximum radius that keeps items in bounds
        // Since distance is measured to item center, we need half the item dimension
        let maxItemDimension = max(effectiveItemSize.width, effectiveItemSize.height)
        let maxRadius = min(contentRect.width, contentRect.height) / 2 - maxItemDimension / 2

        // Calculate radius based on gap percentage
        // gap = 0: all items at center (radius = 0)
        // gap = 1: all items at 1 itemWidth from center
        // Distance is measured to the CENTER of each item
        let itemRadius = effectiveItemSize.width * radiusGapPercentage

        // Clamp to stay within bounds
        let effectiveRadius = min(itemRadius, maxRadius)

        // Convert start angle percentage to radians
        // 0.0 -> 0°, 1.0 -> 360°
        let startAngleRadians = startAnglePercentage * 2 * CGFloat.pi

        // Distribute items evenly around the circle
        let angleStep = 2 * CGFloat.pi / CGFloat(itemCount)
        let angle = startAngleRadians + CGFloat(index) * angleStep - CGFloat.pi / 2 // Start at top (-π/2)

        // Calculate position (radius is to item center)
        let itemCenterX = center.x + effectiveRadius * cos(angle)
        let itemCenterY = center.y + effectiveRadius * sin(angle)

        // Convert center position to top-left origin for frame
        let x = itemCenterX - effectiveItemSize.width / 2
        let y = itemCenterY - effectiveItemSize.height / 2

        // Calculate zIndex based on order
        let zIndex: Int
        switch zOrder {
        case .ascending:
            zIndex = index
        case .descending:
            zIndex = itemCount - 1 - index
        }

        return LayoutAttributes(
            index: index,
            frame: CGRect(origin: CGPoint(x: x, y: y), size: effectiveItemSize),
            zIndex: zIndex
        )
    }

    public func computeContentSize(in context: LayoutContext, itemCount: Int) -> CGSize {
        // Circular layout uses the full content rect
        return context.bounds.size
    }
}

extension CachedLayout where Strategy == CircularLayoutStrategy {
    public convenience init(
        itemSizing: RelativeSizing? = nil,
        itemSize: CGSize = CGSize(width: 60, height: 60),
        radius: CGFloat? = nil,
        startAnglePercentage: CGFloat = 0.0,
        radiusGapPercentage: CGFloat = 0.0,
        zOrder: ZOrder = .ascending,
        dataSource: CollectionLayoutDataSource
    ) {
        let strategy = CircularLayoutStrategy(
            itemSizing: itemSizing,
            itemSize: itemSize,
            radius: radius,
            startAnglePercentage: startAnglePercentage,
            radiusGapPercentage: radiusGapPercentage,
            zOrder: zOrder
        )
        self.init(strategy: strategy, dataSource: dataSource)
    }
}
