import Foundation
import SpriteKit
@testable import LayoutKit

#if os(macOS)
import AppKit
typealias PlatformImage = NSImage
typealias PlatformView = NSView
#elseif os(iOS) || os(tvOS)
import UIKit
typealias PlatformImage = UIImage
typealias PlatformView = UIView
#endif


/// Standard test sizes for snapshot testing
enum TestSize {
    case small
    case medium
    case large
    case custom(CGSize)

    var size: CGSize {
        switch self {
        case .small:
            return CGSize(width: 400, height: 400)
        case .medium:
            return CGSize(width: 800, height: 600)
        case .large:
            return CGSize(width: 1200, height: 900)
        case .custom(let size):
            return size
        }
    }
}

/// Standard color palette for test nodes
enum TestColor: CaseIterable {
    case red, blue, green, yellow, orange, purple, cyan, magenta

    var color: SKColor {
        switch self {
        case .red: return SKColor(red: 1.0, green: 0.3, blue: 0.3, alpha: 1.0)
        case .blue: return SKColor(red: 0.3, green: 0.5, blue: 1.0, alpha: 1.0)
        case .green: return SKColor(red: 0.3, green: 0.8, blue: 0.3, alpha: 1.0)
        case .yellow: return SKColor(red: 1.0, green: 0.9, blue: 0.3, alpha: 1.0)
        case .orange: return SKColor(red: 1.0, green: 0.6, blue: 0.2, alpha: 1.0)
        case .purple: return SKColor(red: 0.7, green: 0.3, blue: 0.9, alpha: 1.0)
        case .cyan: return SKColor(red: 0.3, green: 0.9, blue: 0.9, alpha: 1.0)
        case .magenta: return SKColor(red: 0.9, green: 0.3, blue: 0.7, alpha: 1.0)
        }
    }
}

/// Helper functions for rendering SKCollectionNode to images for snapshot testing
struct SnapshotTestHelpers {

    /// Render an SKCollectionNode to a platform-specific image
    /// - Parameters:
    ///   - collectionNode: The collection node to render
    ///   - size: The size of the output image
    ///   - backgroundColor: Background color for the scene (default: white)
    /// - Returns: Rendered image
    @MainActor
    static func render(
        collectionNode: SKCollectionNode,
        size: CGSize,
        backgroundColor: SKColor = .white
    ) -> PlatformImage {
        // Create a scene
        let scene = SKScene(size: size)
        scene.backgroundColor = backgroundColor
        scene.scaleMode = .aspectFit

        // Set the collection node's layout frame to match scene size
        collectionNode.layoutFrame = CGRect(origin: .zero, size: size)
        collectionNode.position = CGPoint(x: size.width / 2, y: size.height / 2)

        // Add to scene and trigger layout
        scene.addChild(collectionNode)
        collectionNode.layoutIfNeeded()

        // Create a view for rendering
        let view = SKView(frame: CGRect(origin: .zero, size: size))

        #if os(macOS)
        // For macOS, we need to render using SKView's texture method
        view.presentScene(scene)

        // Force a render cycle
        view.setNeedsDisplay(view.bounds)

        // Use SKView to create a texture from the scene
        let texture = view.texture(from: scene)
        guard let cgImage = texture?.cgImage() else {
            fatalError("Failed to create texture from scene")
        }

        let image = NSImage(cgImage: cgImage, size: size)
        return image

        #elseif os(iOS) || os(tvOS)
        view.presentScene(scene)

        // Force a render cycle
        view.setNeedsDisplay()

        // Use SKView to create a texture from the scene
        let texture = view.texture(from: scene)
        guard let cgImage = texture?.cgImage() else {
            fatalError("Failed to create texture from scene")
        }

        let image = UIImage(cgImage: cgImage)
        return image
        #endif
    }

    /// Render a collection node with standard test size
    @MainActor
    static func render(
        collectionNode: SKCollectionNode,
        testSize: TestSize = .medium,
        backgroundColor: SKColor = .white
    ) -> PlatformImage {
        return render(
            collectionNode: collectionNode,
            size: testSize.size,
            backgroundColor: backgroundColor
        )
    }

    /// Create a test shape node with a specific color
    /// - Parameters:
    ///   - color: The color for the node
    ///   - index: Optional index for debugging/identification
    /// - Returns: A configured LayoutableSKShapeNode
    static func createTestNode(color: TestColor, index: Int? = nil) -> LayoutableSKShapeNode {
        let node = LayoutableSKShapeNode()
        node.fillColor = color.color
        node.strokeColor = .black
        node.lineWidth = 2

        // Add a label if index is provided
        if let index = index {
            let label = SKLabelNode(text: "\(index)")
            label.fontSize = 24
            label.fontName = "Helvetica-Bold"
            label.fontColor = .black
            label.verticalAlignmentMode = .center
            label.horizontalAlignmentMode = .center
            label.zPosition = 1
            node.addChild(label)
        }

        return node
    }

    /// Create multiple test nodes with different colors
    /// - Parameters:
    ///   - count: Number of nodes to create
    ///   - showIndex: Whether to show index labels on nodes
    /// - Returns: Array of LayoutableSKShapeNode
    static func createTestNodes(count: Int, showIndex: Bool = true) -> [LayoutableSKShapeNode] {
        let colors = TestColor.allCases
        return (0..<count).map { index in
            let color = colors[index % colors.count]
            return createTestNode(color: color, index: showIndex ? index : nil)
        }
    }

    /// Create a collection node with a given layout and test nodes
    /// - Parameters:
    ///   - layout: The layout to use
    ///   - nodeCount: Number of nodes to add
    ///   - showIndex: Whether to show index labels
    ///   - contentInsets: Content insets for the collection
    /// - Returns: Configured SKCollectionNode
    @MainActor
    static func createTestCollection(
        layout: CollectionLayout,
        nodeCount: Int,
        showIndex: Bool = true,
        contentInsets: Insets = Insets(uniform: 10)
    ) -> SKCollectionNode {
        let collection = SKCollectionNode(layoutBuilder: { _ in layout }, contentInsets: contentInsets)

        // Add test nodes
        let nodes = createTestNodes(count: nodeCount, showIndex: showIndex)
        for node in nodes {
            collection.addLayoutableChild(node)
        }

        return collection
    }

    /// Validate that a collection node has been laid out correctly
    /// - Parameter collectionNode: The collection to validate
    /// - Returns: True if layout appears valid, false otherwise
    static func validateLayout(collectionNode: SKCollectionNode) -> Bool {
        // Check that all children have non-zero frames
        for child in collectionNode.layoutableChildren {
            if child.layoutFrame.width <= 0 || child.layoutFrame.height <= 0 {
                print("Warning: Child has invalid frame: \(child.layoutFrame)")
                return false
            }
        }
        return true
    }
}
