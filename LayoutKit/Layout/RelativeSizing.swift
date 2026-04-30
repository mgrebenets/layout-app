import Foundation
import CoreGraphics

public struct RelativeSizing: Sendable, Hashable {
    public enum DimensionSpec: Sendable, Hashable {
        /// Based on container's width
        case containerWidth(percentage: CGFloat)
        /// Based on container's height
        case containerHeight(percentage: CGFloat)
        /// Based on the smaller of container's width or height
        case containerSmallest(percentage: CGFloat)
        /// Based on the larger of container's width or height
        case containerLargest(percentage: CGFloat)
        /// Based on the item's own width (for height calculation)
        case itemWidth(percentage: CGFloat)
        /// Based on the item's own height (for width calculation)
        case itemHeight(percentage: CGFloat)
    }

    public var widthSpec: DimensionSpec
    public var heightSpec: DimensionSpec

    public init(widthSpec: DimensionSpec, heightSpec: DimensionSpec) {
        self.widthSpec = widthSpec
        self.heightSpec = heightSpec
    }

    /// Convenience initializer matching the old API
    public init(
        baseDimension: BaseDimension,
        containerPercentage: CGFloat = 1.0,
        aspectRatio: CGFloat
    ) {
        switch baseDimension {
        case .width:
            self.widthSpec = .containerWidth(percentage: containerPercentage)
            self.heightSpec = .itemWidth(percentage: 1.0 / aspectRatio)
        case .height:
            self.heightSpec = .containerHeight(percentage: containerPercentage)
            self.widthSpec = .itemHeight(percentage: aspectRatio)
        case .smallest:
            self.widthSpec = .containerSmallest(percentage: containerPercentage)
            self.heightSpec = .itemWidth(percentage: 1.0 / aspectRatio)
        case .largest:
            self.widthSpec = .containerLargest(percentage: containerPercentage)
            self.heightSpec = .itemWidth(percentage: 1.0 / aspectRatio)
        }
    }

    /// Compute the size based on the container size
    public func size(for containerSize: CGSize) -> CGSize {
        // Detect circular dependencies
        if isCircularDependency() {
            print("Warning: RelativeSizing has circular dependency. Width spec: \(widthSpec), Height spec: \(heightSpec). Using fallback size.")
            return CGSize(width: 100, height: 100)
        }

        // Determine which dimension to calculate first
        let widthDependsOnItemHeight = dependsOnItemHeight(widthSpec)
        let heightDependsOnItemWidth = dependsOnItemWidth(heightSpec)

        if widthDependsOnItemHeight && heightDependsOnItemWidth {
            // Circular dependency - already logged warning above
            return CGSize(width: 100, height: 100)
        }

        if widthDependsOnItemHeight {
            // Calculate height first, then width
            let height = calculateDimension(heightSpec, containerSize: containerSize, itemSize: .zero)
            let width = calculateDimension(widthSpec, containerSize: containerSize, itemSize: CGSize(width: 0, height: height))
            return CGSize(width: width, height: height)
        } else {
            // Calculate width first, then height (default case)
            let width = calculateDimension(widthSpec, containerSize: containerSize, itemSize: .zero)
            let height = calculateDimension(heightSpec, containerSize: containerSize, itemSize: CGSize(width: width, height: 0))
            return CGSize(width: width, height: height)
        }
    }

    private func isCircularDependency() -> Bool {
        let widthDependsOnItemHeight = dependsOnItemHeight(widthSpec)
        let heightDependsOnItemWidth = dependsOnItemWidth(heightSpec)
        return widthDependsOnItemHeight && heightDependsOnItemWidth
    }

    private func dependsOnItemHeight(_ spec: DimensionSpec) -> Bool {
        if case .itemHeight = spec {
            return true
        }
        return false
    }

    private func dependsOnItemWidth(_ spec: DimensionSpec) -> Bool {
        if case .itemWidth = spec {
            return true
        }
        return false
    }

    private func calculateDimension(_ spec: DimensionSpec, containerSize: CGSize, itemSize: CGSize) -> CGFloat {
        switch spec {
        case .containerWidth(let percentage):
            return containerSize.width * percentage
        case .containerHeight(let percentage):
            return containerSize.height * percentage
        case .containerSmallest(let percentage):
            return min(containerSize.width, containerSize.height) * percentage
        case .containerLargest(let percentage):
            return max(containerSize.width, containerSize.height) * percentage
        case .itemWidth(let percentage):
            return itemSize.width * percentage
        case .itemHeight(let percentage):
            return itemSize.height * percentage
        }
    }

    /// Legacy enum for backward compatibility
    public enum BaseDimension: Sendable, Hashable {
        case width
        case height
        case smallest
        case largest
    }

    // MARK: - Backward Compatibility Properties

    /// Extract container percentage from width or height spec (for backward compatibility)
    public var containerPercentage: CGFloat {
        switch widthSpec {
        case .containerWidth(let percentage),
             .containerHeight(let percentage),
             .containerSmallest(let percentage),
             .containerLargest(let percentage):
            return percentage
        case .itemWidth, .itemHeight:
            // Fallback to height spec
            switch heightSpec {
            case .containerWidth(let percentage),
                 .containerHeight(let percentage),
                 .containerSmallest(let percentage),
                 .containerLargest(let percentage):
                return percentage
            case .itemWidth, .itemHeight:
                return 1.0
            }
        }
    }

    /// Extract aspect ratio (width/height) from specs (for backward compatibility)
    public var aspectRatio: CGFloat {
        // Try to infer aspect ratio from the relationship between width and height specs
        switch (widthSpec, heightSpec) {
        case (.containerWidth(let wPct), .itemWidth(let hRatio)):
            // height = width * hRatio, so aspectRatio = width/height = 1/hRatio
            return 1.0 / hRatio
        case (.itemHeight(let wRatio), .containerHeight(let hPct)):
            // width = height * wRatio, so aspectRatio = width/height = wRatio
            return wRatio
        case (.containerSmallest(let wPct), .itemWidth(let hRatio)):
            return 1.0 / hRatio
        case (.containerLargest(let wPct), .itemWidth(let hRatio)):
            return 1.0 / hRatio
        default:
            return 1.0
        }
    }

    /// Extract base dimension (for backward compatibility)
    public var baseDimension: BaseDimension {
        switch widthSpec {
        case .containerWidth:
            return .width
        case .containerHeight:
            return .height
        case .containerSmallest:
            return .smallest
        case .containerLargest:
            return .largest
        case .itemHeight:
            // Infer from height spec
            switch heightSpec {
            case .containerHeight:
                return .height
            default:
                return .width
            }
        case .itemWidth:
            return .width
        }
    }
}
