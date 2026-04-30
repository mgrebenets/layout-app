import Foundation
import CoreGraphics

/// Protocol for nodes that manage a collection of child nodes with a layout system.
/// Collection nodes own a layout, manage children, and coordinate layout updates.
public protocol CollectionNode: LayoutableNode {
    /// The layout strategy used to position and size children
    var layout: CollectionLayout! { get set }

    /// The array of child nodes being laid out
    var layoutableChildren: [LayoutableNode] { get }

    /// Add a child node to this collection
    /// - Parameter child: The node to add
    func addLayoutableChild(_ child: LayoutableNode)

    /// Remove a child node from this collection
    /// - Parameter child: The node to remove
    func removeLayoutableChild(_ child: LayoutableNode)

    /// Mark the layout as needing recalculation
    /// This should be called when children are added/removed or when child properties change
    func invalidateLayout()

    /// Perform layout if needed
    /// Calculates and applies layout attributes to all children
    func layoutIfNeeded()

    /// Force layout to be performed immediately
    /// This bypasses the needsLayout check and always performs layout
    func forceLayout()
}
