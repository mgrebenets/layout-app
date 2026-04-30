import Foundation
import Testing
import SnapshotTesting
@testable import LayoutKit

@MainActor
@Suite("CircularLayout Snapshot Tests", .snapshots(diffTool: "bcomp"))
struct CircularLayoutSnapshotTests {

    // MARK: - Full Circle Tests

    @Test("Circular layout - full circle (360 degrees)")
    func circularFullCircle() {
        let collection = SnapshotTestHelpers.createTestCollection(
            layout: LayoutTestFactory.circularLayout(
                startAngle: 0,
                angleSpan: 360,
                radiusPercentage: 0.35,
                itemSizing: LayoutTestFactory.relativeSizeSquare(percentage: 0.1),
                dataSource: MockDataSource(itemCount: 8)
            ),
            nodeCount: 8
        )

        let image = SnapshotTestHelpers.render(collectionNode: collection, testSize: .medium)
        assertSnapshot(of: image, as: .image, named: "circular-full-circle")
    }

    @Test("Circular layout - semicircle (top half)")
    func circularSemicircleTop() {
        let collection = SnapshotTestHelpers.createTestCollection(
            layout: LayoutTestFactory.circularLayout(
                startAngle: 180,
                angleSpan: 180,
                radiusPercentage: 0.35,
                itemSizing: LayoutTestFactory.relativeSizeSquare(percentage: 0.1),
                dataSource: MockDataSource(itemCount: 6)
            ),
            nodeCount: 6
        )

        let image = SnapshotTestHelpers.render(collectionNode: collection, testSize: .medium)
        assertSnapshot(of: image, as: .image, named: "circular-semicircle-top")
    }

    @Test("Circular layout - semicircle (bottom half)")
    func circularSemicircleBottom() {
        let collection = SnapshotTestHelpers.createTestCollection(
            layout: LayoutTestFactory.circularLayout(
                startAngle: 0,
                angleSpan: 180,
                radiusPercentage: 0.35,
                itemSizing: LayoutTestFactory.relativeSizeSquare(percentage: 0.1),
                dataSource: MockDataSource(itemCount: 6)
            ),
            nodeCount: 6
        )

        let image = SnapshotTestHelpers.render(collectionNode: collection, testSize: .medium)
        assertSnapshot(of: image, as: .image, named: "circular-semicircle-bottom")
    }

    @Test("Circular layout - quarter circle (arc)")
    func circularQuarterCircle() {
        let collection = SnapshotTestHelpers.createTestCollection(
            layout: LayoutTestFactory.circularLayout(
                startAngle: 45,
                angleSpan: 90,
                radiusPercentage: 0.35,
                itemSizing: LayoutTestFactory.relativeSizeSquare(percentage: 0.12),
                dataSource: MockDataSource(itemCount: 5)
            ),
            nodeCount: 5
        )

        let image = SnapshotTestHelpers.render(collectionNode: collection, testSize: .medium)
        assertSnapshot(of: image, as: .image, named: "circular-quarter-circle")
    }

    // MARK: - Radius Tests

    @Test("Circular layout - small radius")
    func circularSmallRadius() {
        let collection = SnapshotTestHelpers.createTestCollection(
            layout: LayoutTestFactory.circularLayout(
                startAngle: 0,
                angleSpan: 360,
                radiusPercentage: 0.2,
                itemSizing: LayoutTestFactory.relativeSizeSquare(percentage: 0.08),
                dataSource: MockDataSource(itemCount: 8)
            ),
            nodeCount: 8
        )

        let image = SnapshotTestHelpers.render(collectionNode: collection, testSize: .medium)
        assertSnapshot(of: image, as: .image, named: "circular-small-radius")
    }

    @Test("Circular layout - large radius")
    func circularLargeRadius() {
        let collection = SnapshotTestHelpers.createTestCollection(
            layout: LayoutTestFactory.circularLayout(
                startAngle: 0,
                angleSpan: 360,
                radiusPercentage: 0.45,
                itemSizing: LayoutTestFactory.relativeSizeSquare(percentage: 0.08),
                dataSource: MockDataSource(itemCount: 12)
            ),
            nodeCount: 12
        )

        let image = SnapshotTestHelpers.render(collectionNode: collection, testSize: .medium)
        assertSnapshot(of: image, as: .image, named: "circular-large-radius")
    }

    // MARK: - Item Count Variations

    @Test("Circular layout - few items (3)")
    func circularFewItems() {
        let collection = SnapshotTestHelpers.createTestCollection(
            layout: LayoutTestFactory.circularLayout(
                startAngle: 0,
                angleSpan: 360,
                radiusPercentage: 0.35,
                itemSizing: LayoutTestFactory.relativeSizeSquare(percentage: 0.15),
                dataSource: MockDataSource(itemCount: 3)
            ),
            nodeCount: 3
        )

        let image = SnapshotTestHelpers.render(collectionNode: collection, testSize: .medium)
        assertSnapshot(of: image, as: .image, named: "circular-few-items")
    }

    @Test("Circular layout - many items (16)")
    func circularManyItems() {
        let collection = SnapshotTestHelpers.createTestCollection(
            layout: LayoutTestFactory.circularLayout(
                startAngle: 0,
                angleSpan: 360,
                radiusPercentage: 0.38,
                itemSizing: LayoutTestFactory.relativeSizeSquare(percentage: 0.06),
                dataSource: MockDataSource(itemCount: 16)
            ),
            nodeCount: 16
        )

        let image = SnapshotTestHelpers.render(collectionNode: collection, testSize: .medium)
        assertSnapshot(of: image, as: .image, named: "circular-many-items")
    }

    // MARK: - Start Angle Variations

    @Test("Circular layout - start at top (90 degrees)")
    func circularStartTop() {
        let collection = SnapshotTestHelpers.createTestCollection(
            layout: LayoutTestFactory.circularLayout(
                startAngle: 90,
                angleSpan: 360,
                radiusPercentage: 0.35,
                itemSizing: LayoutTestFactory.relativeSizeSquare(percentage: 0.1),
                dataSource: MockDataSource(itemCount: 8)
            ),
            nodeCount: 8
        )

        let image = SnapshotTestHelpers.render(collectionNode: collection, testSize: .medium)
        assertSnapshot(of: image, as: .image, named: "circular-start-top")
    }

    @Test("Circular layout - single item")
    func circularSingleItem() {
        let collection = SnapshotTestHelpers.createTestCollection(
            layout: LayoutTestFactory.circularLayout(
                startAngle: 0,
                angleSpan: 360,
                radiusPercentage: 0.3,
                itemSizing: LayoutTestFactory.relativeSizeSquare(percentage: 0.15),
                dataSource: MockDataSource(itemCount: 1)
            ),
            nodeCount: 1
        )

        let image = SnapshotTestHelpers.render(collectionNode: collection, testSize: .medium)
        assertSnapshot(of: image, as: .image, named: "circular-single-item")
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
