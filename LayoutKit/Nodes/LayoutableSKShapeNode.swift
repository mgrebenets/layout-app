import Foundation
import SpriteKit

/// A shape node that can be positioned by a layout system and reused from a pool
public class LayoutableSKShapeNode: SKShapeNode, LayoutableNode, ReusableNode {

    // MARK: - LayoutableNode Properties

    /// The frame assigned by the parent's layout system
    public var layoutFrame: CGRect = .zero {
        didSet {
            applyLayoutFrame()
        }
    }

    /// The z-index assigned by the parent's layout system
    public var layoutZIndex: Int = 0

    /// Delegate that receives notifications when this node needs layout updates
    public weak var layoutDelegate: LayoutableNodeDelegate?

    // MARK: - ReusableNode Properties

    /// Unique identifier for this type of reusable node
    public var reuseIdentifier: String {
        return "LayoutableSKShapeNode"
    }

    // MARK: - ReusableNode Methods

    /// Prepare this node for reuse by resetting its state
    public func prepareForReuse() {
        // Reset visual properties
        fillColor = .clear
        strokeColor = .black
        lineWidth = 1.0
        alpha = 1.0

        // Remove all children (like labels)
        removeAllChildren()

        // Reset transform
        xScale = 1.0
        yScale = 1.0
        zRotation = 0

        // Reset layout properties
        layoutFrame = .zero
        layoutZIndex = 0
    }

    // MARK: - Private Methods

    /// Apply the layout frame to this node's SpriteKit position and size
    private func applyLayoutFrame() {
        // Position at the center of the layout frame
        position = CGPoint(
            x: layoutFrame.midX,
            y: layoutFrame.midY
        )

        // Update the shape path to match the size
        let rect = CGRect(
            x: -layoutFrame.width / 2,
            y: -layoutFrame.height / 2,
            width: layoutFrame.width,
            height: layoutFrame.height
        )

        let newPath = CGPath(
            roundedRect: rect,
            cornerWidth: 4,
            cornerHeight: 4,
            transform: nil
        )
        path = newPath
    }
}
