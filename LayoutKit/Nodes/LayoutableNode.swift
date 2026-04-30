import Foundation
import CoreGraphics

/// Protocol for nodes that can be positioned and sized by a layout system.
/// Layoutable nodes receive layout information (frame, zIndex) from their parent
/// and can notify when they need layout updates.
public protocol LayoutableNode: AnyObject {
    /// The frame assigned by the parent's layout system
    var layoutFrame: CGRect { get set }

    /// The z-index (depth order) assigned by the parent's layout system
    var layoutZIndex: Int { get set }

    /// Delegate that receives notifications when this node needs layout updates
    /// Note: Conforming types should implement this as a weak reference to avoid retain cycles
    var layoutDelegate: LayoutableNodeDelegate? { get set }
}

/// Delegate protocol for receiving layout invalidation notifications
public protocol LayoutableNodeDelegate: AnyObject {
    /// Called when a child node has changed in a way that requires layout recalculation
    /// - Parameter node: The node that needs its layout updated
    func nodeDidInvalidateLayout(_ node: LayoutableNode)
}
