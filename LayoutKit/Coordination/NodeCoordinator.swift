//
//  NodeCoordinator.swift
//  LayoutKit
//
//  Central orchestrator for node movement between collections
//

import Foundation
import SpriteKit

/// Central coordinator for managing node movement between collections
public class NodeCoordinator {
    // MARK: - Properties

    /// Registered collections that can participate in node movement
    private var registeredCollections: Set<SKCollectionNode> = []

    /// Parent container for "free" nodes during drag
    private weak var parentContainer: SKNode?

    /// Delegate for policy decisions
    public weak var delegate: NodeCoordinatorDelegate?

    /// Current tracking state
    private var trackedNode: LayoutableNode?
    private var sourceCollection: SKCollectionNode?
    private var originalIndex: Int?  // Track the original index for proper re-insertion
    private var isDragging: Bool = false

    // MARK: - Initialization

    public init() {}

    // MARK: - Collection Registration

    /// Register a collection to participate in node movement
    /// - Parameter collection: The collection to register
    public func register(collection: SKCollectionNode) {
        registeredCollections.insert(collection)
    }

    /// Unregister a collection from participating in node movement
    /// - Parameter collection: The collection to unregister
    public func unregister(collection: SKCollectionNode) {
        registeredCollections.remove(collection)
    }

    /// Unregister all collections
    public func unregisterAll() {
        registeredCollections.removeAll()
    }

    /// Whether a drag operation is currently in progress
    public var isTracking: Bool { isDragging }

    /// Set the parent container for holding "free" nodes during drag
    /// - Parameter container: The parent container (typically the scene)
    public func setParentContainer(_ container: SKNode) {
        parentContainer = container
    }

    /// Determines visual priority between two collections.
    /// Higher priority means the collection is "more on top" (higher zPosition or deeper nesting).
    private func hasHigherPriority(_ a: SKCollectionNode, than b: SKCollectionNode) -> Bool {
        // 1. Check world z-position (accumulated)
        let zA = a.zPosition // Simplified: In a real app, you might sum up parent zPositions
        let zB = b.zPosition
        if zA != zB {
            return zA > zB
        }

        // 2. If z-positions are equal, check if one is a descendant of the other
        var current: SKNode? = a
        while let parent = current?.parent {
            if parent === b { return true } // a is deeper than b
            current = parent
        }
        return false
    }

    // MARK: - Helper Methods

    /// Find the collection containing a point
    /// - Parameters:
    ///   - point: The point in scene coordinates
    ///   - scene: The scene containing the collections
    /// - Returns: The deepest collection containing the point, or nil
    private func findCollection(at point: CGPoint, in scene: SKScene) -> SKCollectionNode? {
        // Start with all registered collections that contain the point
        var candidateCollections: [SKCollectionNode] = []

        for collection in registeredCollections {
            let localPoint = scene.convert(point, to: collection)
            let bounds = CGRect(
                x: -collection.layoutFrame.width / 2,
                y: -collection.layoutFrame.height / 2,
                width: collection.layoutFrame.width,
                height: collection.layoutFrame.height
            )

            if bounds.contains(localPoint) {
                candidateCollections.append(collection)
            }
        }

        return candidateCollections.max { a, b in
            hasHigherPriority(b, than: a)
        }
    }

    /// Find a node and its containing collection at the given point
    /// - Parameters:
    ///   - point: The point in scene coordinates
    ///   - scene: The scene containing the collections
    /// - Returns: A tuple of the node and its collection, or nil
    /// - Note: Only registered collections participate in hit testing.
    ///         To enable dragging from nested collections, register them explicitly.
    private func findNode(at point: CGPoint, in scene: SKScene) -> (node: LayoutableNode, collection: SKCollectionNode)? {
        // Build a list of all registered collections that contain a node at this point
        var candidateResults: [(node: LayoutableNode, collection: SKCollectionNode)] = []

        for collection in registeredCollections {
            let localPoint = scene.convert(point, to: collection)

            if let node = collection.layoutableNode(at: localPoint) {
                candidateResults.append((node, collection))
            }
        }

        // Return the result with the deepest (most nested) collection
        // This handles cases where multiple registered collections overlap
        return candidateResults.max { a, b in
            hasHigherPriority(b.collection, than: a.collection)
        }
    }

    // MARK: - Touch/Mouse Handling

    /// Handle the beginning of a touch/mouse down event
    /// - Parameters:
    ///   - point: The location of the touch in scene coordinates
    ///   - scene: The scene containing the touch
    public func handleTouchBegan(at point: CGPoint, in scene: SKScene) {
        guard let (node, collection) = findNode(at: point, in: scene) else {
            print("❌ No node found at point: \(point)")
            return
        }

        print("🎯 Touch began at: \(point)")
        print("   Found node: \(type(of: node))")
        print("   In collection: \(type(of: collection))")

        // Check if collection is nested
        if let parent = collection.parent as? SKCollectionNode {
            print("   ⚠️ Collection is nested inside: \(type(of: parent))")
            print("   Collection position in parent: \(collection.position)")
            print("   Collection.frame (SKNode): \(collection.frame)")
            print("   Collection.layoutFrame (LayoutableNode): \(collection.layoutFrame)")
            print("   Parent.layoutFrame: \(parent.layoutFrame)")
        } else {
            print("   Collection.layoutFrame: \(collection.layoutFrame)")
        }

        // Ask delegate if this node can be tracked
        guard let delegate = delegate,
              delegate.nodeCoordinator(self, canTrackNode: node, inCollection: collection) else {
            print("   ❌ Delegate denied tracking")
            return
        }

        // Check if collection has valid layout frame
        if collection.layoutFrame.width == 0 || collection.layoutFrame.height == 0 {
            print("   ⚠️ WARNING: Collection has zero-size layoutFrame: \(collection.layoutFrame)")
            print("   This will cause immediate node removal. Collection may need layout.")
        }

        // Start tracking
        trackedNode = node
        sourceCollection = collection
        // Find the original index of the node in its collection
        if let index = collection.layoutableChildren.firstIndex(where: { $0 === node }) {
            originalIndex = index
            print("   📌 Original index in collection: \(index)")
        }
        isDragging = true

        // Apply tracking transformation
        if let transform = delegate.nodeCoordinator(self, trackingTransformationFor: node),
           let skNode = node as? SKNode {
            print("   Node position before transform: \(skNode.position)")
            print("   Node zPosition before transform: \(skNode.zPosition)")
            transform(skNode)
            print("   ✅ Applied tracking transformation")
            print("   Node position after transform: \(skNode.position)")
            print("   Node zPosition after transform: \(skNode.zPosition)")
        }
    }

    /// Handle touch/mouse movement during drag
    /// - Parameter point: The current location of the touch in scene coordinates
    public func handleTouchMoved(to point: CGPoint) {
        guard isDragging,
              let node = trackedNode,
              let skNode = node as? SKNode,
              let source = sourceCollection,
              let parent = parentContainer else { return }

        print("🖱️ handleTouchMoved")
        print("   Mouse position (scene coords): \(point)")
        print("   Node parent: \(type(of: skNode.parent))")
        print("   Source collection: \(type(of: source))")
        print("   Parent container: \(type(of: parent))")

        // If node is still in source collection, check if we should make it "free"
        if skNode.parent == source {
            // Get source collection's bounds in scene coordinates
            // We need to check if the point is outside the collection's bounds
            let sourceOriginInScene = source.scene?.convert(CGPoint.zero, from: source) ?? .zero
            let sourceBoundsInScene = CGRect(
                x: sourceOriginInScene.x - source.layoutFrame.width / 2,
                y: sourceOriginInScene.y - source.layoutFrame.height / 2,
                width: source.layoutFrame.width,
                height: source.layoutFrame.height
            )
            print("   Source bounds in scene: \(sourceBoundsInScene)")

            let expandedFrame = sourceBoundsInScene.insetBy(dx: -10, dy: -10) // Add small margin

            if !expandedFrame.contains(point) {
                print("   📤 Moving node outside source - making it free")
                // Node moved outside source - make it "free"
                // Convert node position from source to scene coordinates
                print("   Source collection type: \(type(of: source))")
                print("   Source parent: \(type(of: source.parent))")
                print("   Source position: \(source.position)")
                print("   Source layoutFrame: \(source.layoutFrame)")
                let globalPos = source.scene?.convert(skNode.position, from: source) ?? skNode.position
                print("   Node position in source: \(skNode.position)")
                print("   Node position in scene: \(globalPos)")
                print("   Mouse position: \(point)")
                print("   Node will be positioned at: \(globalPos)")

                // Store the original index for later re-insertion
                originalIndex = source.removeLayoutableChildWithIndex(node)
                parent.addChild(skNode)
                skNode.position = globalPos
                print("   ✅ Node is now free. Position: \(skNode.position), zPosition: \(skNode.zPosition)")

                // Force source to re-layout after removing node
                source.forceLayout()
            } else {
                // Still inside source, but update position to follow mouse
                let localPoint = source.scene?.convert(point, to: source) ?? point
                print("   📍 Updating position inside source")
                print("   Local point in source: \(localPoint)")
                skNode.position = localPoint
            }
        } else {
            // Node is already free, just follow the mouse
            print("   🎯 Node is free, following mouse at: \(point)")
            skNode.position = point
        }
    }

    /// Handle the end of a touch/mouse up event
    /// - Parameter point: The final location of the touch in scene coordinates
    public func handleTouchEnded(at point: CGPoint) {
        guard isDragging,
              let node = trackedNode,
              let skNode = node as? SKNode,
              let source = sourceCollection else {
            resetTracking()
            return
        }

        // Find target collection
        let targetCollection = findCollection(at: point, in: skNode.scene!)

        // Reset transformation
        if let reset = delegate?.nodeCoordinator(self, resetTransformationFor: node) {
            reset(skNode)
        }

        // Determine final destination
        if let target = targetCollection,
           target !== source,
           let delegate = delegate,
           delegate.nodeCoordinator(self, canMoveNode: node, from: source, to: target) {
            print("📦 Moving node to target collection")
            print("   Target children before: \(target.layoutableChildren.count)")
            // Move to target collection
            skNode.removeFromParent()
            // Reset position before adding to ensure layout positions it correctly
            skNode.position = .zero
            target.addLayoutableChild(node)
            print("   Target children after: \(target.layoutableChildren.count)")
            print("   Calling forceLayout on target")
            target.forceLayout()  // Force layout to ensure nodes are positioned
            print("   Layout complete. Node position: \(skNode.position), z-position: \(skNode.zPosition)")
        } else {
            print("📦 Returning node to source collection")
            print("   Source children before: \(source.layoutableChildren.count)")
            print("   Original index: \(originalIndex ?? -1)")
            print("   Node parent: \(type(of: skNode.parent))")

            // Only re-add to collection if it was removed (became "free")
            if skNode.parent != source {
                print("   Node was free, re-adding to source")
                // Return to source collection
                skNode.removeFromParent()
                // Reset position before adding to ensure layout positions it correctly
                skNode.position = .zero
                // If we have the original index and returning to same collection, insert at that position
                if let idx = originalIndex {
                    source.insertLayoutableChild(node, at: idx)
                } else {
                    source.addLayoutableChild(node)
                }
            } else {
                print("   Node never left collection, just repositioning")
                // Node never left the collection, just reset position
                skNode.position = .zero
            }

            print("   Source children after: \(source.layoutableChildren.count)")
            print("   Calling forceLayout on source")
            source.forceLayout()  // Force layout to ensure nodes are positioned
            print("   Layout complete. Node position: \(skNode.position), z-position: \(skNode.zPosition)")
        }

        resetTracking()
    }

    // MARK: - Private Methods

    /// Reset the tracking state
    private func resetTracking() {
        trackedNode = nil
        sourceCollection = nil
        originalIndex = nil
        isDragging = false
    }
}
