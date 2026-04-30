import Foundation
import CoreGraphics

public typealias DynamicGridLayout = CachedLayout<DynamicGridLayoutStrategy>

public struct DynamicGridLayoutStrategy: LayoutStrategy {
    var itemSizing: RelativeSizing
    var horizontalGapPercentage: CGFloat
    var verticalGapPercentage: CGFloat
    var horizontalAlignment: Alignment
    var verticalAlignment: Alignment
    var zOrder: ZOrder

    public init(
        itemSizing: RelativeSizing,
        horizontalGapPercentage: CGFloat = 1.0,
        verticalGapPercentage: CGFloat = 1.0,
        horizontalAlignment: Alignment = .leading,
        verticalAlignment: Alignment = .leading,
        zOrder: ZOrder = .ascending
    ) {
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

        let contentRect = context.contentRect

        // Calculate base item size from configuration
        let baseItemSize = itemSizing.size(for: contentRect.size)

        // Calculate horizontal spacing based on gap percentage
        let baseHorizontalSpacing = baseItemSize.width * horizontalGapPercentage
        let baseVerticalSpacing = baseItemSize.height * verticalGapPercentage

        // Calculate how many columns can fit with base spacing
        let availableWidth = contentRect.width
        var columns = 1
        var requiredWidth = baseItemSize.width

        // Guard against infinite loop when spacing is zero
        if baseHorizontalSpacing > 0 {
            while requiredWidth + baseHorizontalSpacing + baseItemSize.width <= availableWidth {
                columns += 1
                requiredWidth += baseItemSize.width + baseHorizontalSpacing
            }
        } else {
            // When spacing is 0, calculate max columns that fit
            columns = max(1, Int(availableWidth / baseItemSize.width))
        }

        // Calculate how many rows we need
        let rows = (itemCount + columns - 1) / columns

        // Calculate total height needed with base spacing
        let totalBaseHeight = CGFloat(rows - 1) * baseVerticalSpacing + baseItemSize.height

        // Apply compression to keep items within bounds
        // Compress horizontally if needed
        let horizontalCompressionRatio: CGFloat
        if requiredWidth > availableWidth && columns > 1 {
            // Calculate how much space we actually have for spacing
            let availableSpacingWidth = availableWidth - baseItemSize.width
            let neededSpacingWidth = CGFloat(columns - 1) * baseHorizontalSpacing
            horizontalCompressionRatio = min(1.0, availableSpacingWidth / neededSpacingWidth)
        } else {
            horizontalCompressionRatio = 1.0
        }

        // Compress vertically if needed
        let verticalCompressionRatio: CGFloat
        if totalBaseHeight > contentRect.height && rows > 1 {
            // Calculate how much space we actually have for spacing
            let availableSpacingHeight = contentRect.height - baseItemSize.height
            let neededSpacingHeight = CGFloat(rows - 1) * baseVerticalSpacing
            verticalCompressionRatio = min(1.0, availableSpacingHeight / neededSpacingHeight)
        } else {
            verticalCompressionRatio = 1.0
        }

        // Apply compression to spacing
        let horizontalSpacing = baseHorizontalSpacing * horizontalCompressionRatio
        let verticalSpacing = baseVerticalSpacing * verticalCompressionRatio

        // Calculate actual total height after compression
        let totalHeight = CGFloat(rows - 1) * verticalSpacing + baseItemSize.height

        // Calculate row and column for this item
        let row = index / columns
        let column = index % columns

        // Calculate how many items are in this row (last row might be partial)
        let itemsInRow = (row == rows - 1) ? itemCount - row * columns : columns

        // Calculate base position for this column
        let baseX = CGFloat(column) * horizontalSpacing

        // Apply horizontal alignment
        let alignedX: CGFloat
        switch horizontalAlignment {
        case .leading:
            alignedX = contentRect.minX + baseX
        case .center:
            // Center the row within available width
            let rowWidth = CGFloat(itemsInRow - 1) * horizontalSpacing + baseItemSize.width
            let offset = (contentRect.width - rowWidth) / 2
            alignedX = contentRect.minX + offset + baseX
        case .trailing:
            // Align row to trailing edge
            let rowWidth = CGFloat(itemsInRow - 1) * horizontalSpacing + baseItemSize.width
            let offset = contentRect.width - rowWidth
            alignedX = contentRect.minX + offset + baseX
        }

        // Calculate base position for this row
        let baseY = CGFloat(row) * verticalSpacing

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
        guard itemCount > 0 else { return .zero }

        let contentRect = context.contentRect
        let itemSize = itemSizing.size(for: contentRect.size)

        let horizontalSpacing = itemSize.width * horizontalGapPercentage
        let verticalSpacing = itemSize.height * verticalGapPercentage

        // Calculate columns
        let availableWidth = contentRect.width
        var columns = 1
        var requiredWidth = itemSize.width

        // Guard against infinite loop when spacing is zero
        if horizontalSpacing > 0 {
            while requiredWidth + horizontalSpacing + itemSize.width <= availableWidth {
                columns += 1
                requiredWidth += itemSize.width + horizontalSpacing
            }
        } else {
            // When spacing is 0, calculate max columns that fit
            columns = max(1, Int(availableWidth / itemSize.width))
        }

        // Calculate rows
        let rows = (itemCount + columns - 1) / columns

        // Total height needed
        let totalHeight = CGFloat(rows - 1) * verticalSpacing + itemSize.height

        return CGSize(
            width: context.bounds.width,
            height: totalHeight + context.contentInsets.vertical
        )
    }
}

extension CachedLayout where Strategy == DynamicGridLayoutStrategy {
    public convenience init(
        itemSizing: RelativeSizing,
        horizontalGapPercentage: CGFloat = 1.0,
        verticalGapPercentage: CGFloat = 1.0,
        horizontalAlignment: Alignment = .leading,
        verticalAlignment: Alignment = .leading,
        zOrder: ZOrder = .ascending,
        dataSource: CollectionLayoutDataSource
    ) {
        let strategy = DynamicGridLayoutStrategy(
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

