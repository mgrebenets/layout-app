import Foundation
import Testing
import SnapshotTesting
@testable import LayoutKit

@MainActor
@Suite("WaterfallLayout Snapshot Tests", .snapshots(diffTool: "bcomp"))
struct WaterfallLayoutSnapshotTests {

    // MARK: - Basic Waterfall Tests

    @Test("Waterfall layout - 2 columns")
    func waterfall2Columns() {
        let collection = SnapshotTestHelpers.createTestCollection(
            layout: LayoutTestFactory.waterfallLayout(
                columns: 2,
                columnSpacing: 10,
                itemSpacing: 10,
                itemSizing: LayoutTestFactory.relativeSizeSquare(percentage: 0.2),
                dataSource: MockDataSource(itemCount: 6)
            ),
            nodeCount: 6
        )

        let image = SnapshotTestHelpers.render(collectionNode: collection, testSize: .medium)
        assertSnapshot(of: image, as: .image, named: "waterfall-2-columns")
    }

    @Test("Waterfall layout - 3 columns")
    func waterfall3Columns() {
        let collection = SnapshotTestHelpers.createTestCollection(
            layout: LayoutTestFactory.waterfallLayout(
                columns: 3,
                columnSpacing: 10,
                itemSpacing: 10,
                itemSizing: LayoutTestFactory.relativeSizeSquare(percentage: 0.15),
                dataSource: MockDataSource(itemCount: 9)
            ),
            nodeCount: 9
        )

        let image = SnapshotTestHelpers.render(collectionNode: collection, testSize: .medium)
        assertSnapshot(of: image, as: .image, named: "waterfall-3-columns")
    }

    @Test("Waterfall layout - 4 columns")
    func waterfall4Columns() {
        let collection = SnapshotTestHelpers.createTestCollection(
            layout: LayoutTestFactory.waterfallLayout(
                columns: 4,
                columnSpacing: 8,
                itemSpacing: 8,
                itemSizing: LayoutTestFactory.relativeSizeSquare(percentage: 0.12),
                dataSource: MockDataSource(itemCount: 12)
            ),
            nodeCount: 12
        )

        let image = SnapshotTestHelpers.render(collectionNode: collection, testSize: .medium)
        assertSnapshot(of: image, as: .image, named: "waterfall-4-columns")
    }

    // MARK: - Spacing Tests

    @Test("Waterfall layout - no spacing")
    func waterfallNoSpacing() {
        let collection = SnapshotTestHelpers.createTestCollection(
            layout: LayoutTestFactory.waterfallLayout(
                columns: 2,
                columnSpacing: 0,
                itemSpacing: 0,
                itemSizing: LayoutTestFactory.relativeSizeSquare(percentage: 0.2),
                dataSource: MockDataSource(itemCount: 6)
            ),
            nodeCount: 6
        )

        let image = SnapshotTestHelpers.render(collectionNode: collection, testSize: .medium)
        assertSnapshot(of: image, as: .image, named: "waterfall-no-spacing")
    }

    @Test("Waterfall layout - large spacing")
    func waterfallLargeSpacing() {
        let collection = SnapshotTestHelpers.createTestCollection(
            layout: LayoutTestFactory.waterfallLayout(
                columns: 2,
                columnSpacing: 20,
                itemSpacing: 20,
                itemSizing: LayoutTestFactory.relativeSizeSquare(percentage: 0.18),
                dataSource: MockDataSource(itemCount: 6)
            ),
            nodeCount: 6
        )

        let image = SnapshotTestHelpers.render(collectionNode: collection, testSize: .medium)
        assertSnapshot(of: image, as: .image, named: "waterfall-large-spacing")
    }

    // MARK: - Item Count Variations

    @Test("Waterfall layout - few items (3 items, 2 columns)")
    func waterfallFewItems() {
        let collection = SnapshotTestHelpers.createTestCollection(
            layout: LayoutTestFactory.waterfallLayout(
                columns: 2,
                columnSpacing: 10,
                itemSpacing: 10,
                itemSizing: LayoutTestFactory.relativeSizeSquare(percentage: 0.2),
                dataSource: MockDataSource(itemCount: 3)
            ),
            nodeCount: 3
        )

        let image = SnapshotTestHelpers.render(collectionNode: collection, testSize: .medium)
        assertSnapshot(of: image, as: .image, named: "waterfall-few-items")
    }

    @Test("Waterfall layout - many items")
    func waterfallManyItems() {
        let collection = SnapshotTestHelpers.createTestCollection(
            layout: LayoutTestFactory.waterfallLayout(
                columns: 3,
                columnSpacing: 8,
                itemSpacing: 8,
                itemSizing: LayoutTestFactory.relativeSizeSquare(percentage: 0.12),
                dataSource: MockDataSource(itemCount: 15)
            ),
            nodeCount: 15
        )

        let image = SnapshotTestHelpers.render(collectionNode: collection, testSize: .medium)
        assertSnapshot(of: image, as: .image, named: "waterfall-many-items")
    }

    // MARK: - Edge Cases

    @Test("Waterfall layout - single column")
    func waterfallSingleColumn() {
        let collection = SnapshotTestHelpers.createTestCollection(
            layout: LayoutTestFactory.waterfallLayout(
                columns: 1,
                columnSpacing: 0,
                itemSpacing: 10,
                itemSizing: LayoutTestFactory.relativeSizeSquare(percentage: 0.2),
                dataSource: MockDataSource(itemCount: 5)
            ),
            nodeCount: 5
        )

        let image = SnapshotTestHelpers.render(collectionNode: collection, testSize: .medium)
        assertSnapshot(of: image, as: .image, named: "waterfall-single-column")
    }

    @Test("Waterfall layout - single item")
    func waterfallSingleItem() {
        let collection = SnapshotTestHelpers.createTestCollection(
            layout: LayoutTestFactory.waterfallLayout(
                columns: 3,
                columnSpacing: 10,
                itemSpacing: 10,
                itemSizing: LayoutTestFactory.relativeSizeSquare(percentage: 0.2),
                dataSource: MockDataSource(itemCount: 1)
            ),
            nodeCount: 1
        )

        let image = SnapshotTestHelpers.render(collectionNode: collection, testSize: .medium)
        assertSnapshot(of: image, as: .image, named: "waterfall-single-item")
    }
}

// MARK: - Mock Data Source

private final class MockDataSource: CollectionLayoutDataSource {
    let itemCount: Int

    init(itemCount: Int) {
        self.itemCount = itemCount
    }

    var numberOfItems: Int {
        return itemCount
    }
}
