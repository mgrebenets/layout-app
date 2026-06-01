import Foundation
import SpriteKit
@testable import LayoutKit


/// Factory for creating pre-configured layouts for testing
struct LayoutTestFactory {

    // MARK: - Stack Layouts

    static func horizontalStack(
        alignment: Alignment = .leading,
        gapPercentage: CGFloat = 0.0,
        itemSizing: RelativeSizing? = nil,
        dataSource: CollectionLayoutDataSource
    ) -> StackLayout {
        return StackLayout(
            axis: .horizontal,
            itemSizing: itemSizing,
            itemSpacing: 8,
            gapPercentage: gapPercentage,
            alignment: alignment,
            zOrder: .ascending,
            dataSource: dataSource
        )
    }

    static func verticalStack(
        alignment: Alignment = .leading,
        gapPercentage: CGFloat = 0.0,
        itemSizing: RelativeSizing? = nil,
        dataSource: CollectionLayoutDataSource
    ) -> StackLayout {
        return StackLayout(
            axis: .vertical,
            itemSizing: itemSizing,
            itemSpacing: 8,
            gapPercentage: gapPercentage,
            alignment: alignment,
            zOrder: .ascending,
            dataSource: dataSource
        )
    }

    // MARK: - Diagonal Layouts

    static func diagonalLayout(
        horizontalAlignment: Alignment = .leading,
        verticalAlignment: Alignment = .leading,
        horizontalGapPercentage: CGFloat = 0.5,
        verticalGapPercentage: CGFloat = 0.5,
        itemSizing: RelativeSizing? = nil,
        dataSource: CollectionLayoutDataSource
    ) -> DiagonalLayout {
        return DiagonalLayout(
            itemSizing: itemSizing,
            horizontalGapPercentage: horizontalGapPercentage,
            verticalGapPercentage: verticalGapPercentage,
            horizontalAlignment: horizontalAlignment,
            verticalAlignment: verticalAlignment,
            zOrder: .ascending,
            dataSource: dataSource
        )
    }

    // MARK: - Circular Layouts

    static func circularLayout(
        startAngle: CGFloat = 0,
        angleSpan: CGFloat = 360,
        radiusPercentage: CGFloat = 0.35,
        itemSizing: RelativeSizing? = nil,
        dataSource: CollectionLayoutDataSource
    ) -> CircularLayout {
        // Note: CircularLayout uses startAnglePercentage (0-1) and radiusGapPercentage
        // We'll approximate the desired behavior
        return CircularLayout(
            itemSizing: itemSizing,
            startAnglePercentage: startAngle / 360.0,
            radiusGapPercentage: radiusPercentage * 3.0, // Approximate scaling
            zOrder: .ascending,
            dataSource: dataSource
        )
    }

    // MARK: - Grid Layouts

    static func gridLayout(
        rows: Int,
        columns: Int,
        horizontalAlignment: Alignment = .leading,
        verticalAlignment: Alignment = .leading,
        itemSizing: RelativeSizing? = nil,
        dataSource: CollectionLayoutDataSource
    ) -> GridLayout {
        return GridLayout(
            rows: rows,
            columns: columns,
            itemSizing: itemSizing,
            horizontalGapPercentage: 1.0,
            verticalGapPercentage: 1.0,
            horizontalAlignment: horizontalAlignment,
            verticalAlignment: verticalAlignment,
            zOrder: .ascending,
            dataSource: dataSource
        )
    }

    // MARK: - Dynamic Grid Layouts

    static func dynamicGridLayout(
        horizontalAlignment: Alignment = .leading,
        verticalAlignment: Alignment = .leading,
        itemSizing: RelativeSizing,
        dataSource: CollectionLayoutDataSource
    ) -> DynamicGridLayout {
        return DynamicGridLayout(
            itemSizing: itemSizing,
            horizontalGapPercentage: 1.0,
            verticalGapPercentage: 1.0,
            horizontalAlignment: horizontalAlignment,
            verticalAlignment: verticalAlignment,
            zOrder: .ascending,
            dataSource: dataSource
        )
    }

    // MARK: - Waterfall Layouts

    static func waterfallLayout(
        columns: Int = 2,
        columnSpacing: CGFloat = 8,
        itemSpacing: CGFloat = 8,
        itemSizing: RelativeSizing? = nil,
        dataSource: CollectionLayoutDataSource
    ) -> WaterfallLayout {
        return WaterfallLayout(
            columns: columns,
            itemSpacing: columnSpacing,
            lineSpacing: itemSpacing,
            itemSizing: itemSizing,
            dataSource: dataSource
        )
    }

    // MARK: - Standard Sizing Configurations

    static func fixedSizeSquare(dimension: CGFloat = 80) -> RelativeSizing {
        return RelativeSizing(
            widthSpec: .containerWidth(percentage: 0),
            heightSpec: .containerHeight(percentage: 0)
        )
    }

    static func relativeSizeSquare(percentage: CGFloat = 0.15) -> RelativeSizing {
        return RelativeSizing(
            baseDimension: .smallest,
            containerPercentage: percentage,
            aspectRatio: 1.0
        )
    }

    static func relativeSizeWide(widthPercentage: CGFloat = 0.2, aspectRatio: CGFloat = 2.0) -> RelativeSizing {
        return RelativeSizing(
            widthSpec: .containerWidth(percentage: widthPercentage),
            heightSpec: .itemWidth(percentage: 1.0 / aspectRatio)
        )
    }

    static func relativeSizeTall(heightPercentage: CGFloat = 0.2, aspectRatio: CGFloat = 0.5) -> RelativeSizing {
        return RelativeSizing(
            widthSpec: .itemHeight(percentage: aspectRatio),
            heightSpec: .containerHeight(percentage: heightPercentage)
        )
    }

    // MARK: - Standard Test Configurations

    struct TestConfig {
        let name: String
        let layout: CollectionLayout
        let nodeCount: Int
        let contentInsets: Insets
        let testSize: TestSize

        init(
            name: String,
            layout: CollectionLayout,
            nodeCount: Int = 5,
            contentInsets: Insets = Insets(uniform: 20),
            testSize: TestSize = .medium
        ) {
            self.name = name
            self.layout = layout
            self.nodeCount = nodeCount
            self.contentInsets = contentInsets
            self.testSize = testSize
        }
    }

    /// Create a test collection from a configuration
    @MainActor static func createCollection(from config: TestConfig) -> SKCollectionNode {
        return SnapshotTestHelpers.createTestCollection(
            layout: config.layout,
            nodeCount: config.nodeCount,
            showIndex: true,
            contentInsets: config.contentInsets
        )
    }
}
