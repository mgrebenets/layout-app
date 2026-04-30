import Foundation
import Foundation
import CoreGraphics

public typealias GridLayout = CachedLayout<GridLayoutStrategy>

public struct GridLayoutStrategy: LayoutStrategy {
    var rows: Int
    var columns: Int
    var itemSizing: RelativeSizing?
    var horizontalGapPercentage: CGFloat
    var verticalGapPercentage: CGFloat
    var horizontalAlignment: Alignment
    var verticalAlignment: Alignment
    var zOrder: ZOrder

    public init(
        rows: Int,
        columns: Int,
        itemSizing: RelativeSizing? = nil,
        horizontalGapPercentage: CGFloat = 1.0,
        verticalGapPercentage: CGFloat = 1.0,
        horizontalAlignment: Alignment = .leading,
        verticalAlignment: Alignment = .leading,
        zOrder: ZOrder = .ascending
    ) {
        self.rows = max(1, rows)
        self.columns = max(1, columns)
        self.itemSizing = itemSizing
        self.horizontalGapPercentage = horizontalGapPercentage
        self.verticalGapPercentage = verticalGapPercentage
        self.horizontalAlignment = horizontalAlignment
        self.verticalAlignment = verticalAlignment
        self.zOrder = zOrder
    }

    public func computeAttributes(
        for index: Int,
        in context: LayoutContext,
        itemCount: Int
    ) -> LayoutAttributes? {
        guard index >= 0 && index < itemCount else { return nil }
        
        // Items are placed in row-major order (left-to-right, top-to-bottom)
        let totalCells = rows * columns
        guard index < totalCells else { return nil }

        let contentRect = context.contentRect

        // Calculate item size
        let baseItemSize: CGSize
        if let sizing = itemSizing {
            baseItemSize = sizing.size(for: contentRect.size)
        } else {
            // Default sizing - divide available space by grid dimensions
            let cellWidth = contentRect.width / CGFloat(columns)
            let cellHeight = contentRect.height / CGFloat(rows)
            baseItemSize = CGSize(width: cellWidth * 0.8, height: cellHeight * 0.8)
        }

        // Calculate spacing based on gap percentages
        let baseHorizontalSpacing = baseItemSize.width * horizontalGapPercentage
        let baseVerticalSpacing = baseItemSize.height * verticalGapPercentage

        // Calculate total width and height needed with base spacing
        let totalBaseWidth = CGFloat(columns - 1) * baseHorizontalSpacing + baseItemSize.width
        let totalBaseHeight = CGFloat(rows - 1) * baseVerticalSpacing + baseItemSize.height

        // Apply compression to keep grid within bounds
        let horizontalCompressionRatio: CGFloat
        if totalBaseWidth > contentRect.width && columns > 1 {
            let availableSpacingWidth = contentRect.width - baseItemSize.width
            let neededSpacingWidth = CGFloat(columns - 1) * baseHorizontalSpacing
            horizontalCompressionRatio = min(1.0, availableSpacingWidth / neededSpacingWidth)
        } else {
            horizontalCompressionRatio = 1.0
        }

        let verticalCompressionRatio: CGFloat
        if totalBaseHeight > contentRect.height && rows > 1 {
            let availableSpacingHeight = contentRect.height - baseItemSize.height
            let neededSpacingHeight = CGFloat(rows - 1) * baseVerticalSpacing
            verticalCompressionRatio = min(1.0, availableSpacingHeight / neededSpacingHeight)
        } else {
            verticalCompressionRatio = 1.0
        }

        // Apply compression to spacing
        let horizontalSpacing = baseHorizontalSpacing * horizontalCompressionRatio
        let verticalSpacing = baseVerticalSpacing * verticalCompressionRatio

        // Calculate actual total dimensions after compression
        let totalWidth = CGFloat(columns - 1) * horizontalSpacing + baseItemSize.width
        let totalHeight = CGFloat(rows - 1) * verticalSpacing + baseItemSize.height

        // Calculate row and column for this item (row-major order)
        let row = index / columns
        let column = index % columns

        // Calculate base position
        let baseX = CGFloat(column) * horizontalSpacing
        let baseY = CGFloat(row) * verticalSpacing

        // Apply horizontal alignment
        let alignedX: CGFloat
        switch horizontalAlignment {
        case .leading:
            alignedX = contentRect.minX + baseX
        case .center:
            let offset = (contentRect.width - totalWidth) / 2
            alignedX = contentRect.minX + offset + baseX
        case .trailing:
            let offset = contentRect.width - totalWidth
            alignedX = contentRect.minX + offset + baseX
        }

        // Apply vertical alignment
        let alignedY: CGFloat
        switch verticalAlignment {
        case .leading:
            alignedY = contentRect.minY + baseY
        case .center:
            let offset = (contentRect.height - totalHeight) / 2
            alignedY = contentRect.minY + offset + baseY
        case .trailing:
            let offset = contentRect.height - totalHeight
            alignedY = contentRect.minY + offset + baseY
        }

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
            frame: CGRect(x: alignedX, y: alignedY, width: baseItemSize.width, height: baseItemSize.height),
            zIndex: zIndex
        )
    }

    public func computeContentSize(in context: LayoutContext, itemCount: Int) -> CGSize {
        guard itemCount > 0 && rows > 0 && columns > 0 else { return .zero }

        let contentRect = context.contentRect

        // Calculate item size
        let itemSize: CGSize
        if let sizing = itemSizing {
            itemSize = sizing.size(for: contentRect.size)
        } else {
            // Default sizing - divide available space by grid dimensions
            let cellWidth = contentRect.width / CGFloat(columns)
            let cellHeight = contentRect.height / CGFloat(rows)
            itemSize = CGSize(width: cellWidth * 0.8, height: cellHeight * 0.8)
        }

        // Calculate spacing
        let horizontalSpacing = itemSize.width * horizontalGapPercentage
        let verticalSpacing = itemSize.height * verticalGapPercentage

        // Total dimensions needed
        let totalWidth = CGFloat(columns - 1) * horizontalSpacing + itemSize.width
        let totalHeight = CGFloat(rows - 1) * verticalSpacing + itemSize.height

        return CGSize(
            width: max(totalWidth + context.contentInsets.horizontal, context.bounds.width),
            height: max(totalHeight + context.contentInsets.vertical, context.bounds.height)
        )
    }
}

extension CachedLayout where Strategy == GridLayoutStrategy {
    public convenience init(
        rows: Int,
        columns: Int,
        itemSizing: RelativeSizing? = nil,
        horizontalGapPercentage: CGFloat = 1.0,
        verticalGapPercentage: CGFloat = 1.0,
        horizontalAlignment: Alignment = .leading,
        verticalAlignment: Alignment = .leading,
        zOrder: ZOrder = .ascending,
        dataSource: CollectionLayoutDataSource
    ) {
        let strategy = GridLayoutStrategy(
            rows: rows,
            columns: columns,
            itemSizing: itemSizing,
            horizontalGapPercentage: horizontalGapPercentage,
            verticalGapPercentage: verticalGapPercentage,
            horizontalAlignment: horizontalAlignment,
            verticalAlignment: verticalAlignment,
            zOrder: zOrder
        )
        self.init(strategy: strategy, dataSource: dataSource)
    }
}