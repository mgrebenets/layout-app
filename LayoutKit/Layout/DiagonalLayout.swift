import Foundation
import CoreGraphics

public typealias DiagonalLayout = CachedLayout<DiagonalLayoutStrategy>


public struct DiagonalLayoutStrategy: LayoutStrategy {
    var itemSizing: RelativeSizing?
    var horizontalGapPercentage: CGFloat
    var verticalGapPercentage: CGFloat
    var horizontalAlignment: Alignment
    var verticalAlignment: Alignment
    var zOrder: ZOrder

    public init(
        itemSizing: RelativeSizing? = nil,
        horizontalGapPercentage: CGFloat = 0.0,
        verticalGapPercentage: CGFloat = 0.0,
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

        // Calculate item size
        let itemSize: CGSize
        if let sizing = itemSizing {
            itemSize = sizing.size(for: contentRect.size)
        } else {
            // Default sizing - square based on smaller dimension
            let minDimension = min(contentRect.width, contentRect.height)
            let defaultSize = minDimension / CGFloat(max(3, itemCount))
            itemSize = CGSize(width: defaultSize, height: defaultSize)
        }

        // Gap semantics:
        // gap = 0: complete overlap (spacing = 0)
        // gap = 1: touching (spacing = itemSize)
        // gap = 2: one item width apart (spacing = 2 * itemSize)
        // gap = -1: touching but reversed (spacing = -itemSize)

        let hSpacing = itemSize.width * horizontalGapPercentage
        let vSpacing = itemSize.height * verticalGapPercentage

        // Calculate where items would naturally be positioned
        // Item N is at position: N * spacing
        // (This works for both positive and negative spacing)
        guard itemCount > 0 else { return nil }

        let firstItemPosition = CGPoint.zero
        let lastItemPosition = CGPoint(
            x: CGFloat(itemCount - 1) * hSpacing,
            y: CGFloat(itemCount - 1) * vSpacing
        )

        // Calculate the bounding box of all items
        let minX = min(firstItemPosition.x, lastItemPosition.x)
        let maxX = max(firstItemPosition.x, lastItemPosition.x) + itemSize.width
        let minY = min(firstItemPosition.y, lastItemPosition.y)
        let maxY = max(firstItemPosition.y, lastItemPosition.y) + itemSize.height

        let naturalWidth = maxX - minX
        let naturalHeight = maxY - minY

        // Calculate effective spacing and offset
        let effectiveHSpacing: CGFloat
        let effectiveVSpacing: CGFloat
        let hBaseOffset: CGFloat  // Offset to shift from natural positioning
        let vBaseOffset: CGFloat

        // Horizontal
        if naturalWidth <= contentRect.width {
            // Items fit - use preferred spacing
            effectiveHSpacing = hSpacing

            // Calculate alignment offset
            // First, shift by -minX to bring leftmost item to 0
            // Then apply alignment
            let contentWidth = naturalWidth
            let alignmentShift: CGFloat
            switch horizontalAlignment {
            case .leading:
                alignmentShift = 0
            case .center:
                alignmentShift = (contentRect.width - contentWidth) / 2
            case .trailing:
                alignmentShift = contentRect.width - contentWidth
            }
            hBaseOffset = -minX + alignmentShift
        } else {
            // Items don't fit - compress while preserving direction
            if itemCount > 1 {
                // Determine direction from original spacing
                if hSpacing >= 0 {
                    // Positive: compress by reducing spacing
                    let availableSpace = contentRect.width - itemSize.width
                    effectiveHSpacing = availableSpace / CGFloat(itemCount - 1)
                } else {
                    // Negative: compress by reducing magnitude of negative spacing
                    // Maximum negative spacing that fits: last item at -(width - itemSize)
                    let availableSpace = contentRect.width - itemSize.width
                    effectiveHSpacing = -availableSpace / CGFloat(itemCount - 1)
                }
            } else {
                effectiveHSpacing = 0
            }

            // Calculate the compressed bounding box
            let compressedLastPos = CGFloat(itemCount - 1) * effectiveHSpacing
            let compressedMinX = min(0, compressedLastPos)
            hBaseOffset = -compressedMinX  // Shift to bring leftmost to 0
        }

        // Vertical (same logic)
        if naturalHeight <= contentRect.height {
            effectiveVSpacing = vSpacing

            let contentHeight = naturalHeight
            let alignmentShift: CGFloat
            switch verticalAlignment {
            case .leading:
                alignmentShift = 0
            case .center:
                alignmentShift = (contentRect.height - contentHeight) / 2
            case .trailing:
                alignmentShift = contentRect.height - contentHeight
            }
            vBaseOffset = -minY + alignmentShift
        } else {
            // Items don't fit - compress while preserving direction
            if itemCount > 1 {
                if vSpacing >= 0 {
                    // Positive: compress by reducing spacing
                    let availableSpace = contentRect.height - itemSize.height
                    effectiveVSpacing = availableSpace / CGFloat(itemCount - 1)
                } else {
                    // Negative: compress by reducing magnitude of negative spacing
                    let availableSpace = contentRect.height - itemSize.height
                    effectiveVSpacing = -availableSpace / CGFloat(itemCount - 1)
                }
            } else {
                effectiveVSpacing = 0
            }

            // Calculate the compressed bounding box
            let compressedLastPos = CGFloat(itemCount - 1) * effectiveVSpacing
            let compressedMinY = min(0, compressedLastPos)
            vBaseOffset = -compressedMinY  // Shift to bring topmost to 0
        }

        // Calculate final position
        let x = contentRect.minX + hBaseOffset + CGFloat(index) * effectiveHSpacing
        let y = contentRect.minY + vBaseOffset + CGFloat(index) * effectiveVSpacing

        // Calculate zIndex
        let zIndex: Int
        switch zOrder {
        case .ascending:
            zIndex = index
        case .descending:
            zIndex = itemCount - 1 - index
        }

        let frame = CGRect(
            x: x,
            y: y,
            width: itemSize.width,
            height: itemSize.height
        )

        return LayoutAttributes(index: index, frame: frame, zIndex: zIndex)
    }

    public func computeContentSize(in context: LayoutContext, itemCount: Int) -> CGSize {
        // Content size is always the container size (items compress to fit)
        return context.bounds.size
    }
}

extension CachedLayout where Strategy == DiagonalLayoutStrategy {
    public convenience init(
        itemSizing: RelativeSizing? = nil,
        horizontalGapPercentage: CGFloat = 0.0,
        verticalGapPercentage: CGFloat = 0.0,
        horizontalAlignment: Alignment = .leading,
        verticalAlignment: Alignment = .leading,
        zOrder: ZOrder = .ascending,
        dataSource: CollectionLayoutDataSource
    ) {
        let strategy = DiagonalLayoutStrategy(
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
