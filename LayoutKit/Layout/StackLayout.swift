import Foundation
import CoreGraphics

public typealias StackLayout = CachedLayout<StackLayoutStrategy>

public enum LayoutAxis: Sendable, Hashable {
    case horizontal
    case vertical
}


public struct StackLayoutStrategy: LayoutStrategy {
    var axis: LayoutAxis
    var itemSizing: RelativeSizing?
    var itemSpacing: CGFloat
    var gapPercentage: CGFloat
    var alignment: Alignment
    var zOrder: ZOrder

    public init(
        axis: LayoutAxis,
        itemSizing: RelativeSizing? = nil,
        itemSpacing: CGFloat = 8,
        gapPercentage: CGFloat = 0.0,
        alignment: Alignment = .leading,
        zOrder: ZOrder = .ascending
    ) {
        self.axis = axis
        self.itemSizing = itemSizing
        self.itemSpacing = itemSpacing
        self.gapPercentage = gapPercentage
        self.alignment = alignment
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
            // Default sizing based on axis
            switch axis {
            case .horizontal:
                itemSize = CGSize(width: 100, height: contentRect.height)
            case .vertical:
                itemSize = CGSize(width: contentRect.width, height: 44)
            }
        }

        // Get item dimension and available size based on axis
        let itemDimension: CGFloat
        let availableSize: CGFloat
        switch axis {
        case .horizontal:
            itemDimension = itemSize.width
            availableSize = contentRect.width
        case .vertical:
            itemDimension = itemSize.height
            availableSize = contentRect.height
        }

        // Gap semantics (same as DiagonalLayout):
        // gap = 0: complete overlap (spacing = 0)
        // gap = 1: touching (spacing = itemDimension)
        // gap = -1: touching but reversed (spacing = -itemDimension)
        let spacing = itemDimension * gapPercentage

        guard itemCount > 0 else { return nil }

        // Calculate natural positions
        let firstItemPosition: CGFloat = 0
        let lastItemPosition = CGFloat(itemCount - 1) * spacing

        // Calculate the bounding box
        let minPos = min(firstItemPosition, lastItemPosition)
        let maxPos = max(firstItemPosition, lastItemPosition) + itemDimension
        let naturalSize = maxPos - minPos

        // Calculate effective spacing and offset
        let effectiveSpacing: CGFloat
        let baseOffset: CGFloat

        if naturalSize <= availableSize {
            // Items fit - use preferred spacing and alignment
            effectiveSpacing = spacing

            let alignmentShift: CGFloat
            switch alignment {
            case .leading:
                alignmentShift = 0
            case .center:
                alignmentShift = (availableSize - naturalSize) / 2
            case .trailing:
                alignmentShift = availableSize - naturalSize
            }
            baseOffset = -minPos + alignmentShift
        } else {
            // Items don't fit - compress while preserving direction
            if itemCount > 1 {
                if spacing >= 0 {
                    // Positive: compress by reducing spacing
                    let availableSpace = availableSize - itemDimension
                    effectiveSpacing = availableSpace / CGFloat(itemCount - 1)
                } else {
                    // Negative: compress by reducing magnitude of negative spacing
                    let availableSpace = availableSize - itemDimension
                    effectiveSpacing = -availableSpace / CGFloat(itemCount - 1)
                }
            } else {
                effectiveSpacing = 0
            }

            // Calculate compressed positions
            let compressedLastPos = CGFloat(itemCount - 1) * effectiveSpacing
            let compressedMinPos = min(0, compressedLastPos)
            baseOffset = -compressedMinPos
        }

        // Calculate final position
        let position = baseOffset + CGFloat(index) * effectiveSpacing

        // Calculate zIndex based on order
        let zIndex: Int
        switch zOrder {
        case .ascending:
            zIndex = index
        case .descending:
            zIndex = itemCount - 1 - index
        }

        // Calculate frame
        let frame: CGRect
        switch axis {
        case .horizontal:
            frame = CGRect(
                x: contentRect.minX + position,
                y: contentRect.minY,
                width: itemSize.width,
                height: itemSize.height
            )
        case .vertical:
            frame = CGRect(
                x: contentRect.minX,
                y: contentRect.minY + position,
                width: itemSize.width,
                height: itemSize.height
            )
        }

        return LayoutAttributes(index: index, frame: frame, zIndex: zIndex)
    }

    public func computeContentSize(in context: LayoutContext, itemCount: Int) -> CGSize {
        guard itemCount > 0 else { return .zero }

        // Content size is always the container size (items compress to fit)
        return context.bounds.size
    }
}

extension CachedLayout where Strategy == StackLayoutStrategy {
    public convenience init(
        axis: LayoutAxis,
        itemSizing: RelativeSizing? = nil,
        itemSpacing: CGFloat = 8,
        gapPercentage: CGFloat = 0.0,
        alignment: Alignment = .leading,
        zOrder: ZOrder = .ascending,
        dataSource: CollectionLayoutDataSource
    ) {
        let strategy = StackLayoutStrategy(
            axis: axis,
            itemSizing: itemSizing,
            itemSpacing: itemSpacing,
            gapPercentage: gapPercentage,
            alignment: alignment,
            zOrder: zOrder
        )
        self.init(strategy: strategy, dataSource: dataSource)
    }
}
