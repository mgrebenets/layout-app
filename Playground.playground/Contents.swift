import Foundation
import SpriteKit
import CoreGraphics
import Synchronization
import PlaygroundSupport

// MARK: - SpriteKit Integration

final class LayoutDataSource: CollectionLayoutDataSource {
    let numberOfItems: Int

    init(numberOfItems: Int) {
        self.numberOfItems = numberOfItems
    }
}

final class LayoutScene: SKScene {
    private var layout: VerticalStackLayout!
    private var nodes: [SKShapeNode] = []
    private let dataSource = LayoutDataSource(numberOfItems: 10)

    override func didMove(to view: SKView) {
        super.didMove(to: view)

        backgroundColor = .white

        // Initialize vertical layout
        layout = VerticalStackLayout(
            itemHeight: 60,
            itemSpacing: 10,
            dataSource: dataSource
        )

        setupNodes()
        layoutNodes()
    }

    private func setupNodes() {
        for i in 0..<dataSource.numberOfItems {
            let node = SKShapeNode(rectOf: CGSize(width: 100, height: 60), cornerRadius: 8)
            node.fillColor = [.systemBlue, .systemGreen, .systemOrange, .systemPurple, .systemPink][i % 5]
            node.strokeColor = .clear

            let label = SKLabelNode(text: "Item \(i)")
            label.fontColor = .white
            label.fontSize = 16
            label.verticalAlignmentMode = .center
            label.horizontalAlignmentMode = .center
            node.addChild(label)

            addChild(node)
            nodes.append(node)
        }
    }

    private func layoutNodes() {
        let context = LayoutContext(
            bounds: CGRect(origin: .zero, size: size),
            contentInsets: Insets(uniform: 20)
        )

        let attributes = layout.layoutAttributes(in: context)

        for attr in attributes {
            guard attr.index < nodes.count else { continue }
            let node = nodes[attr.index]

            // Convert from UIKit coordinate system (top-left origin) to SpriteKit (bottom-left origin)
            let spriteKitY = size.height - attr.frame.midY
            node.position = CGPoint(x: attr.frame.midX, y: spriteKitY)
        }
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        layoutNodes()
    }
}

// MARK: - View Setup

let sceneView = SKView(frame: CGRect(x: 0, y: 0, width: 375, height: 667))
let scene = LayoutScene(size: sceneView.bounds.size)
scene.scaleMode = .resizeFill
sceneView.presentScene(scene)
sceneView.showsFPS = true
sceneView.showsNodeCount = true

PlaygroundPage.current.liveView = sceneView
