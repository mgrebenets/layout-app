import Foundation
import Testing
import SnapshotTesting
@testable import LayoutKit

@MainActor
@Suite("GridLayout Snapshot Tests", .snapshots(diffTool: "bcomp"))
struct GridLayoutSnapshotTests {

    // MARK: - Basic Grid Tests

    @Test("Grid layout - 2x2 grid")
    func grid2x2() {
        let collection = SnapshotTestHelpers.createTestCollection(
            layout: LayoutTestFactory.gridLayout(
                rows: 2,
                columns: 2,
                horizontalAlignment: .leading, verticalAlignment: .leading,
                itemSizing: LayoutTestFactory.relativeSizeSquare(percentage: 0.2),
                dataSource: MockDataSource(itemCount: 4)
            ),
            nodeCount: 4
        )

        let image = SnapshotTestHelpers.render(collectionNode: collection, testSize: .medium)
        assertSnapshot(of: image, as: .image, named: "grid-2x2")
    }

    @Test("Grid layout - 3x3 grid")
    func grid3x3() {
        let collection = SnapshotTestHelpers.createTestCollection(
            layout: LayoutTestFactory.gridLayout(
                rows: 3,
                columns: 3,
                horizontalAlignment: .center, verticalAlignment: .center,
                itemSizing: LayoutTestFactory.relativeSizeSquare(percentage: 0.15),
                dataSource: MockDataSource(itemCount: 9)
            ),
            nodeCount: 9
        )

        let image = SnapshotTestHelpers.render(collectionNode: collection, testSize: .medium)
        assertSnapshot(of: image, as: .image, named: "grid-3x3")
    }

    @Test("Grid layout - 4x2 grid")
    func grid4x2() {
        let collection = SnapshotTestHelpers.createTestCollection(
            layout: LayoutTestFactory.gridLayout(
                rows: 4,
                columns: 2,
                horizontalAlignment: .center, verticalAlignment: .center,
                itemSizing: LayoutTestFactory.relativeSizeSquare(percentage: 0.15),
                dataSource: MockDataSource(itemCount: 8)
            ),
            nodeCount: 8
        )

        let image = SnapshotTestHelpers.render(collectionNode: collection, testSize: .medium)
        assertSnapshot(of: image, as: .image, named: "grid-4x2")
    }

    @Test("Grid layout - 2x4 grid")
    func grid2x4() {
        let collection = SnapshotTestHelpers.createTestCollection(
            layout: LayoutTestFactory.gridLayout(
                rows: 2,
                columns: 4,
                horizontalAlignment: .center, verticalAlignment: .center,
                itemSizing: LayoutTestFactory.relativeSizeSquare(percentage: 0.12),
                dataSource: MockDataSource(itemCount: 8)
            ),
            nodeCount: 8
        )

        let image = SnapshotTestHelpers.render(collectionNode: collection, testSize: .medium)
        assertSnapshot(of: image, as: .image, named: "grid-2x4")
    }

    // MARK: - Alignment Tests

    @Test("Grid layout - leading alignment")
    func gridLeadingAlignment() {
        let collection = SnapshotTestHelpers.createTestCollection(
            layout: LayoutTestFactory.gridLayout(
                rows: 2,
                columns: 3,
                horizontalAlignment: .leading, verticalAlignment: .leading,
                itemSizing: LayoutTestFactory.relativeSizeSquare(percentage: 0.15),
                dataSource: MockDataSource(itemCount: 6)
            ),
            nodeCount: 6
        )

        let image = SnapshotTestHelpers.render(collectionNode: collection, testSize: .medium)
        assertSnapshot(of: image, as: .image, named: "grid-leading-alignment")
    }

    @Test("Grid layout - center alignment")
    func gridCenterAlignment() {
        let collection = SnapshotTestHelpers.createTestCollection(
            layout: LayoutTestFactory.gridLayout(
                rows: 2,
                columns: 3,
                horizontalAlignment: .center, verticalAlignment: .center,
                itemSizing: LayoutTestFactory.relativeSizeSquare(percentage: 0.15),
                dataSource: MockDataSource(itemCount: 6)
            ),
            nodeCount: 6
        )

        let image = SnapshotTestHelpers.render(collectionNode: collection, testSize: .medium)
        assertSnapshot(of: image, as: .image, named: "grid-center-alignment")
    }

    @Test("Grid layout - trailing alignment")
    func gridTrailingAlignment() {
        let collection = SnapshotTestHelpers.createTestCollection(
            layout: LayoutTestFactory.gridLayout(
                rows: 2,
                columns: 3,
                horizontalAlignment: .trailing, verticalAlignment: .trailing,
                itemSizing: LayoutTestFactory.relativeSizeSquare(percentage: 0.15),
                dataSource: MockDataSource(itemCount: 6)
            ),
            nodeCount: 6
        )

        let image = SnapshotTestHelpers.render(collectionNode: collection, testSize: .medium)
        assertSnapshot(of: image, as: .image, named: "grid-trailing-alignment")
    }

    @Test("Grid layout - mixed alignment")
    func gridMixedAlignment() {
        let collection = SnapshotTestHelpers.createTestCollection(
            layout: LayoutTestFactory.gridLayout(
                rows: 2,
                columns: 3,
                horizontalAlignment: .center, verticalAlignment: .leading,
                itemSizing: LayoutTestFactory.relativeSizeSquare(percentage: 0.15),
                dataSource: MockDataSource(itemCount: 6)
            ),
            nodeCount: 6
        )

        let image = SnapshotTestHelpers.render(collectionNode: collection, testSize: .medium)
        assertSnapshot(of: image, as: .image, named: "grid-mixed-alignment")
    }

    // MARK: - Partially Filled Grid

    @Test("Grid layout - partially filled (5 items in 3x3)")
    func gridPartiallyFilled() {
        let collection = SnapshotTestHelpers.createTestCollection(
            layout: LayoutTestFactory.gridLayout(
                rows: 3,
                columns: 3,
                horizontalAlignment: .center, verticalAlignment: .center,
                itemSizing: LayoutTestFactory.relativeSizeSquare(percentage: 0.15),
                dataSource: MockDataSource(itemCount: 5)
            ),
            nodeCount: 5
        )

        let image = SnapshotTestHelpers.render(collectionNode: collection, testSize: .medium)
        assertSnapshot(of: image, as: .image, named: "grid-partially-filled")
    }

    // MARK: - Edge Cases

    @Test("Grid layout - single row")
    func gridSingleRow() {
        let collection = SnapshotTestHelpers.createTestCollection(
            layout: LayoutTestFactory.gridLayout(
                rows: 1,
                columns: 5,
                horizontalAlignment: .center, verticalAlignment: .center,
                itemSizing: LayoutTestFactory.relativeSizeSquare(percentage: 0.12),
                dataSource: MockDataSource(itemCount: 5)
            ),
            nodeCount: 5
        )

        let image = SnapshotTestHelpers.render(collectionNode: collection, testSize: .medium)
        assertSnapshot(of: image, as: .image, named: "grid-single-row")
    }

    @Test("Grid layout - single column")
    func gridSingleColumn() {
        let collection = SnapshotTestHelpers.createTestCollection(
            layout: LayoutTestFactory.gridLayout(
                rows: 5,
                columns: 1,
                horizontalAlignment: .center, verticalAlignment: .center,
                itemSizing: LayoutTestFactory.relativeSizeSquare(percentage: 0.12),
                dataSource: MockDataSource(itemCount: 5)
            ),
            nodeCount: 5
        )

        let image = SnapshotTestHelpers.render(collectionNode: collection, testSize: .medium)
        assertSnapshot(of: image, as: .image, named: "grid-single-column")
    }

    @Test("Grid layout - single item in large grid")
    func gridSingleItem() {
        let collection = SnapshotTestHelpers.createTestCollection(
            layout: LayoutTestFactory.gridLayout(
                rows: 3,
                columns: 3,
                horizontalAlignment: .center, verticalAlignment: .center,
                itemSizing: LayoutTestFactory.relativeSizeSquare(percentage: 0.15),
                dataSource: MockDataSource(itemCount: 1)
            ),
            nodeCount: 1
        )

        let image = SnapshotTestHelpers.render(collectionNode: collection, testSize: .medium)
        assertSnapshot(of: image, as: .image, named: "grid-single-item")
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
