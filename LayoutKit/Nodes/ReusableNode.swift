import Foundation
import CoreGraphics

/// Protocol for nodes that can be reused from a pool to improve performance.
/// Reusable nodes have an identifier and can reset their state when reused.
public protocol ReusableNode: LayoutableNode {
    /// Unique identifier for this type of reusable node
    /// Nodes with the same identifier can be reused interchangeably
    var reuseIdentifier: String { get }

    /// Prepare this node for reuse
    /// Reset any state that should not carry over to the next use
    /// Called automatically when the node is dequeued from the pool
    func prepareForReuse()
}
