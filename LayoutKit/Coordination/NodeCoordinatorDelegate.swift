//
//  NodeCoordinatorDelegate.swift
//  LayoutKit
//
//  Protocol for policy decisions in node coordination system
//

import Foundation
import SpriteKit

/// Protocol for making policy decisions about node tracking and movement
public protocol NodeCoordinatorDelegate: AnyObject {
    /// Ask if a node can be tracked (picked up)
    /// - Parameters:
    ///   - coordinator: The node coordinator
    ///   - node: The node that was touched
    ///   - sourceCollection: The collection containing the node
    /// - Returns: true if node can be tracked
    func nodeCoordinator(
        _ coordinator: NodeCoordinator,
        canTrackNode node: LayoutableNode,
        inCollection sourceCollection: SKCollectionNode
    ) -> Bool

    /// Ask if a node can be moved to a target collection
    /// - Parameters:
    ///   - coordinator: The node coordinator
    ///   - node: The node being moved
    ///   - sourceCollection: The collection the node came from
    ///   - targetCollection: The collection the node is being dropped on
    /// - Returns: true if the move is allowed
    func nodeCoordinator(
        _ coordinator: NodeCoordinator,
        canMoveNode node: LayoutableNode,
        from sourceCollection: SKCollectionNode,
        to targetCollection: SKCollectionNode
    ) -> Bool

    /// Get the transformation to apply when tracking starts
    /// - Parameters:
    ///   - coordinator: The node coordinator
    ///   - node: The node that will be tracked
    /// - Returns: A closure that applies the transformation to the node
    func nodeCoordinator(
        _ coordinator: NodeCoordinator,
        trackingTransformationFor node: LayoutableNode
    ) -> ((SKNode) -> Void)?

    /// Get the transformation to reset when tracking ends
    /// - Parameters:
    ///   - coordinator: The node coordinator
    ///   - node: The node that was being tracked
    /// - Returns: A closure that resets the transformation
    func nodeCoordinator(
        _ coordinator: NodeCoordinator,
        resetTransformationFor node: LayoutableNode
    ) -> ((SKNode) -> Void)?
}