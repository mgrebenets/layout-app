//
//  LayoutScenarioScene.swift
//  LayoutApp macOS
//
//  Created by Max Grebenets on 21/10/2025.
//

import SpriteKit
import LayoutKit

// Simple data source for placeholder layouts
private struct EmptyDataSource: CollectionLayoutDataSource {
    var numberOfItems: Int { 0 }
}

/// A SpriteKit scene that configures its content based on a specific scenario
public class LayoutScenarioScene: SKScene {
    private let coordinator = NodeCoordinator()
    private let coordinatorDelegate = DefaultNodeCoordinatorDelegate() // Strong reference!
    private let pool = NodePool(maxPoolSize: 100)
    private var scenario: ScenarioType = .overview
    private weak var contextMenuState: ContextMenuState?

    // Properties for overview scenario (from GameScene)
    private var layoutContainers: [(config: LayoutConfiguration, collectionNode: SKCollectionNode, frame: SKShapeNode)] = []
    private var centerCollection: SKCollectionNode?
    private var centerGridConfig: CenterGridConfiguration?
    private var diagonalCollection: SKCollectionNode?
    private var diagonalConfig: DiagonalConfiguration?
    private var circularCollection: SKCollectionNode?
    private var circularConfig: CircularConfiguration?
    private var dynamicGridCollection: SKCollectionNode?
    private var gridConfig: GridConfiguration?
    private var nestedCollection: SKCollectionNode?

    public static func create(for scenario: Scenario, contextMenuState: ContextMenuState) -> LayoutScenarioScene {
        let scene = LayoutScenarioScene(size: CGSize(width: 1024, height: 768))
        scene.scenario = scenario.type
        scene.scaleMode = .resizeFill
        scene.contextMenuState = contextMenuState
        return scene
    }

    public override func didMove(to view: SKView) {
        coordinator.setParentContainer(self)
        coordinator.delegate = coordinatorDelegate // Use the stored property

        setupCallbacks()
        setupScenario()
    }

    public override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        guard scene?.view != nil, !coordinator.isTracking else { return }
        setupScenario()
    }

    private func setupCallbacks() {
        guard let state = contextMenuState else { return }

        // Stack layout callbacks
        state.onStackAlignmentChange = { [weak self] index, newAlignment in
            self?.updateStackAlignment(at: index, newAlignment: newAlignment)
        }
        state.onStackGapChange = { [weak self] index, newGap in
            self?.updateStackGap(at: index, newGap: newGap)
        }
        state.onStackZOrderChange = { [weak self] index, newZOrder in
            self?.updateStackZOrder(at: index, newZOrder: newZOrder)
        }
        state.onStackItemCountChange = { [weak self] index, newCount in
            self?.updateStackItemCount(at: index, newCount: newCount)
        }
        state.onStackItemSizingChange = { [weak self] index, newSizing in
            self?.updateStackItemSizing(at: index, newSizing: newSizing)
        }

        // Diagonal layout callbacks
        state.onDiagonalHorizontalAlignmentChange = { [weak self] newAlignment in
            self?.updateDiagonalHorizontalAlignment(newAlignment)
        }
        state.onDiagonalVerticalAlignmentChange = { [weak self] newAlignment in
            self?.updateDiagonalVerticalAlignment(newAlignment)
        }
        state.onDiagonalHorizontalGapChange = { [weak self] newGap in
            self?.updateDiagonalHorizontalGap(newGap)
        }
        state.onDiagonalVerticalGapChange = { [weak self] newGap in
            self?.updateDiagonalVerticalGap(newGap)
        }
        state.onDiagonalZOrderChange = { [weak self] newZOrder in
            self?.updateDiagonalZOrder(newZOrder)
        }
        state.onDiagonalItemCountChange = { [weak self] newCount in
            self?.updateDiagonalItemCount(newCount)
        }
        state.onDiagonalItemSizingChange = { [weak self] newSizing in
            self?.updateDiagonalItemSizing(newSizing)
        }

        // Circular layout callbacks
        state.onCircularItemCountChange = { [weak self] newCount in
            self?.updateCircularItemCount(newCount)
        }
        state.onCircularStartAngleChange = { [weak self] newAngle in
            self?.updateCircularStartAngle(newAngle)
        }
        state.onCircularRadiusGapChange = { [weak self] newGap in
            self?.updateCircularRadiusGap(newGap)
        }
        state.onCircularItemSizingChange = { [weak self] newSizing in
            self?.updateCircularItemSizing(newSizing)
        }
        state.onCircularZOrderChange = { [weak self] newZOrder in
            self?.updateCircularZOrder(newZOrder)
        }

        // Grid layout callbacks
        state.onGridHorizontalAlignmentChange = { [weak self] newAlignment in
            self?.updateGridHorizontalAlignment(newAlignment)
        }
        state.onGridVerticalAlignmentChange = { [weak self] newAlignment in
            self?.updateGridVerticalAlignment(newAlignment)
        }
        state.onGridHorizontalGapChange = { [weak self] newGap in
            self?.updateGridHorizontalGap(newGap)
        }
        state.onGridVerticalGapChange = { [weak self] newGap in
            self?.updateGridVerticalGap(newGap)
        }
        state.onGridZOrderChange = { [weak self] newZOrder in
            self?.updateGridZOrder(newZOrder)
        }
        state.onGridItemCountChange = { [weak self] newCount in
            self?.updateGridItemCount(newCount)
        }
        state.onGridItemSizingChange = { [weak self] newSizing in
            self?.updateGridItemSizing(newSizing)
        }

        // Center grid layout callbacks
        state.onCenterGridRowsChange = { [weak self] newRows in
            self?.updateCenterGridRows(newRows)
        }
        state.onCenterGridColumnsChange = { [weak self] newColumns in
            self?.updateCenterGridColumns(newColumns)
        }
        state.onCenterGridHorizontalAlignmentChange = { [weak self] newAlignment in
            self?.updateCenterGridHorizontalAlignment(newAlignment)
        }
        state.onCenterGridVerticalAlignmentChange = { [weak self] newAlignment in
            self?.updateCenterGridVerticalAlignment(newAlignment)
        }
        state.onCenterGridHorizontalGapChange = { [weak self] newGap in
            self?.updateCenterGridHorizontalGap(newGap)
        }
        state.onCenterGridVerticalGapChange = { [weak self] newGap in
            self?.updateCenterGridVerticalGap(newGap)
        }
        state.onCenterGridZOrderChange = { [weak self] newZOrder in
            self?.updateCenterGridZOrder(newZOrder)
        }
        state.onCenterGridItemSizingChange = { [weak self] newSizing in
            self?.updateCenterGridItemSizing(newSizing)
        }
    }

    private func setupScenario() {
        removeAllChildren()
        coordinator.unregisterAll()

        // Clear state
        layoutContainers.removeAll()
        centerCollection = nil
        centerGridConfig = nil
        diagonalCollection = nil
        diagonalConfig = nil
        circularCollection = nil
        circularConfig = nil
        dynamicGridCollection = nil
        gridConfig = nil
        nestedCollection = nil

        // Only setup overview for now
        setupOverview()
    }

    // MARK: - Overview Scenario (Full GameScene)

    private func setupOverview() {
        backgroundColor = .white

        let margin: CGFloat = 20
        let sideWidth: CGFloat = 100
        let topBottomHeight: CGFloat = 80

        // Center area - use GridLayout to arrange 4 collections in 2x2 grid
        let centerWidth = size.width - 2 * margin - 2 * sideWidth
        let centerHeight = size.height - 2 * margin - 2 * topBottomHeight
        setupCenterGridLayout(
            rect: CGRect(
                x: margin + sideWidth,
                y: topBottomHeight + margin,
                width: centerWidth,
                height: centerHeight
            )
        )

        // Left vertical layout - overlap
        let leftConfig = LayoutConfiguration(
            axis: .vertical,
            itemSizing: RelativeSizing(baseDimension: .width, aspectRatio: 1.0),
            gapPercentage: 0.5,
            alignment: .leading,
            zOrder: .descending,
            rect: CGRect(
                x: margin,
                y: topBottomHeight + margin,
                width: sideWidth,
                height: size.height - 2 * margin - 2 * topBottomHeight
            ),
            itemCount: 8
        )
        addLayoutContainer(config: leftConfig)

        // Right vertical layout - centered
        let rightConfig = LayoutConfiguration(
            axis: .vertical,
            itemSizing: RelativeSizing(baseDimension: .width, aspectRatio: 1.2),
            gapPercentage: 1.2,
            alignment: .center,
            zOrder: .ascending,
            rect: CGRect(
                x: size.width - margin - sideWidth,
                y: topBottomHeight + margin,
                width: sideWidth,
                height: size.height - 2 * margin - 2 * topBottomHeight
            ),
            itemCount: 3
        )
        addLayoutContainer(config: rightConfig)

        // Top horizontal layout - trailing alignment
        let topConfig = LayoutConfiguration(
            axis: .horizontal,
            itemSizing: RelativeSizing(baseDimension: .height, aspectRatio: 1.0),
            gapPercentage: 0.8,
            alignment: .trailing,
            zOrder: .ascending,
            rect: CGRect(
                x: margin + sideWidth,
                y: margin,
                width: size.width - 2 * margin - 2 * sideWidth,
                height: topBottomHeight
            ),
            itemCount: 3
        )
        addLayoutContainer(config: topConfig)

        // Bottom horizontal layout - spread evenly
        let bottomConfig = LayoutConfiguration(
            axis: .horizontal,
            itemSizing: RelativeSizing(baseDimension: .height, aspectRatio: 0.8),
            gapPercentage: 2.0,
            alignment: .leading,
            zOrder: .ascending,
            rect: CGRect(
                x: margin + sideWidth,
                y: size.height - margin - topBottomHeight,
                width: size.width - 2 * margin - 2 * sideWidth,
                height: topBottomHeight
            ),
            itemCount: 5
        )
        addLayoutContainer(config: bottomConfig)
    }

    // MARK: - Nested Grids Scenario

    private func setupNestedGrids() {
        backgroundColor = .systemTeal.withAlphaComponent(0.1)

        // Create a parent collection with 3 levels of nesting
        let level1 = createNestedGridCollection(depth: 3, currentLevel: 1, itemsPerGrid: 4)
        level1.layoutFrame = CGRect(x: 0, y: 0, width: size.width - 100, height: size.height - 100)
        level1.position = CGPoint(x: frame.midX, y: frame.midY)
        addChild(level1)
        coordinator.register(collection: level1)
        level1.layoutIfNeeded()
    }

    private func createNestedGridCollection(depth: Int, currentLevel: Int, itemsPerGrid: Int) -> SKCollectionNode {
        let collection = SKCollectionNode(
            layoutBuilder: { _ in StackLayout(axis: .vertical, dataSource: EmptyDataSource()) },
            contentInsets: Insets(uniform: CGFloat(5 * currentLevel))
        )

        let colors: [SKColor] = [.systemBlue, .systemGreen, .systemOrange, .systemPurple]
        collection.debugBorderColor = colors[(currentLevel - 1) % colors.count]
        collection.debugBorderWidth = CGFloat(2 + currentLevel)

        if currentLevel < depth {
            // Add nested collections
            for _ in 0..<itemsPerGrid {
                let nested = createNestedGridCollection(depth: depth, currentLevel: currentLevel + 1, itemsPerGrid: itemsPerGrid)
                collection.addLayoutableChild(nested)
                coordinator.register(collection: nested)
            }
        } else {
            // Leaf level - add shape nodes
            let colors: [SKColor] = [.blue, .green, .orange, .purple, .red, .cyan]
            for i in 0..<itemsPerGrid {
                let node = LayoutableSKShapeNode()
                node.fillColor = colors[i % colors.count]
                node.strokeColor = .black
                node.lineWidth = 1

                let label = SKLabelNode(text: "L\(currentLevel)-\(i)")
                label.fontColor = .white
                label.fontSize = 10
                label.verticalAlignmentMode = .center
                label.horizontalAlignmentMode = .center
                node.addChild(label)

                collection.addLayoutableChild(node)
            }
        }

        // Set grid layout
        let rows = itemsPerGrid == 4 ? 2 : 3
        let columns = itemsPerGrid == 4 ? 2 : 3
        let layout = GridLayout(
            rows: rows,
            columns: columns,
            itemSizing: RelativeSizing(
                baseDimension: .smallest,
                containerPercentage: 0.4,
                aspectRatio: 1.0
            ),
            horizontalGapPercentage: 0.5,
            verticalGapPercentage: 0.5,
            horizontalAlignment: .center,
            verticalAlignment: .center,
            zOrder: .ascending,
            dataSource: collection
        )
        collection.layout = layout

        return collection
    }

    // MARK: - Node Pooling Scenario

    private func setupPoolingDemo() {
        backgroundColor = .systemGreen.withAlphaComponent(0.1)

        let collection = SKCollectionNode(layoutBuilder: { collectionNode in
            GridLayout(
                rows: 15,
                columns: 15,
                itemSizing: RelativeSizing(widthSpec: .containerWidth(percentage: 0.06), heightSpec: .itemWidth(percentage: 1.0)),
                horizontalGapPercentage: 0.01,
                verticalGapPercentage: 0.01,
                horizontalAlignment: .center,
                verticalAlignment: .center,
                zOrder: .ascending,
                dataSource: collectionNode
            )
        })
        collection.nodePool = pool
        collection.layoutFrame = CGRect(x: 0, y: 0, width: size.width - 100, height: size.height - 100)
        collection.position = CGPoint(x: frame.midX, y: frame.midY)
        collection.debugBorderColor = .systemGreen
        collection.debugBorderWidth = 3

        Task {
            let colors: [SKColor] = [.blue, .green, .orange, .purple, .red, .cyan, .yellow, .magenta]
            for i in 0..<100 {
                let node = await collection.dequeueReusableNode(withIdentifier: "LayoutableSKShapeNode") {
                    LayoutableSKShapeNode()
                }
                node.fillColor = colors[i % colors.count]
                node.strokeColor = .black
                node.lineWidth = 1

                let label = SKLabelNode(text: "\(i)")
                label.fontColor = .white
                label.fontSize = 8
                label.verticalAlignmentMode = .center
                label.horizontalAlignmentMode = .center
                node.addChild(label)

                collection.addLayoutableChild(node)
            }
            collection.forceLayout()
        }

        addChild(collection)
        coordinator.register(collection: collection)
    }

    // MARK: - Circular and Stack Scenario

    private func setupCircularAndStack() {
        backgroundColor = .systemPurple.withAlphaComponent(0.1)

        // Create circular layout in center
        let circular = SKCollectionNode(layoutBuilder: { collectionNode in
            CircularLayout(
                itemSizing: RelativeSizing(baseDimension: .width, containerPercentage: 0.12, aspectRatio: 1.0),
                startAnglePercentage: 0.0,
                radiusGapPercentage: 1.0,
                zOrder: .ascending,
                dataSource: collectionNode
            )
        })
        circular.layoutFrame = CGRect(x: 0, y: 0, width: 600, height: 600)
        circular.position = CGPoint(x: frame.midX, y: frame.midY)
        circular.debugBorderColor = .systemPurple
        circular.debugBorderWidth = 2

        let colors: [SKColor] = [.blue, .green, .orange, .purple, .red, .cyan, .yellow, .magenta, .brown, .systemPink]
        for i in 0..<12 {
            let node = LayoutableSKShapeNode()
            node.fillColor = colors[i % colors.count]
            node.strokeColor = .black
            node.lineWidth = 2

            let label = SKLabelNode(text: "\(i)")
            label.fontColor = .white
            label.fontSize = 14
            label.verticalAlignmentMode = .center
            label.horizontalAlignmentMode = .center
            node.addChild(label)

            circular.addLayoutableChild(node)
        }

        addChild(circular)
        coordinator.register(collection: circular)
        circular.layoutIfNeeded()
    }

    // MARK: - Drag and Drop Scenario

    private func setupDragAndDrop() {
        backgroundColor = .systemOrange.withAlphaComponent(0.1)

        // Create 3 collections side by side for drag and drop testing
        let collectionWidth = (size.width - 80) / 3
        let collectionHeight = size.height - 100

        for i in 0..<3 {
            let collection = SKCollectionNode(layoutBuilder: { collectionNode in
                StackLayout(
                    axis: .vertical,
                    itemSizing: RelativeSizing(
                        widthSpec: .containerWidth(percentage: 0.8),
                        heightSpec: .containerHeight(percentage: 0.15)
                    ),
                    gapPercentage: 0.2,
                    alignment: .center,
                    zOrder: .ascending,
                    dataSource: collectionNode
                )
            })

            collection.layoutFrame = CGRect(x: 0, y: 0, width: collectionWidth, height: collectionHeight)
            collection.position = CGPoint(
                x: 20 + collectionWidth / 2 + CGFloat(i) * (collectionWidth + 20),
                y: frame.midY
            )

            let borderColors: [SKColor] = [.systemRed, .systemBlue, .systemGreen]
            collection.debugBorderColor = borderColors[i]
            collection.debugBorderWidth = 3

            // Add some initial items (more in first collection)
            let itemCount = i == 0 ? 6 : 2
            let colors: [SKColor] = [.red, .blue, .green, .orange, .purple, .cyan]
            for j in 0..<itemCount {
                let node = LayoutableSKShapeNode()
                node.fillColor = colors[j % colors.count]
                node.strokeColor = .black
                node.lineWidth = 2

                let label = SKLabelNode(text: "Item \(i)-\(j)")
                label.fontColor = .white
                label.fontSize = 12
                label.verticalAlignmentMode = .center
                label.horizontalAlignmentMode = .center
                node.addChild(label)

                collection.addLayoutableChild(node)
            }

            addChild(collection)
            coordinator.register(collection: collection)
            collection.layoutIfNeeded()
        }
    }

    // MARK: - Overview Helper Methods (from GameScene)

    private func setupCenterGridLayout(rect: CGRect) {
        let collection = SKCollectionNode(
            layoutBuilder: { _ in StackLayout(axis: .vertical, dataSource: EmptyDataSource()) },
            contentInsets: Insets(uniform: 10)
        )

        collection.layoutFrame = CGRect(x: 0, y: 0, width: rect.width, height: rect.height)

        let spriteKitY = size.height - rect.maxY
        collection.position = CGPoint(
            x: rect.midX,
            y: spriteKitY + rect.height / 2
        )

        addChild(collection)
        centerCollection = collection
        coordinator.register(collection: collection)

        // Create 4 child collections for the grid
        let diagonal = createDiagonalCollection()
        collection.addLayoutableChild(diagonal)
        diagonalCollection = diagonal
        coordinator.register(collection: diagonal)

        let nested = createNestedTestCollection()
        collection.addLayoutableChild(nested)
        nestedCollection = nested

        let circular = createCircularCollection()
        collection.addLayoutableChild(circular)
        circularCollection = circular
        coordinator.register(collection: circular)

        let dynamicGrid = createDynamicGridCollection()
        collection.addLayoutableChild(dynamicGrid)
        dynamicGridCollection = dynamicGrid
        coordinator.register(collection: dynamicGrid)

        // Set parent's layout to a 2x2 grid
        let gridLayout = GridLayout(
            rows: 2,
            columns: 2,
            itemSizing: RelativeSizing(
                baseDimension: .smallest,
                containerPercentage: 0.5,
                aspectRatio: 1.0
            ),
            horizontalGapPercentage: 1.0,
            verticalGapPercentage: 1,
            horizontalAlignment: .center,
            verticalAlignment: .center,
            zOrder: .ascending,
            dataSource: collection
        )
        collection.layout = gridLayout

        centerGridConfig = CenterGridConfiguration(
            rows: 2,
            columns: 2,
            itemSizing: RelativeSizing(
                baseDimension: .smallest,
                containerPercentage: 0.5,
                aspectRatio: 1.0
            ),
            rect: rect,
            horizontalGapPercentage: 1.0,
            verticalGapPercentage: 1.0,
            horizontalAlignment: .center,
            verticalAlignment: .center,
            zOrder: .ascending
        )

        collection.layoutIfNeeded()
    }

    private func createDiagonalCollection() -> SKCollectionNode {
        let collectionNode = SKCollectionNode(
            layoutBuilder: { _ in StackLayout(axis: .vertical, dataSource: EmptyDataSource()) },
            contentInsets: Insets(uniform: 5)
        )

        collectionNode.debugBorderColor = SKColor.purple
        collectionNode.debugBorderWidth = 2

        diagonalConfig = DiagonalConfiguration(
            itemSizing: RelativeSizing(baseDimension: .width, containerPercentage: 0.15, aspectRatio: 1.0),
            horizontalGapPercentage: 0.1,
            verticalGapPercentage: 0.1,
            horizontalAlignment: .center,
            verticalAlignment: .center,
            zOrder: .ascending,
            rect: .zero,
            itemCount: 6
        )

        let layout = DiagonalLayout(
            itemSizing: diagonalConfig!.itemSizing,
            horizontalGapPercentage: diagonalConfig!.horizontalGapPercentage,
            verticalGapPercentage: diagonalConfig!.verticalGapPercentage,
            horizontalAlignment: diagonalConfig!.horizontalAlignment,
            verticalAlignment: diagonalConfig!.verticalAlignment,
            zOrder: diagonalConfig!.zOrder,
            dataSource: collectionNode
        )
        collectionNode.layout = layout

        let colors: [SKColor] = [.blue, .green, .orange, .purple, .red, .cyan]
        for i in 0..<6 {
            let node = LayoutableSKShapeNode()
            node.fillColor = colors[i]
            node.strokeColor = .black
            node.lineWidth = 1

            let label = SKLabelNode(text: "D\(i)")
            label.fontColor = .white
            label.fontSize = 10
            label.verticalAlignmentMode = .center
            label.horizontalAlignmentMode = .center
            node.addChild(label)

            collectionNode.addLayoutableChild(node)
        }

        return collectionNode
    }

    private func createCircularCollection() -> SKCollectionNode {
        let collectionNode = SKCollectionNode(
            layoutBuilder: { _ in StackLayout(axis: .vertical, dataSource: EmptyDataSource()) },
            contentInsets: Insets(uniform: 5)
        )

        collectionNode.debugBorderColor = .systemTeal
        collectionNode.debugBorderWidth = 2

        circularConfig = CircularConfiguration(
            itemSizing: RelativeSizing(baseDimension: .width, containerPercentage: 0.2, aspectRatio: 1.0),
            rect: .zero,
            itemCount: 8,
            startAnglePercentage: 0.0,
            radiusGapPercentage: 1.0,
            zOrder: .ascending
        )

        let layout = CircularLayout(
            itemSizing: circularConfig!.itemSizing,
            startAnglePercentage: circularConfig!.startAnglePercentage,
            radiusGapPercentage: circularConfig!.radiusGapPercentage,
            zOrder: circularConfig!.zOrder,
            dataSource: collectionNode
        )
        collectionNode.layout = layout

        let colors: [SKColor] = [.blue, .green, .orange, .purple, .red, .cyan, .yellow, .magenta]
        for i in 0..<8 {
            let node = LayoutableSKShapeNode()
            node.fillColor = colors[i]
            node.strokeColor = .black
            node.lineWidth = 1

            let label = SKLabelNode(text: "C\(i)")
            label.fontColor = .white
            label.fontSize = 10
            label.verticalAlignmentMode = .center
            label.horizontalAlignmentMode = .center
            node.addChild(label)

            collectionNode.addLayoutableChild(node)
        }

        return collectionNode
    }

    private func createDynamicGridCollection() -> SKCollectionNode {
        let collectionNode = SKCollectionNode(
            layoutBuilder: { _ in StackLayout(axis: .vertical, dataSource: EmptyDataSource()) },
            contentInsets: Insets(uniform: 5)
        )

        collectionNode.debugBorderColor = .systemGreen
        collectionNode.debugBorderWidth = 2

        gridConfig = GridConfiguration(
            itemSizing: RelativeSizing(baseDimension: .width, containerPercentage: 0.15, aspectRatio: 1.0),
            rect: .zero,
            itemCount: 12,
            horizontalGapPercentage: 1.0,
            verticalGapPercentage: 1.0,
            horizontalAlignment: .center,
            verticalAlignment: .center,
            zOrder: .ascending
        )

        let layout = DynamicGridLayout(
            itemSizing: gridConfig!.itemSizing,
            horizontalGapPercentage: gridConfig!.horizontalGapPercentage,
            verticalGapPercentage: gridConfig!.verticalGapPercentage,
            horizontalAlignment: gridConfig!.horizontalAlignment,
            verticalAlignment: gridConfig!.verticalAlignment,
            zOrder: gridConfig!.zOrder,
            dataSource: collectionNode
        )
        collectionNode.layout = layout

        let colors: [SKColor] = [.blue, .green, .orange, .purple, .red, .cyan, .yellow, .magenta]
        for i in 0..<12 {
            let node = LayoutableSKShapeNode()
            node.fillColor = colors[i % colors.count]
            node.strokeColor = .black
            node.lineWidth = 1

            let label = SKLabelNode(text: "G\(i)")
            label.fontColor = .white
            label.fontSize = 10
            label.verticalAlignmentMode = .center
            label.horizontalAlignmentMode = .center
            node.addChild(label)

            collectionNode.addLayoutableChild(node)
        }

        return collectionNode
    }

    private func createNestedTestCollection() -> SKCollectionNode {
        let parentCollection = SKCollectionNode(
            layoutBuilder: { _ in StackLayout(axis: .vertical, dataSource: EmptyDataSource()) },
            contentInsets: Insets(uniform: 5)
        )

        parentCollection.debugBorderColor = .black
        parentCollection.debugBorderWidth = 2

        for i in 0..<4 {
            let childCollection = SKCollectionNode(
                layoutBuilder: { _ in StackLayout(axis: .vertical, dataSource: EmptyDataSource()) },
                contentInsets: Insets(uniform: 2)
            )

            let colors: [SKColor] = [.blue, .green, .orange]
            for j in 0..<3 {
                let node = LayoutableSKShapeNode()
                node.fillColor = colors[j]
                node.strokeColor = .black
                node.lineWidth = 1

                let label = SKLabelNode(text: "\(i)-\(j)")
                label.fontColor = .white
                label.fontSize = 12
                label.verticalAlignmentMode = .center
                label.horizontalAlignmentMode = .center
                node.addChild(label)

                childCollection.addLayoutableChild(node)
            }

            let childLayout = DiagonalLayout(
                itemSizing: RelativeSizing(
                    baseDimension: .height,
                    containerPercentage: 0.5,
                    aspectRatio: 1.0
                ),
                horizontalGapPercentage: 0.5,
                verticalGapPercentage: 0.5,
                horizontalAlignment: .center,
                verticalAlignment: .center,
                zOrder: .ascending,
                dataSource: childCollection
            )
            childCollection.layout = childLayout

            parentCollection.addLayoutableChild(childCollection)
            coordinator.register(collection: childCollection)
        }

        let parentLayout = GridLayout(
            rows: 2,
            columns: 2,
            itemSizing: RelativeSizing(
                baseDimension: .height,
                containerPercentage: 0.4,
                aspectRatio: 1.0
            ),
            horizontalGapPercentage: 1.0,
            verticalGapPercentage: 1.0,
            horizontalAlignment: .center,
            verticalAlignment: .center,
            zOrder: .ascending,
            dataSource: parentCollection
        )
        parentCollection.layout = parentLayout
        parentCollection.layoutIfNeeded()

        return parentCollection
    }

    private func addLayoutContainer(config: LayoutConfiguration) {
        let containerIndex = layoutContainers.count

        let spriteKitRect = CGRect(
            x: config.rect.minX,
            y: size.height - config.rect.maxY,
            width: config.rect.width,
            height: config.rect.height
        )

        let containerFrame = SKShapeNode(rect: spriteKitRect)
        containerFrame.strokeColor = .red
        containerFrame.lineWidth = 2
        containerFrame.fillColor = .clear
        containerFrame.name = "container_\(containerIndex)"
        addChild(containerFrame)

        let collectionNode = SKCollectionNode(
            layoutBuilder: { _ in StackLayout(axis: .vertical, dataSource: EmptyDataSource()) },
            contentInsets: Insets(uniform: 5)
        )

        let layout = StackLayout(
            axis: config.axis,
            itemSizing: config.itemSizing,
            gapPercentage: config.gapPercentage,
            alignment: config.alignment,
            zOrder: config.zOrder,
            dataSource: collectionNode
        )

        collectionNode.layout = layout

        collectionNode.position = CGPoint(
            x: spriteKitRect.midX,
            y: spriteKitRect.midY
        )

        collectionNode.layoutFrame = CGRect(
            x: 0,
            y: 0,
            width: config.rect.width,
            height: config.rect.height
        )

        addChild(collectionNode)
        coordinator.register(collection: collectionNode)

        let colors: [SKColor] = [.blue, .green, .orange, .purple, .red, .cyan, .yellow, .magenta]

        for i in 0..<config.itemCount {
            let node = LayoutableSKShapeNode()
            node.fillColor = colors[i % colors.count]
            node.strokeColor = .black
            node.lineWidth = 1

            let label = SKLabelNode(text: "\(i)")
            label.fontColor = .white
            label.fontSize = 10
            label.verticalAlignmentMode = .center
            label.horizontalAlignmentMode = .center
            node.addChild(label)

            collectionNode.addLayoutableChild(node)
        }

        collectionNode.layoutIfNeeded()
        layoutContainers.append((config, collectionNode, containerFrame))
    }

    // MARK: - Update Methods for Context Menus

    // Stack layout updates
    private func updateStackAlignment(at index: Int, newAlignment: Alignment) {
        guard index < layoutContainers.count else { return }
        var config = layoutContainers[index].config
        config.alignment = newAlignment
        layoutContainers[index].config = config

        let collection = layoutContainers[index].collectionNode
        let newLayout = StackLayout(
            axis: config.axis,
            itemSizing: config.itemSizing,
            gapPercentage: config.gapPercentage,
            alignment: config.alignment,
            zOrder: config.zOrder,
            dataSource: collection
        )
        collection.layout = newLayout
        collection.layoutIfNeeded()
    }

    private func updateStackGap(at index: Int, newGap: CGFloat) {
        guard index < layoutContainers.count else { return }
        var config = layoutContainers[index].config
        config.gapPercentage = newGap
        layoutContainers[index].config = config

        let collection = layoutContainers[index].collectionNode
        let newLayout = StackLayout(
            axis: config.axis,
            itemSizing: config.itemSizing,
            gapPercentage: config.gapPercentage,
            alignment: config.alignment,
            zOrder: config.zOrder,
            dataSource: collection
        )
        collection.layout = newLayout
        collection.layoutIfNeeded()
    }

    private func updateStackZOrder(at index: Int, newZOrder: ZOrder) {
        guard index < layoutContainers.count else { return }
        var config = layoutContainers[index].config
        config.zOrder = newZOrder
        layoutContainers[index].config = config

        let collection = layoutContainers[index].collectionNode
        let newLayout = StackLayout(
            axis: config.axis,
            itemSizing: config.itemSizing,
            gapPercentage: config.gapPercentage,
            alignment: config.alignment,
            zOrder: config.zOrder,
            dataSource: collection
        )
        collection.layout = newLayout
        collection.layoutIfNeeded()
    }

    private func updateStackItemCount(at index: Int, newCount: Int) {
        guard index < layoutContainers.count else { return }
        var config = layoutContainers[index].config
        let collection = layoutContainers[index].collectionNode

        let currentCount = config.itemCount
        config.itemCount = newCount
        layoutContainers[index].config = config

        let colors: [SKColor] = [.blue, .green, .orange, .purple, .red, .cyan, .yellow, .magenta]

        if newCount > currentCount {
            for i in currentCount..<newCount {
                let node = LayoutableSKShapeNode()
                node.fillColor = colors[i % colors.count]
                node.strokeColor = .black
                node.lineWidth = 1

                let label = SKLabelNode(text: "\(i)")
                label.fontColor = .white
                label.fontSize = 10
                label.verticalAlignmentMode = .center
                label.horizontalAlignmentMode = .center
                node.addChild(label)

                collection.addLayoutableChild(node)
            }
        } else if newCount < currentCount {
            while collection.layoutableChildren.count > newCount {
                if let last = collection.layoutableChildren.last {
                    collection.removeLayoutableChild(last)
                }
            }
        }

        collection.layoutIfNeeded()
    }

    private func updateStackItemSizing(at index: Int, newSizing: RelativeSizing) {
        guard index < layoutContainers.count else { return }
        var config = layoutContainers[index].config
        config.itemSizing = newSizing
        layoutContainers[index].config = config

        let collection = layoutContainers[index].collectionNode
        let newLayout = StackLayout(
            axis: config.axis,
            itemSizing: config.itemSizing,
            gapPercentage: config.gapPercentage,
            alignment: config.alignment,
            zOrder: config.zOrder,
            dataSource: collection
        )
        collection.layout = newLayout
        collection.layoutIfNeeded()
    }

    // Diagonal layout updates
    private func updateDiagonalHorizontalAlignment(_ newAlignment: Alignment) {
        guard let collection = diagonalCollection, var config = diagonalConfig else { return }
        config.horizontalAlignment = newAlignment
        diagonalConfig = config

        let layout = DiagonalLayout(
            itemSizing: config.itemSizing,
            horizontalGapPercentage: config.horizontalGapPercentage,
            verticalGapPercentage: config.verticalGapPercentage,
            horizontalAlignment: config.horizontalAlignment,
            verticalAlignment: config.verticalAlignment,
            zOrder: config.zOrder,
            dataSource: collection
        )
        collection.layout = layout
        collection.layoutIfNeeded()
    }

    private func updateDiagonalVerticalAlignment(_ newAlignment: Alignment) {
        guard let collection = diagonalCollection, var config = diagonalConfig else { return }
        config.verticalAlignment = newAlignment
        diagonalConfig = config

        let layout = DiagonalLayout(
            itemSizing: config.itemSizing,
            horizontalGapPercentage: config.horizontalGapPercentage,
            verticalGapPercentage: config.verticalGapPercentage,
            horizontalAlignment: config.horizontalAlignment,
            verticalAlignment: config.verticalAlignment,
            zOrder: config.zOrder,
            dataSource: collection
        )
        collection.layout = layout
        collection.layoutIfNeeded()
    }

    private func updateDiagonalHorizontalGap(_ newGap: CGFloat) {
        guard let collection = diagonalCollection, var config = diagonalConfig else { return }
        config.horizontalGapPercentage = newGap
        diagonalConfig = config

        let layout = DiagonalLayout(
            itemSizing: config.itemSizing,
            horizontalGapPercentage: config.horizontalGapPercentage,
            verticalGapPercentage: config.verticalGapPercentage,
            horizontalAlignment: config.horizontalAlignment,
            verticalAlignment: config.verticalAlignment,
            zOrder: config.zOrder,
            dataSource: collection
        )
        collection.layout = layout
        collection.layoutIfNeeded()
    }

    private func updateDiagonalVerticalGap(_ newGap: CGFloat) {
        guard let collection = diagonalCollection, var config = diagonalConfig else { return }
        config.verticalGapPercentage = newGap
        diagonalConfig = config

        let layout = DiagonalLayout(
            itemSizing: config.itemSizing,
            horizontalGapPercentage: config.horizontalGapPercentage,
            verticalGapPercentage: config.verticalGapPercentage,
            horizontalAlignment: config.horizontalAlignment,
            verticalAlignment: config.verticalAlignment,
            zOrder: config.zOrder,
            dataSource: collection
        )
        collection.layout = layout
        collection.layoutIfNeeded()
    }

    private func updateDiagonalZOrder(_ newZOrder: ZOrder) {
        guard let collection = diagonalCollection, var config = diagonalConfig else { return }
        config.zOrder = newZOrder
        diagonalConfig = config

        let layout = DiagonalLayout(
            itemSizing: config.itemSizing,
            horizontalGapPercentage: config.horizontalGapPercentage,
            verticalGapPercentage: config.verticalGapPercentage,
            horizontalAlignment: config.horizontalAlignment,
            verticalAlignment: config.verticalAlignment,
            zOrder: config.zOrder,
            dataSource: collection
        )
        collection.layout = layout
        collection.layoutIfNeeded()
    }

    private func updateDiagonalItemCount(_ newCount: Int) {
        guard let collection = diagonalCollection, var config = diagonalConfig else { return }
        let currentCount = config.itemCount
        config.itemCount = newCount
        diagonalConfig = config

        let colors: [SKColor] = [.blue, .green, .orange, .purple, .red, .cyan]

        if newCount > currentCount {
            for i in currentCount..<newCount {
                let node = LayoutableSKShapeNode()
                node.fillColor = colors[i % colors.count]
                node.strokeColor = .black
                node.lineWidth = 1

                let label = SKLabelNode(text: "D\(i)")
                label.fontColor = .white
                label.fontSize = 10
                label.verticalAlignmentMode = .center
                label.horizontalAlignmentMode = .center
                node.addChild(label)

                collection.addLayoutableChild(node)
            }
        } else if newCount < currentCount {
            while collection.layoutableChildren.count > newCount {
                if let last = collection.layoutableChildren.last {
                    collection.removeLayoutableChild(last)
                }
            }
        }

        collection.layoutIfNeeded()
    }

    private func updateDiagonalItemSizing(_ newSizing: RelativeSizing) {
        guard let collection = diagonalCollection, var config = diagonalConfig else { return }
        config.itemSizing = newSizing
        diagonalConfig = config

        let layout = DiagonalLayout(
            itemSizing: config.itemSizing,
            horizontalGapPercentage: config.horizontalGapPercentage,
            verticalGapPercentage: config.verticalGapPercentage,
            horizontalAlignment: config.horizontalAlignment,
            verticalAlignment: config.verticalAlignment,
            zOrder: config.zOrder,
            dataSource: collection
        )
        collection.layout = layout
        collection.layoutIfNeeded()
    }

    // Circular layout updates
    private func updateCircularItemCount(_ newCount: Int) {
        guard let collection = circularCollection, var config = circularConfig else { return }
        let currentCount = config.itemCount
        config.itemCount = newCount
        circularConfig = config

        let colors: [SKColor] = [.blue, .green, .orange, .purple, .red, .cyan, .yellow, .magenta]

        if newCount > currentCount {
            for i in currentCount..<newCount {
                let node = LayoutableSKShapeNode()
                node.fillColor = colors[i % colors.count]
                node.strokeColor = .black
                node.lineWidth = 1

                let label = SKLabelNode(text: "C\(i)")
                label.fontColor = .white
                label.fontSize = 10
                label.verticalAlignmentMode = .center
                label.horizontalAlignmentMode = .center
                node.addChild(label)

                collection.addLayoutableChild(node)
            }
        } else if newCount < currentCount {
            while collection.layoutableChildren.count > newCount {
                if let last = collection.layoutableChildren.last {
                    collection.removeLayoutableChild(last)
                }
            }
        }

        collection.layoutIfNeeded()
    }

    private func updateCircularStartAngle(_ newAngle: CGFloat) {
        guard let collection = circularCollection, var config = circularConfig else { return }
        config.startAnglePercentage = newAngle
        circularConfig = config

        let layout = CircularLayout(
            itemSizing: config.itemSizing,
            startAnglePercentage: config.startAnglePercentage,
            radiusGapPercentage: config.radiusGapPercentage,
            zOrder: config.zOrder,
            dataSource: collection
        )
        collection.layout = layout
        collection.layoutIfNeeded()
    }

    private func updateCircularRadiusGap(_ newGap: CGFloat) {
        guard let collection = circularCollection, var config = circularConfig else { return }
        config.radiusGapPercentage = newGap
        circularConfig = config

        let layout = CircularLayout(
            itemSizing: config.itemSizing,
            startAnglePercentage: config.startAnglePercentage,
            radiusGapPercentage: config.radiusGapPercentage,
            zOrder: config.zOrder,
            dataSource: collection
        )
        collection.layout = layout
        collection.layoutIfNeeded()
    }

    private func updateCircularItemSizing(_ newSizing: RelativeSizing) {
        guard let collection = circularCollection, var config = circularConfig else { return }
        config.itemSizing = newSizing
        circularConfig = config

        let layout = CircularLayout(
            itemSizing: config.itemSizing,
            startAnglePercentage: config.startAnglePercentage,
            radiusGapPercentage: config.radiusGapPercentage,
            zOrder: config.zOrder,
            dataSource: collection
        )
        collection.layout = layout
        collection.layoutIfNeeded()
    }

    private func updateCircularZOrder(_ newZOrder: ZOrder) {
        guard let collection = circularCollection, var config = circularConfig else { return }
        config.zOrder = newZOrder
        circularConfig = config

        let layout = CircularLayout(
            itemSizing: config.itemSizing,
            startAnglePercentage: config.startAnglePercentage,
            radiusGapPercentage: config.radiusGapPercentage,
            zOrder: config.zOrder,
            dataSource: collection
        )
        collection.layout = layout
        collection.layoutIfNeeded()
    }

    // Grid layout updates
    private func updateGridHorizontalAlignment(_ newAlignment: Alignment) {
        guard let collection = dynamicGridCollection, var config = gridConfig else { return }
        config.horizontalAlignment = newAlignment
        gridConfig = config

        let layout = DynamicGridLayout(
            itemSizing: config.itemSizing,
            horizontalGapPercentage: config.horizontalGapPercentage,
            verticalGapPercentage: config.verticalGapPercentage,
            horizontalAlignment: config.horizontalAlignment,
            verticalAlignment: config.verticalAlignment,
            zOrder: config.zOrder,
            dataSource: collection
        )
        collection.layout = layout
        collection.layoutIfNeeded()
    }

    private func updateGridVerticalAlignment(_ newAlignment: Alignment) {
        guard let collection = dynamicGridCollection, var config = gridConfig else { return }
        config.verticalAlignment = newAlignment
        gridConfig = config

        let layout = DynamicGridLayout(
            itemSizing: config.itemSizing,
            horizontalGapPercentage: config.horizontalGapPercentage,
            verticalGapPercentage: config.verticalGapPercentage,
            horizontalAlignment: config.horizontalAlignment,
            verticalAlignment: config.verticalAlignment,
            zOrder: config.zOrder,
            dataSource: collection
        )
        collection.layout = layout
        collection.layoutIfNeeded()
    }

    private func updateGridHorizontalGap(_ newGap: CGFloat) {
        guard let collection = dynamicGridCollection, var config = gridConfig else { return }
        config.horizontalGapPercentage = newGap
        gridConfig = config

        let layout = DynamicGridLayout(
            itemSizing: config.itemSizing,
            horizontalGapPercentage: config.horizontalGapPercentage,
            verticalGapPercentage: config.verticalGapPercentage,
            horizontalAlignment: config.horizontalAlignment,
            verticalAlignment: config.verticalAlignment,
            zOrder: config.zOrder,
            dataSource: collection
        )
        collection.layout = layout
        collection.layoutIfNeeded()
    }

    private func updateGridVerticalGap(_ newGap: CGFloat) {
        guard let collection = dynamicGridCollection, var config = gridConfig else { return }
        config.verticalGapPercentage = newGap
        gridConfig = config

        let layout = DynamicGridLayout(
            itemSizing: config.itemSizing,
            horizontalGapPercentage: config.horizontalGapPercentage,
            verticalGapPercentage: config.verticalGapPercentage,
            horizontalAlignment: config.horizontalAlignment,
            verticalAlignment: config.verticalAlignment,
            zOrder: config.zOrder,
            dataSource: collection
        )
        collection.layout = layout
        collection.layoutIfNeeded()
    }

    private func updateGridZOrder(_ newZOrder: ZOrder) {
        guard let collection = dynamicGridCollection, var config = gridConfig else { return }
        config.zOrder = newZOrder
        gridConfig = config

        let layout = DynamicGridLayout(
            itemSizing: config.itemSizing,
            horizontalGapPercentage: config.horizontalGapPercentage,
            verticalGapPercentage: config.verticalGapPercentage,
            horizontalAlignment: config.horizontalAlignment,
            verticalAlignment: config.verticalAlignment,
            zOrder: config.zOrder,
            dataSource: collection
        )
        collection.layout = layout
        collection.layoutIfNeeded()
    }

    private func updateGridItemCount(_ newCount: Int) {
        guard let collection = dynamicGridCollection, var config = gridConfig else { return }
        let currentCount = config.itemCount
        config.itemCount = newCount
        gridConfig = config

        let colors: [SKColor] = [.blue, .green, .orange, .purple, .red, .cyan, .yellow, .magenta]

        if newCount > currentCount {
            for i in currentCount..<newCount {
                let node = LayoutableSKShapeNode()
                node.fillColor = colors[i % colors.count]
                node.strokeColor = .black
                node.lineWidth = 1

                let label = SKLabelNode(text: "G\(i)")
                label.fontColor = .white
                label.fontSize = 10
                label.verticalAlignmentMode = .center
                label.horizontalAlignmentMode = .center
                node.addChild(label)

                collection.addLayoutableChild(node)
            }
        } else if newCount < currentCount {
            while collection.layoutableChildren.count > newCount {
                if let last = collection.layoutableChildren.last {
                    collection.removeLayoutableChild(last)
                }
            }
        }

        collection.layoutIfNeeded()
    }

    private func updateGridItemSizing(_ newSizing: RelativeSizing) {
        guard let collection = dynamicGridCollection, var config = gridConfig else { return }
        config.itemSizing = newSizing
        gridConfig = config

        let layout = DynamicGridLayout(
            itemSizing: config.itemSizing,
            horizontalGapPercentage: config.horizontalGapPercentage,
            verticalGapPercentage: config.verticalGapPercentage,
            horizontalAlignment: config.horizontalAlignment,
            verticalAlignment: config.verticalAlignment,
            zOrder: config.zOrder,
            dataSource: collection
        )
        collection.layout = layout
        collection.layoutIfNeeded()
    }

    // Center grid layout updates
    private func updateCenterGridRows(_ newRows: Int) {
        guard let collection = centerCollection, var config = centerGridConfig else { return }
        config.rows = newRows
        centerGridConfig = config

        let layout = GridLayout(
            rows: config.rows,
            columns: config.columns,
            itemSizing: config.itemSizing,
            horizontalGapPercentage: config.horizontalGapPercentage,
            verticalGapPercentage: config.verticalGapPercentage,
            horizontalAlignment: config.horizontalAlignment,
            verticalAlignment: config.verticalAlignment,
            zOrder: config.zOrder,
            dataSource: collection
        )
        collection.layout = layout
        collection.layoutIfNeeded()
    }

    private func updateCenterGridColumns(_ newColumns: Int) {
        guard let collection = centerCollection, var config = centerGridConfig else { return }
        config.columns = newColumns
        centerGridConfig = config

        let layout = GridLayout(
            rows: config.rows,
            columns: config.columns,
            itemSizing: config.itemSizing,
            horizontalGapPercentage: config.horizontalGapPercentage,
            verticalGapPercentage: config.verticalGapPercentage,
            horizontalAlignment: config.horizontalAlignment,
            verticalAlignment: config.verticalAlignment,
            zOrder: config.zOrder,
            dataSource: collection
        )
        collection.layout = layout
        collection.layoutIfNeeded()
    }

    private func updateCenterGridHorizontalAlignment(_ newAlignment: Alignment) {
        guard let collection = centerCollection, var config = centerGridConfig else { return }
        config.horizontalAlignment = newAlignment
        centerGridConfig = config

        let layout = GridLayout(
            rows: config.rows,
            columns: config.columns,
            itemSizing: config.itemSizing,
            horizontalGapPercentage: config.horizontalGapPercentage,
            verticalGapPercentage: config.verticalGapPercentage,
            horizontalAlignment: config.horizontalAlignment,
            verticalAlignment: config.verticalAlignment,
            zOrder: config.zOrder,
            dataSource: collection
        )
        collection.layout = layout
        collection.layoutIfNeeded()
    }

    private func updateCenterGridVerticalAlignment(_ newAlignment: Alignment) {
        guard let collection = centerCollection, var config = centerGridConfig else { return }
        config.verticalAlignment = newAlignment
        centerGridConfig = config

        let layout = GridLayout(
            rows: config.rows,
            columns: config.columns,
            itemSizing: config.itemSizing,
            horizontalGapPercentage: config.horizontalGapPercentage,
            verticalGapPercentage: config.verticalGapPercentage,
            horizontalAlignment: config.horizontalAlignment,
            verticalAlignment: config.verticalAlignment,
            zOrder: config.zOrder,
            dataSource: collection
        )
        collection.layout = layout
        collection.layoutIfNeeded()
    }

    private func updateCenterGridHorizontalGap(_ newGap: CGFloat) {
        guard let collection = centerCollection, var config = centerGridConfig else { return }
        config.horizontalGapPercentage = newGap
        centerGridConfig = config

        let layout = GridLayout(
            rows: config.rows,
            columns: config.columns,
            itemSizing: config.itemSizing,
            horizontalGapPercentage: config.horizontalGapPercentage,
            verticalGapPercentage: config.verticalGapPercentage,
            horizontalAlignment: config.horizontalAlignment,
            verticalAlignment: config.verticalAlignment,
            zOrder: config.zOrder,
            dataSource: collection
        )
        collection.layout = layout
        collection.layoutIfNeeded()
    }

    private func updateCenterGridVerticalGap(_ newGap: CGFloat) {
        guard let collection = centerCollection, var config = centerGridConfig else { return }
        config.verticalGapPercentage = newGap
        centerGridConfig = config

        let layout = GridLayout(
            rows: config.rows,
            columns: config.columns,
            itemSizing: config.itemSizing,
            horizontalGapPercentage: config.horizontalGapPercentage,
            verticalGapPercentage: config.verticalGapPercentage,
            horizontalAlignment: config.horizontalAlignment,
            verticalAlignment: config.verticalAlignment,
            zOrder: config.zOrder,
            dataSource: collection
        )
        collection.layout = layout
        collection.layoutIfNeeded()
    }

    private func updateCenterGridZOrder(_ newZOrder: ZOrder) {
        guard let collection = centerCollection, var config = centerGridConfig else { return }
        config.zOrder = newZOrder
        centerGridConfig = config

        let layout = GridLayout(
            rows: config.rows,
            columns: config.columns,
            itemSizing: config.itemSizing,
            horizontalGapPercentage: config.horizontalGapPercentage,
            verticalGapPercentage: config.verticalGapPercentage,
            horizontalAlignment: config.horizontalAlignment,
            verticalAlignment: config.verticalAlignment,
            zOrder: config.zOrder,
            dataSource: collection
        )
        collection.layout = layout
        collection.layoutIfNeeded()
    }

    private func updateCenterGridItemSizing(_ newSizing: RelativeSizing) {
        guard let collection = centerCollection, var config = centerGridConfig else { return }
        config.itemSizing = newSizing
        centerGridConfig = config

        let layout = GridLayout(
            rows: config.rows,
            columns: config.columns,
            itemSizing: config.itemSizing,
            horizontalGapPercentage: config.horizontalGapPercentage,
            verticalGapPercentage: config.verticalGapPercentage,
            horizontalAlignment: config.horizontalAlignment,
            verticalAlignment: config.verticalAlignment,
            zOrder: config.zOrder,
            dataSource: collection
        )
        collection.layout = layout
        collection.layoutIfNeeded()
    }

    // MARK: - Event Forwarding

    #if os(macOS) // pointer/right-click input — iOS touch handling is a later step
    public override func rightMouseDown(with event: NSEvent) {
        let location = event.location(in: self)

        // Check nested collections first (they're inside center collection)
        // Check diagonal collection
        if let diagonal = diagonalCollection,
           let centerParent = diagonal.parent {
            let pointInCenter = convert(location, to: centerParent)
            let pointInDiagonal = centerParent.convert(pointInCenter, to: diagonal)

            let bounds = CGRect(
                x: -diagonal.layoutFrame.width / 2,
                y: -diagonal.layoutFrame.height / 2,
                width: diagonal.layoutFrame.width,
                height: diagonal.layoutFrame.height
            )

            if bounds.contains(pointInDiagonal) {
                if let config = diagonalConfig {
                    DispatchQueue.main.async { [weak self] in
                        self?.contextMenuState?.diagonalConfig = config
                        self?.contextMenuState?.showDiagonalMenu = true
                    }
                }
                return
            }
        }

        // Check circular collection
        if let circular = circularCollection,
           let centerParent = circular.parent {
            let pointInCenter = convert(location, to: centerParent)
            let pointInCircular = centerParent.convert(pointInCenter, to: circular)

            let bounds = CGRect(
                x: -circular.layoutFrame.width / 2,
                y: -circular.layoutFrame.height / 2,
                width: circular.layoutFrame.width,
                height: circular.layoutFrame.height
            )

            if bounds.contains(pointInCircular) {
                if let config = circularConfig {
                    DispatchQueue.main.async { [weak self] in
                        self?.contextMenuState?.circularConfig = config
                        self?.contextMenuState?.showCircularMenu = true
                    }
                }
                return
            }
        }

        // Check dynamic grid collection
        if let grid = dynamicGridCollection,
           let centerParent = grid.parent {
            let pointInCenter = convert(location, to: centerParent)
            let pointInGrid = centerParent.convert(pointInCenter, to: grid)

            let bounds = CGRect(
                x: -grid.layoutFrame.width / 2,
                y: -grid.layoutFrame.height / 2,
                width: grid.layoutFrame.width,
                height: grid.layoutFrame.height
            )

            if bounds.contains(pointInGrid) {
                if let config = gridConfig {
                    DispatchQueue.main.async { [weak self] in
                        self?.contextMenuState?.gridConfig = config
                        self?.contextMenuState?.showGridMenu = true
                    }
                }
                return
            }
        }

        // Check nested test collection
        if let nested = nestedCollection,
           let centerParent = nested.parent {
            let pointInCenter = convert(location, to: centerParent)
            let pointInNested = centerParent.convert(pointInCenter, to: nested)

            let bounds = CGRect(
                x: -nested.layoutFrame.width / 2,
                y: -nested.layoutFrame.height / 2,
                width: nested.layoutFrame.width,
                height: nested.layoutFrame.height
            )

            if bounds.contains(pointInNested) {
                // Nested collection doesn't have its own menu, but we should handle the click
                // so it doesn't fall through to center collection
                return
            }
        }

        // Check center collection (but only if not clicking on its children)
        if let center = centerCollection {
            let pointInCenter = convert(location, to: center)

            let bounds = CGRect(
                x: -center.layoutFrame.width / 2,
                y: -center.layoutFrame.height / 2,
                width: center.layoutFrame.width,
                height: center.layoutFrame.height
            )

            if bounds.contains(pointInCenter) {
                if let config = centerGridConfig {
                    DispatchQueue.main.async { [weak self] in
                        self?.contextMenuState?.centerGridConfig = config
                        self?.contextMenuState?.showCenterGridMenu = true
                    }
                }
                return
            }
        }

        // Check stack layout containers (direct children of scene)
        for (index, (config, collection, _)) in layoutContainers.enumerated() {
            let pointInCollection = convert(location, to: collection)

            let bounds = CGRect(
                x: -collection.layoutFrame.width / 2,
                y: -collection.layoutFrame.height / 2,
                width: collection.layoutFrame.width,
                height: collection.layoutFrame.height
            )

            if bounds.contains(pointInCollection) {
                DispatchQueue.main.async { [weak self] in
                    self?.contextMenuState?.stackConfig = config
                    self?.contextMenuState?.selectedIndex = index
                    self?.contextMenuState?.showStackMenu = true
                }
                return
            }
        }
    }

    public override func mouseDown(with event: NSEvent) {
        coordinator.handleTouchBegan(at: event.location(in: self), in: self)
    }

    public override func mouseDragged(with event: NSEvent) {
        coordinator.handleTouchMoved(to: event.location(in: self))
    }

    public override func mouseUp(with event: NSEvent) {
        coordinator.handleTouchEnded(at: event.location(in: self))
    }
    #endif
}
