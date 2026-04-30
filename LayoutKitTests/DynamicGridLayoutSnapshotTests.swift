import Foundation
import Testing
import SnapshotTesting
@testable import LayoutKit

@MainActor
@Suite("DynamicGridLayout Snapshot Tests", .snapshots(diffTool: "bcomp"))
struct DynamicGridLayoutSnapshotTests {

    // MARK: - Basic Dynamic Grid Tests

    @Test("Dynamic grid - 3 columns")
    func dynamicGrid3Columns() {
        let collection = SnapshotTestHelpers.createTestCollection(
            layout: LayoutTestFactory.dynamicGridLayout(
                horizontalAlignment: .leading,
                verticalAlignment: .leading,
                itemSizing: LayoutTestFactory.relativeSizeSquare(percentage: 0.15),
                dataSource: MockDataSource(itemCount: 9)
            ),
            nodeCount: 9
        )

        let image = SnapshotTestHelpers.render(collectionNode: collection, testSize: .medium)
        assertSnapshot(of: image, as: .image, named: "dynamic-grid-3-columns")
    }

    @Test("Dynamic grid - 2 columns")
    func dynamicGrid2Columns() {
        let collection = SnapshotTestHelpers.createTestCollection(
            layout: LayoutTestFactory.dynamicGridLayout(
                horizontalAlignment: .center,
                verticalAlignment: .center,
                itemSizing: LayoutTestFactory.relativeSizeSquare(percentage: 0.18),
                dataSource: MockDataSource(itemCount: 6)
            ),
            nodeCount: 6
        )

        let image = SnapshotTestHelpers.render(collectionNode: collection, testSize: .medium)
        assertSnapshot(of: image, as: .image, named: "dynamic-grid-2-columns")
    }

    @Test("Dynamic grid - 4 columns")
    func dynamicGrid4Columns() {
        let collection = SnapshotTestHelpers.createTestCollection(
            layout: LayoutTestFactory.dynamicGridLayout(
                horizontalAlignment: .center,
                verticalAlignment: .center,
                itemSizing: LayoutTestFactory.relativeSizeSquare(percentage: 0.12),
                dataSource: MockDataSource(itemCount: 12)
            ),
            nodeCount: 12
        )

        let image = SnapshotTestHelpers.render(collectionNode: collection, testSize: .medium)
        assertSnapshot(of: image, as: .image, named: "dynamic-grid-4-columns")
    }

    // MARK: - Alignment Tests

    @Test("Dynamic grid - leading alignment")
    func dynamicGridLeadingAlignment() {
        let collection = SnapshotTestHelpers.createTestCollection(
            layout: LayoutTestFactory.dynamicGridLayout(
                horizontalAlignment: .leading,
                verticalAlignment: .leading,
                itemSizing: LayoutTestFactory.relativeSizeSquare(percentage: 0.15),
                dataSource: MockDataSource(itemCount: 7)
            ),
            nodeCount: 7
        )

        let image = SnapshotTestHelpers.render(collectionNode: collection, testSize: .medium)
        assertSnapshot(of: image, as: .image, named: "dynamic-grid-leading-alignment")
    }

    @Test("Dynamic grid - center alignment")
    func dynamicGridCenterAlignment() {
        let collection = SnapshotTestHelpers.createTestCollection(
            layout: LayoutTestFactory.dynamicGridLayout(
                horizontalAlignment: .center,
                verticalAlignment: .center,
                itemSizing: LayoutTestFactory.relativeSizeSquare(percentage: 0.15),
                dataSource: MockDataSource(itemCount: 7)
            ),
            nodeCount: 7
        )

        let image = SnapshotTestHelpers.render(collectionNode: collection, testSize: .medium)
        assertSnapshot(of: image, as: .image, named: "dynamic-grid-center-alignment")
    }

    @Test("Dynamic grid - trailing alignment")
    func dynamicGridTrailingAlignment() {
        let collection = SnapshotTestHelpers.createTestCollection(
            layout: LayoutTestFactory.dynamicGridLayout(
                horizontalAlignment: .trailing,
                verticalAlignment: .trailing,
                itemSizing: LayoutTestFactory.relativeSizeSquare(percentage: 0.15),
                dataSource: MockDataSource(itemCount: 7)
            ),
            nodeCount: 7
        )

        let image = SnapshotTestHelpers.render(collectionNode: collection, testSize: .medium)
        assertSnapshot(of: image, as: .image, named: "dynamic-grid-trailing-alignment")
    }

    // MARK: - Spacing Tests

    @Test("Dynamic grid - no spacing")
    func dynamicGridNoSpacing() {
        let collection = SnapshotTestHelpers.createTestCollection(
            layout: LayoutTestFactory.dynamicGridLayout(
                horizontalAlignment: .center,
                verticalAlignment: .center,
                itemSizing: LayoutTestFactory.relativeSizeSquare(percentage: 0.15),
                dataSource: MockDataSource(itemCount: 9)
            ),
            nodeCount: 9
        )

        let image = SnapshotTestHelpers.render(collectionNode: collection, testSize: .medium)
        assertSnapshot(of: image, as: .image, named: "dynamic-grid-no-spacing")
    }

    @Test("Dynamic grid - large spacing")
    func dynamicGridLargeSpacing() {
        let collection = SnapshotTestHelpers.createTestCollection(
            layout: LayoutTestFactory.dynamicGridLayout(
                horizontalAlignment: .center,
                verticalAlignment: .center,
                itemSizing: LayoutTestFactory.relativeSizeSquare(percentage: 0.15),
                dataSource: MockDataSource(itemCount: 6)
            ),
            nodeCount: 6
        )

        let image = SnapshotTestHelpers.render(collectionNode: collection, testSize: .medium)
        assertSnapshot(of: image, as: .image, named: "dynamic-grid-large-spacing")
    }

    // MARK: - Partial Row Tests

    @Test("Dynamic grid - incomplete last row (7 items in 3 columns)")
    func dynamicGridIncompleteRow() {
        let collection = SnapshotTestHelpers.createTestCollection(
            layout: LayoutTestFactory.dynamicGridLayout(
                horizontalAlignment: .center,
                verticalAlignment: .center,
                itemSizing: LayoutTestFactory.relativeSizeSquare(percentage: 0.15),
                dataSource: MockDataSource(itemCount: 7)
            ),
            nodeCount: 7
        )

        let image = SnapshotTestHelpers.render(collectionNode: collection, testSize: .medium)
        assertSnapshot(of: image, as: .image, named: "dynamic-grid-incomplete-row")
    }

    // MARK: - Edge Cases

    @Test("Dynamic grid - single column")
    func dynamicGridSingleColumn() {
        let collection = SnapshotTestHelpers.createTestCollection(
            layout: LayoutTestFactory.dynamicGridLayout(
                horizontalAlignment: .center,
                verticalAlignment: .center,
                itemSizing: LayoutTestFactory.relativeSizeSquare(percentage: 0.15),
                dataSource: MockDataSource(itemCount: 5)
            ),
            nodeCount: 5
        )

        let image = SnapshotTestHelpers.render(collectionNode: collection, testSize: .medium)
        assertSnapshot(of: image, as: .image, named: "dynamic-grid-single-column")
    }

    @Test("Dynamic grid - single item")
    func dynamicGridSingleItem() {
        let collection = SnapshotTestHelpers.createTestCollection(
            layout: LayoutTestFactory.dynamicGridLayout(
                horizontalAlignment: .center,
                verticalAlignment: .center,
                itemSizing: LayoutTestFactory.relativeSizeSquare(percentage: 0.2),
                dataSource: MockDataSource(itemCount: 1)
            ),
            nodeCount: 1
        )

        let image = SnapshotTestHelpers.render(collectionNode: collection, testSize: .medium)
        assertSnapshot(of: image, as: .image, named: "dynamic-grid-single-item")
    }

    @Test("Dynamic grid - many items")
    func dynamicGridManyItems() {
        let collection = SnapshotTestHelpers.createTestCollection(
            layout: LayoutTestFactory.dynamicGridLayout(
                horizontalAlignment: .center,
                verticalAlignment: .center,
                itemSizing: LayoutTestFactory.relativeSizeSquare(percentage: 0.1),
                dataSource: MockDataSource(itemCount: 16)
            ),
            nodeCount: 16
        )

        let image = SnapshotTestHelpers.render(collectionNode: collection, testSize: .medium)
        assertSnapshot(of: image, as: .image, named: "dynamic-grid-many-items")
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
