import Foundation
import Testing
import SnapshotTesting
@testable import LayoutKit

@MainActor
@Suite("DiagonalLayout Snapshot Tests", .snapshots(diffTool: "bcomp"))
struct DiagonalLayoutSnapshotTests {

    // MARK: - Basic Diagonal Tests

    @Test("Diagonal layout - default (top-left to bottom-right)")
    func diagonalDefault() {
        let collection = SnapshotTestHelpers.createTestCollection(
            layout: LayoutTestFactory.diagonalLayout(
                horizontalAlignment: .leading,
                verticalAlignment: .leading,
                horizontalGapPercentage: 0.5,
                verticalGapPercentage: 0.5,
                itemSizing: LayoutTestFactory.relativeSizeSquare(percentage: 0.15),
                dataSource: MockDataSource(itemCount: 5)
            ),
            nodeCount: 5
        )

        let image = SnapshotTestHelpers.render(collectionNode: collection, testSize: .medium)
        assertSnapshot(of: image, as: .image, named: "diagonal-default")
    }

    @Test("Diagonal layout - bottom-left to top-right")
    func diagonalBottomLeftToTopRight() {
        let collection = SnapshotTestHelpers.createTestCollection(
            layout: LayoutTestFactory.diagonalLayout(
                horizontalAlignment: .leading,
                verticalAlignment: .trailing,
                horizontalGapPercentage: 0.5,
                verticalGapPercentage: -0.5,
                itemSizing: LayoutTestFactory.relativeSizeSquare(percentage: 0.15),
                dataSource: MockDataSource(itemCount: 5)
            ),
            nodeCount: 5
        )

        let image = SnapshotTestHelpers.render(collectionNode: collection, testSize: .medium)
        assertSnapshot(of: image, as: .image, named: "diagonal-bottom-left-to-top-right")
    }

    // MARK: - Alignment Tests

    @Test("Diagonal layout - center alignment")
    func diagonalCenterAlignment() {
        let collection = SnapshotTestHelpers.createTestCollection(
            layout: LayoutTestFactory.diagonalLayout(
                horizontalAlignment: .center,
                verticalAlignment: .center,
                horizontalGapPercentage: 0.5,
                verticalGapPercentage: 0.5,
                itemSizing: LayoutTestFactory.relativeSizeSquare(percentage: 0.15),
                dataSource: MockDataSource(itemCount: 5)
            ),
            nodeCount: 5
        )

        let image = SnapshotTestHelpers.render(collectionNode: collection, testSize: .medium)
        assertSnapshot(of: image, as: .image, named: "diagonal-center-alignment")
    }

    @Test("Diagonal layout - trailing alignment")
    func diagonalTrailingAlignment() {
        let collection = SnapshotTestHelpers.createTestCollection(
            layout: LayoutTestFactory.diagonalLayout(
                horizontalAlignment: .trailing,
                verticalAlignment: .trailing,
                horizontalGapPercentage: 0.5,
                verticalGapPercentage: 0.5,
                itemSizing: LayoutTestFactory.relativeSizeSquare(percentage: 0.15),
                dataSource: MockDataSource(itemCount: 5)
            ),
            nodeCount: 5
        )

        let image = SnapshotTestHelpers.render(collectionNode: collection, testSize: .medium)
        assertSnapshot(of: image, as: .image, named: "diagonal-trailing-alignment")
    }

    @Test("Diagonal layout - mixed alignment (horizontal center, vertical leading)")
    func diagonalMixedAlignment() {
        let collection = SnapshotTestHelpers.createTestCollection(
            layout: LayoutTestFactory.diagonalLayout(
                horizontalAlignment: .center,
                verticalAlignment: .leading,
                horizontalGapPercentage: 0.5,
                verticalGapPercentage: 0.5,
                itemSizing: LayoutTestFactory.relativeSizeSquare(percentage: 0.15),
                dataSource: MockDataSource(itemCount: 5)
            ),
            nodeCount: 5
        )

        let image = SnapshotTestHelpers.render(collectionNode: collection, testSize: .medium)
        assertSnapshot(of: image, as: .image, named: "diagonal-mixed-alignment")
    }

    // MARK: - Gap Percentage Tests

    @Test("Diagonal layout - zero gap (complete overlap)")
    func diagonalZeroGap() {
        let collection = SnapshotTestHelpers.createTestCollection(
            layout: LayoutTestFactory.diagonalLayout(
                horizontalAlignment: .center,
                verticalAlignment: .center,
                horizontalGapPercentage: 0.0,
                verticalGapPercentage: 0.0,
                itemSizing: LayoutTestFactory.relativeSizeSquare(percentage: 0.15),
                dataSource: MockDataSource(itemCount: 5)
            ),
            nodeCount: 5
        )

        let image = SnapshotTestHelpers.render(collectionNode: collection, testSize: .medium)
        assertSnapshot(of: image, as: .image, named: "diagonal-zero-gap")
    }

    @Test("Diagonal layout - full gap (touching)")
    func diagonalFullGap() {
        let collection = SnapshotTestHelpers.createTestCollection(
            layout: LayoutTestFactory.diagonalLayout(
                horizontalAlignment: .center,
                verticalAlignment: .center,
                horizontalGapPercentage: 1.0,
                verticalGapPercentage: 1.0,
                itemSizing: LayoutTestFactory.relativeSizeSquare(percentage: 0.15),
                dataSource: MockDataSource(itemCount: 5)
            ),
            nodeCount: 5
        )

        let image = SnapshotTestHelpers.render(collectionNode: collection, testSize: .medium)
        assertSnapshot(of: image, as: .image, named: "diagonal-full-gap")
    }

    @Test("Diagonal layout - large gap")
    func diagonalLargeGap() {
        let collection = SnapshotTestHelpers.createTestCollection(
            layout: LayoutTestFactory.diagonalLayout(
                horizontalAlignment: .center,
                verticalAlignment: .center,
                horizontalGapPercentage: 1.5,
                verticalGapPercentage: 1.5,
                itemSizing: LayoutTestFactory.relativeSizeSquare(percentage: 0.1),
                dataSource: MockDataSource(itemCount: 4)
            ),
            nodeCount: 4
        )

        let image = SnapshotTestHelpers.render(collectionNode: collection, testSize: .medium)
        assertSnapshot(of: image, as: .image, named: "diagonal-large-gap")
    }

    @Test("Diagonal layout - asymmetric gaps")
    func diagonalAsymmetricGaps() {
        let collection = SnapshotTestHelpers.createTestCollection(
            layout: LayoutTestFactory.diagonalLayout(
                horizontalAlignment: .center,
                verticalAlignment: .center,
                horizontalGapPercentage: 1.0,
                verticalGapPercentage: 0.3,
                itemSizing: LayoutTestFactory.relativeSizeSquare(percentage: 0.12),
                dataSource: MockDataSource(itemCount: 6)
            ),
            nodeCount: 6
        )

        let image = SnapshotTestHelpers.render(collectionNode: collection, testSize: .medium)
        assertSnapshot(of: image, as: .image, named: "diagonal-asymmetric-gaps")
    }

    // MARK: - Edge Cases

    @Test("Diagonal layout - single item")
    func diagonalSingleItem() {
        let collection = SnapshotTestHelpers.createTestCollection(
            layout: LayoutTestFactory.diagonalLayout(
                horizontalAlignment: .center,
                verticalAlignment: .center,
                horizontalGapPercentage: 0.5,
                verticalGapPercentage: 0.5,
                itemSizing: LayoutTestFactory.relativeSizeSquare(percentage: 0.2),
                dataSource: MockDataSource(itemCount: 1)
            ),
            nodeCount: 1
        )

        let image = SnapshotTestHelpers.render(collectionNode: collection, testSize: .medium)
        assertSnapshot(of: image, as: .image, named: "diagonal-single-item")
    }

    @Test("Diagonal layout - many items")
    func diagonalManyItems() {
        let collection = SnapshotTestHelpers.createTestCollection(
            layout: LayoutTestFactory.diagonalLayout(
                horizontalAlignment: .center,
                verticalAlignment: .center,
                horizontalGapPercentage: 0.4,
                verticalGapPercentage: 0.4,
                itemSizing: LayoutTestFactory.relativeSizeSquare(percentage: 0.08),
                dataSource: MockDataSource(itemCount: 8)
            ),
            nodeCount: 8
        )

        let image = SnapshotTestHelpers.render(collectionNode: collection, testSize: .medium)
        assertSnapshot(of: image, as: .image, named: "diagonal-many-items")
    }
}

// MARK: - Mock Data Source

private class MockDataSource: CollectionLayoutDataSource {
    let itemCount: Int

    init(itemCount: Int) {
        self.itemCount = itemCount
    }

    var numberOfItems: Int {
        return itemCount
    }
}
