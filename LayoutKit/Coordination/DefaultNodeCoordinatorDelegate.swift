//
//  DefaultNodeCoordinatorDelegate.swift
//  LayoutKit
//
//  Default implementation of NodeCoordinatorDelegate with sensible defaults
//

import Foundation
import SpriteKit

/// Default implementation of NodeCoordinatorDelegate that allows all operations
public class DefaultNodeCoordinatorDelegate: NodeCoordinatorDelegate {

    // MARK: - Properties

    /// Store original z-positions to restore them properly
    private var originalZPositions: [ObjectIdentifier: CGFloat] = [:]

    // MARK: - Initialization

    public init() {}

    // MARK: - NodeCoordinatorDelegate

    /// Always allow tracking
    public func nodeCoordinator(
        _ coordinator: NodeCoordinator,
        canTrackNode node: LayoutableNode,
        inCollection sourceCollection: SKCollectionNode
    ) -> Bool {
        return true
    }

    /// Always allow movement
    public func nodeCoordinator(
        _ coordinator: NodeCoordinator,
        canMoveNode node: LayoutableNode,
        from sourceCollection: SKCollectionNode,
        to targetCollection: SKCollectionNode
    ) -> Bool {
        return true
    }

    /// Default: scale up slightly and bring to front
    public func nodeCoordinator(
        _ coordinator: NodeCoordinator,
        trackingTransformationFor node: LayoutableNode
    ) -> ((SKNode) -> Void)? {
        return { [weak self] skNode in
            // Store original z-position
            let nodeId = ObjectIdentifier(skNode)
            self?.originalZPositions[nodeId] = skNode.zPosition

            let scaleAction = SKAction.scale(to: 1.1, duration: 0.1)
            skNode.run(scaleAction)
            skNode.zPosition = 1000 // Bring to front with high z-position
        }
    }

    /// Reset scale only - z-position will be handled by the layout system
    public func nodeCoordinator(
        _ coordinator: NodeCoordinator,
        resetTransformationFor node: LayoutableNode
    ) -> ((SKNode) -> Void)? {
        return { [weak self] skNode in
            let scaleAction = SKAction.scale(to: 1.0, duration: 0.1)
            skNode.run(scaleAction)
            // Don't reset z-position here - let the layout system handle it
            // Clean up stored value
            let nodeId = ObjectIdentifier(skNode)
            self?.originalZPositions.removeValue(forKey: nodeId)
        }
    }
}