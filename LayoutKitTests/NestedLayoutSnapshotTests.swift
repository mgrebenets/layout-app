import Foundation
import Testing
import SnapshotTesting
import SpriteKit
@testable import LayoutKit

@MainActor
@Suite("Nested Layout Snapshot Tests", .snapshots(diffTool: "bcomp"))
struct NestedLayoutSnapshotTests {

    // MARK: - Grid Containing Stacks

    @Test("Nested layout - 2x2 grid with horizontal stacks")
    func gridWithHorizontalStacks() {
        // Create parent grid collection
        let parentCollection = SKCollectionNode(
            layoutBuilder: { _ in LayoutTestFactory.gridLayout(
                rows: 2,
                columns: 2,
                horizontalAlignment: .center, verticalAlignment: .center,
                itemSizing: nil,
                dataSource: MockDataSource(itemCount: 4)
            ) },
            contentInsets: Insets(uniform: 20)
        )

        // Create 4 child collections, each with a horizontal stack
        for i in 0..<4 {
            let childCollection = SKCollectionNode(
                layoutBuilder: { _ in LayoutTestFactory.horizontalStack(
                    alignment: .center,
                    gapPercentage: 0.5,
                    itemSizing: LayoutTestFactory.relativeSizeSquare(percentage: 0.25),
                    dataSource: MockDataSource(itemCount: 3)
                ) },
                contentInsets: Insets(uniform: 5)
            )

            // Add test nodes to child
            let nodes = SnapshotTestHelpers.createTestNodes(count: 3, showIndex: false)
            for node in nodes {
                childCollection.addLayoutableChild(node)
            }

            childCollection.debugBorderColor = SKColor.gray

            parentCollection.addLayoutableChild(childCollection)
        }

        let image = SnapshotTestHelpers.render(collectionNode: parentCollection, testSize: .medium)
        assertSnapshot(of: image, as: .image, named: "nested-grid-with-horizontal-stacks")
    }

    @Test("Nested layout - 2x2 grid with vertical stacks")
    func gridWithVerticalStacks() {
        let parentCollection = SKCollectionNode(
            layoutBuilder: { _ in LayoutTestFactory.gridLayout(
                rows: 2,
                columns: 2,
                horizontalAlignment: .center, verticalAlignment: .center,
                itemSizing: nil,
                dataSource: MockDataSource(itemCount: 4)
            ) },
            contentInsets: Insets(uniform: 20)
        )

        for i in 0..<4 {
            let childCollection = SKCollectionNode(
                layoutBuilder: { _ in LayoutTestFactory.verticalStack(
                    alignment: .center,
                    gapPercentage: 0.5,
                    itemSizing: LayoutTestFactory.relativeSizeSquare(percentage: 0.25),
                    dataSource: MockDataSource(itemCount: 3)
                ) },
                contentInsets: Insets(uniform: 5)
            )

            let nodes = SnapshotTestHelpers.createTestNodes(count: 3, showIndex: false)
            for node in nodes {
                childCollection.addLayoutableChild(node)
            }

            childCollection.debugBorderColor = SKColor.gray

            parentCollection.addLayoutableChild(childCollection)
        }

        let image = SnapshotTestHelpers.render(collectionNode: parentCollection, testSize: .medium)
        assertSnapshot(of: image, as: .image, named: "nested-grid-with-vertical-stacks")
    }

    // MARK: - Grid Containing Circular Layouts

    @Test("Nested layout - 2x2 grid with circular layouts")
    func gridWithCircularLayouts() {
        let parentCollection = SKCollectionNode(
            layoutBuilder: { _ in LayoutTestFactory.gridLayout(
                rows: 2,
                columns: 2,
                horizontalAlignment: .center, verticalAlignment: .center,
                itemSizing: nil,
                dataSource: MockDataSource(itemCount: 4)
            ) },
            contentInsets: Insets(uniform: 20)
        )

        for i in 0..<4 {
            let childCollection = SKCollectionNode(
                layoutBuilder: { _ in LayoutTestFactory.circularLayout(
                    startAngle: 0,
                    angleSpan: 360,
                    radiusPercentage: 0.35,
                    itemSizing: LayoutTestFactory.relativeSizeSquare(percentage: 0.15),
                    dataSource: MockDataSource(itemCount: 6)
                ) },
                contentInsets: Insets(uniform: 5)
            )

            let nodes = SnapshotTestHelpers.createTestNodes(count: 6, showIndex: false)
            for node in nodes {
                childCollection.addLayoutableChild(node)
            }

            childCollection.debugBorderColor = SKColor.gray

            parentCollection.addLayoutableChild(childCollection)
        }

        let image = SnapshotTestHelpers.render(collectionNode: parentCollection, testSize: .medium)
        assertSnapshot(of: image, as: .image, named: "nested-grid-with-circular-layouts")
    }

    // MARK: - Stack Containing Grids

    @Test("Nested layout - horizontal stack with 2x2 grids")
    func stackWithGrids() {
        let parentCollection = SKCollectionNode(
            layoutBuilder: { _ in LayoutTestFactory.horizontalStack(
                alignment: .center,
                gapPercentage: 0.8,
                itemSizing: LayoutTestFactory.relativeSizeSquare(percentage: 0.35),
                dataSource: MockDataSource(itemCount: 2)
            ) },
            contentInsets: Insets(uniform: 20)
        )

        for i in 0..<2 {
            let childCollection = SKCollectionNode(
                layoutBuilder: { _ in LayoutTestFactory.gridLayout(
                    rows: 2,
                    columns: 2,
                    horizontalAlignment: .center, verticalAlignment: .center,
                    itemSizing: LayoutTestFactory.relativeSizeSquare(percentage: 0.35),
                    dataSource: MockDataSource(itemCount: 4)
                ) },
                contentInsets: Insets(uniform: 5)
            )

            let nodes = SnapshotTestHelpers.createTestNodes(count: 4, showIndex: false)
            for node in nodes {
                childCollection.addLayoutableChild(node)
            }

            childCollection.debugBorderColor = SKColor.gray

            parentCollection.addLayoutableChild(childCollection)
        }

        let image = SnapshotTestHelpers.render(collectionNode: parentCollection, testSize: .medium)
        assertSnapshot(of: image, as: .image, named: "nested-stack-with-grids")
    }

    // MARK: - Mixed Nested Layouts

    @Test("Nested layout - grid with mixed child layouts")
    func gridWithMixedChildren() {
        let parentCollection = SKCollectionNode(
            layoutBuilder: { _ in LayoutTestFactory.gridLayout(
                rows: 2,
                columns: 2,
                horizontalAlignment: .center, verticalAlignment: .center,
                itemSizing: nil,
                dataSource: MockDataSource(itemCount: 4)
            ) },
            contentInsets: Insets(uniform: 20)
        )

        // Top-left: Horizontal stack
        let stackChild = SKCollectionNode(
            layoutBuilder: { _ in LayoutTestFactory.horizontalStack(
                alignment: .center,
                gapPercentage: 0.5,
                itemSizing: LayoutTestFactory.relativeSizeSquare(percentage: 0.25),
                dataSource: MockDataSource(itemCount: 3)
            ) },
            contentInsets: Insets(uniform: 5)
        )
        let stackNodes = SnapshotTestHelpers.createTestNodes(count: 3, showIndex: false)
        for node in stackNodes {
            stackChild.addLayoutableChild(node)
        }
        stackChild.debugBorderColor = SKColor.gray
        parentCollection.addLayoutableChild(stackChild)

        // Top-right: Circular
        let circularChild = SKCollectionNode(
            layoutBuilder: { _ in LayoutTestFactory.circularLayout(
                startAngle: 0,
                angleSpan: 360,
                radiusPercentage: 0.35,
                itemSizing: LayoutTestFactory.relativeSizeSquare(percentage: 0.15),
                dataSource: MockDataSource(itemCount: 5)
            ) },
            contentInsets: Insets(uniform: 5)
        )
        let circularNodes = SnapshotTestHelpers.createTestNodes(count: 5, showIndex: false)
        for node in circularNodes {
            circularChild.addLayoutableChild(node)
        }
        circularChild.debugBorderColor = SKColor.gray
        parentCollection.addLayoutableChild(circularChild)

        // Bottom-left: Diagonal
        let diagonalChild = SKCollectionNode(
            layoutBuilder: { _ in LayoutTestFactory.diagonalLayout(
                horizontalAlignment: .center,
                verticalAlignment: .center,
                horizontalGapPercentage: 0.5,
                verticalGapPercentage: 0.5,
                itemSizing: LayoutTestFactory.relativeSizeSquare(percentage: 0.2),
                dataSource: MockDataSource(itemCount: 4)
            ) },
            contentInsets: Insets(uniform: 5)
        )
        let diagonalNodes = SnapshotTestHelpers.createTestNodes(count: 4, showIndex: false)
        for node in diagonalNodes {
            diagonalChild.addLayoutableChild(node)
        }
        diagonalChild.debugBorderColor = SKColor.gray
        parentCollection.addLayoutableChild(diagonalChild)

        // Bottom-right: 2x2 Grid
        let gridChild = SKCollectionNode(
            layoutBuilder: { _ in LayoutTestFactory.gridLayout(
                rows: 2,
                columns: 2,
                horizontalAlignment: .center, verticalAlignment: .center,
                itemSizing: LayoutTestFactory.relativeSizeSquare(percentage: 0.35),
                dataSource: MockDataSource(itemCount: 4)
            ) },
            contentInsets: Insets(uniform: 5)
        )
        let gridNodes = SnapshotTestHelpers.createTestNodes(count: 4, showIndex: false)
        for node in gridNodes {
            gridChild.addLayoutableChild(node)
        }
        gridChild.debugBorderColor = SKColor.gray
        parentCollection.addLayoutableChild(gridChild)

        let image = SnapshotTestHelpers.render(collectionNode: parentCollection, testSize: .medium)
        assertSnapshot(of: image, as: .image, named: "nested-grid-with-mixed-children")
    }

    // MARK: - Three Levels Deep

    @Test("Nested layout - three levels (grid > stack > shapes)")
    func threeLevelsDeep() {
        // Level 1: Parent grid (2x1)
        let parentCollection = SKCollectionNode(
            layoutBuilder: { _ in LayoutTestFactory.gridLayout(
                rows: 1,
                columns: 2,
                horizontalAlignment: .center, verticalAlignment: .center,
                itemSizing: nil,
                dataSource: MockDataSource(itemCount: 2)
            ) },
            contentInsets: Insets(uniform: 20)
        )

        for i in 0..<2 {
            // Level 2: Child stack (vertical)
            let childCollection = SKCollectionNode(
                layoutBuilder: { _ in LayoutTestFactory.verticalStack(
                    alignment: .center,
                    gapPercentage: 0.5,
                    itemSizing: LayoutTestFactory.relativeSizeSquare(percentage: 0.3),
                    dataSource: MockDataSource(itemCount: 2)
                ) },
                contentInsets: Insets(uniform: 10)
            )

            for j in 0..<2 {
                // Level 3: Grandchild circular layout
                let grandchildCollection = SKCollectionNode(
                    layoutBuilder: { _ in LayoutTestFactory.circularLayout(
                        startAngle: 0,
                        angleSpan: 360,
                        radiusPercentage: 0.3,
                        itemSizing: LayoutTestFactory.relativeSizeSquare(percentage: 0.2),
                        dataSource: MockDataSource(itemCount: 4)
                    ) },
                    contentInsets: Insets(uniform: 2)
                )

                let nodes = SnapshotTestHelpers.createTestNodes(count: 4, showIndex: false)
                for node in nodes {
                    grandchildCollection.addLayoutableChild(node)
                }

                grandchildCollection.debugBorderColor = SKColor.darkGray

                childCollection.addLayoutableChild(grandchildCollection)
            }

            childCollection.debugBorderColor = SKColor.gray

            parentCollection.addLayoutableChild(childCollection)
        }

        let image = SnapshotTestHelpers.render(collectionNode: parentCollection, testSize: .medium)
        assertSnapshot(of: image, as: .image, named: "nested-three-levels-deep")
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
