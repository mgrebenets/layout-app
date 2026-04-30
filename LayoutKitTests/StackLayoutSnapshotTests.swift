import Foundation
import Testing
import SnapshotTesting
@testable import LayoutKit

@MainActor
@Suite("StackLayout Snapshot Tests", .snapshots(diffTool: "bcomp"))
struct StackLayoutSnapshotTests {

    // MARK: - Horizontal Stack Tests

    @Test("Horizontal stack - leading alignment")
    func horizontalStackLeading() {
        let collection = SnapshotTestHelpers.createTestCollection(
            layout: LayoutTestFactory.horizontalStack(
                alignment: .leading,
                gapPercentage: 0.5,
                itemSizing: LayoutTestFactory.relativeSizeSquare(percentage: 0.15),
                dataSource: MockDataSource(itemCount: 5)
            ),
            nodeCount: 5
        )

        let image = SnapshotTestHelpers.render(collectionNode: collection, testSize: .medium)
        assertSnapshot(of: image, as: .image, named: "horizontal-stack-leading")
    }

    @Test("Horizontal stack - center alignment")
    func horizontalStackCenter() {
        let collection = SnapshotTestHelpers.createTestCollection(
            layout: LayoutTestFactory.horizontalStack(
                alignment: .center,
                gapPercentage: 0.5,
                itemSizing: LayoutTestFactory.relativeSizeSquare(percentage: 0.15),
                dataSource: MockDataSource(itemCount: 5)
            ),
            nodeCount: 5
        )

        let image = SnapshotTestHelpers.render(collectionNode: collection, testSize: .medium)
        assertSnapshot(of: image, as: .image, named: "horizontal-stack-center")
    }

    @Test("Horizontal stack - trailing alignment")
    func horizontalStackTrailing() {
        let collection = SnapshotTestHelpers.createTestCollection(
            layout: LayoutTestFactory.horizontalStack(
                alignment: .trailing,
                gapPercentage: 0.5,
                itemSizing: LayoutTestFactory.relativeSizeSquare(percentage: 0.15),
                dataSource: MockDataSource(itemCount: 5)
            ),
            nodeCount: 5
        )

        let image = SnapshotTestHelpers.render(collectionNode: collection, testSize: .medium)
        assertSnapshot(of: image, as: .image, named: "horizontal-stack-trailing")
    }

    // MARK: - Vertical Stack Tests

    @Test("Vertical stack - leading alignment")
    func verticalStackLeading() {
        let collection = SnapshotTestHelpers.createTestCollection(
            layout: LayoutTestFactory.verticalStack(
                alignment: .leading,
                gapPercentage: 0.5,
                itemSizing: LayoutTestFactory.relativeSizeSquare(percentage: 0.15),
                dataSource: MockDataSource(itemCount: 5)
            ),
            nodeCount: 5
        )

        let image = SnapshotTestHelpers.render(collectionNode: collection, testSize: .medium)
        assertSnapshot(of: image, as: .image, named: "vertical-stack-leading")
    }

    @Test("Vertical stack - center alignment")
    func verticalStackCenter() {
        let collection = SnapshotTestHelpers.createTestCollection(
            layout: LayoutTestFactory.verticalStack(
                alignment: .center,
                gapPercentage: 0.5,
                itemSizing: LayoutTestFactory.relativeSizeSquare(percentage: 0.15),
                dataSource: MockDataSource(itemCount: 5)
            ),
            nodeCount: 5
        )

        let image = SnapshotTestHelpers.render(collectionNode: collection, testSize: .medium)
        assertSnapshot(of: image, as: .image, named: "vertical-stack-center")
    }

    @Test("Vertical stack - trailing alignment")
    func verticalStackTrailing() {
        let collection = SnapshotTestHelpers.createTestCollection(
            layout: LayoutTestFactory.verticalStack(
                alignment: .trailing,
                gapPercentage: 0.5,
                itemSizing: LayoutTestFactory.relativeSizeSquare(percentage: 0.15),
                dataSource: MockDataSource(itemCount: 5)
            ),
            nodeCount: 5
        )

        let image = SnapshotTestHelpers.render(collectionNode: collection, testSize: .medium)
        assertSnapshot(of: image, as: .image, named: "vertical-stack-trailing")
    }

    // MARK: - Gap Percentage Tests

    @Test("Horizontal stack - zero gap (complete overlap)")
    func horizontalStackZeroGap() {
        let collection = SnapshotTestHelpers.createTestCollection(
            layout: LayoutTestFactory.horizontalStack(
                alignment: .center,
                gapPercentage: 0.0,
                itemSizing: LayoutTestFactory.relativeSizeSquare(percentage: 0.15),
                dataSource: MockDataSource(itemCount: 5)
            ),
            nodeCount: 5
        )

        let image = SnapshotTestHelpers.render(collectionNode: collection, testSize: .medium)
        assertSnapshot(of: image, as: .image, named: "horizontal-stack-zero-gap")
    }

    @Test("Horizontal stack - full gap (touching)")
    func horizontalStackFullGap() {
        let collection = SnapshotTestHelpers.createTestCollection(
            layout: LayoutTestFactory.horizontalStack(
                alignment: .center,
                gapPercentage: 1.0,
                itemSizing: LayoutTestFactory.relativeSizeSquare(percentage: 0.15),
                dataSource: MockDataSource(itemCount: 5)
            ),
            nodeCount: 5
        )

        let image = SnapshotTestHelpers.render(collectionNode: collection, testSize: .medium)
        assertSnapshot(of: image, as: .image, named: "horizontal-stack-full-gap")
    }

    @Test("Horizontal stack - negative gap")
    func horizontalStackNegativeGap() {
        let collection = SnapshotTestHelpers.createTestCollection(
            layout: LayoutTestFactory.horizontalStack(
                alignment: .center,
                gapPercentage: -0.5,
                itemSizing: LayoutTestFactory.relativeSizeSquare(percentage: 0.15),
                dataSource: MockDataSource(itemCount: 5)
            ),
            nodeCount: 5
        )

        let image = SnapshotTestHelpers.render(collectionNode: collection, testSize: .medium)
        assertSnapshot(of: image, as: .image, named: "horizontal-stack-negative-gap")
    }

    // MARK: - Edge Cases

    @Test("Horizontal stack - single item")
    func horizontalStackSingleItem() {
        let collection = SnapshotTestHelpers.createTestCollection(
            layout: LayoutTestFactory.horizontalStack(
                alignment: .center,
                gapPercentage: 0.5,
                itemSizing: LayoutTestFactory.relativeSizeSquare(percentage: 0.2),
                dataSource: MockDataSource(itemCount: 1)
            ),
            nodeCount: 1
        )

        let image = SnapshotTestHelpers.render(collectionNode: collection, testSize: .medium)
        assertSnapshot(of: image, as: .image, named: "horizontal-stack-single-item")
    }

    @Test("Horizontal stack - many items")
    func horizontalStackManyItems() {
        let collection = SnapshotTestHelpers.createTestCollection(
            layout: LayoutTestFactory.horizontalStack(
                alignment: .center,
                gapPercentage: 0.5,
                itemSizing: LayoutTestFactory.relativeSizeSquare(percentage: 0.1),
                dataSource: MockDataSource(itemCount: 10)
            ),
            nodeCount: 10
        )

        let image = SnapshotTestHelpers.render(collectionNode: collection, testSize: .medium)
        assertSnapshot(of: image, as: .image, named: "horizontal-stack-many-items")
    }

    @Test("Vertical stack - many items")
    func verticalStackManyItems() {
        let collection = SnapshotTestHelpers.createTestCollection(
            layout: LayoutTestFactory.verticalStack(
                alignment: .center,
                gapPercentage: 0.5,
                itemSizing: LayoutTestFactory.relativeSizeSquare(percentage: 0.1),
                dataSource: MockDataSource(itemCount: 10)
            ),
            nodeCount: 10
        )

        let image = SnapshotTestHelpers.render(collectionNode: collection, testSize: .medium)
        assertSnapshot(of: image, as: .image, named: "vertical-stack-many-items")
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
