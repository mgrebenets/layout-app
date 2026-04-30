import Foundation
import SpriteKit

/// A SpriteKit node that manages a collection of child nodes using a layout system.
/// This node conforms to CollectionNode and acts as both a layout container and a layoutable node itself.
public class SKCollectionNode: SKNode, CollectionNode, CollectionLayoutDataSource, LayoutableNodeDelegate {

    // MARK: - CollectionNode Properties

    /// The layout strategy used to position and size children
    public var layout: CollectionLayout! {
        didSet {
            invalidateLayout()
        }
    }

    /// The array of child nodes being laid out
    public private(set) var layoutableChildren: [LayoutableNode] = []

    // MARK: - LayoutableNode Properties

    /// The frame assigned by the parent's layout system
    /// For SKCollectionNode, this represents the size and is used for layout bounds
    /// Position is managed through SKNode.position
    public var layoutFrame: CGRect = .zero {
        didSet {
            invalidateLayout()
            updateDebugBorder()
        }
    }

    /// The z-index assigned by the parent's layout system
    public var layoutZIndex: Int = 0 {
        didSet {
            zPosition = CGFloat(layoutZIndex)
        }
    }

    /// Delegate that receives notifications when this node needs layout updates
    public weak var layoutDelegate: LayoutableNodeDelegate?

    // MARK: - CollectionLayoutDataSource

    /// Number of items in the collection
    public var numberOfItems: Int {
        layoutableChildren.count
    }

    // MARK: - Private Properties

    /// Whether layout needs to be recalculated
    private var needsLayout = true

    /// Content insets for the layout
    private var contentInsets: Insets

    /// Optional debug border for visualization
    private var debugBorder: SKShapeNode?

    /// Node pool for reusing nodes
    public var nodePool: NodePool?

    /// Color for the debug border
    public var debugBorderColor: SKColor? {
        didSet {
            updateDebugBorder()
        }
    }

    /// Line width for the debug border
    public var debugBorderWidth: CGFloat = 2 {
        didSet {
            updateDebugBorder()
        }
    }

    // MARK: - Initialization

    public init(layoutBuilder: (SKCollectionNode) -> CollectionLayout, contentInsets: Insets = Insets(uniform: 0)) {
        self.contentInsets = contentInsets
        super.init()
        // Initialize layout after `self` is available, passing `self` as the dataSource
        self.layout = layoutBuilder(self)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - CollectionNode Methods

    /// Add a child node to this collection
    public func addLayoutableChild(_ child: LayoutableNode) {
        print("   ➕ addLayoutableChild called")
        print("      Children before: \(layoutableChildren.count)")

        // Check if child is already in the array
        if let existingIndex = layoutableChildren.firstIndex(where: { $0 === child }) {
            print("      ⚠️ WARNING: Child already exists at index \(existingIndex)!")
            print("      This will create a duplicate entry!")
        }

        layoutableChildren.append(child)
        // DON'T set layoutDelegate on children - prevents cascading invalidations
        // child.layoutDelegate = self

        // Add to SpriteKit hierarchy if it's an SKNode
        if let skNode = child as? SKNode {
            addChild(skNode)
            print("      Added SKNode to hierarchy at position: \(skNode.position)")
        }

        invalidateLayout()
        print("      Children after: \(layoutableChildren.count), layout invalidated")

        // Verify no duplicates
        let uniqueChildren = Set(layoutableChildren.map { ObjectIdentifier($0) })
        if uniqueChildren.count != layoutableChildren.count {
            print("      ❌ ERROR: Duplicate entries detected in layoutableChildren!")
            print("      Unique: \(uniqueChildren.count), Total: \(layoutableChildren.count)")
        }
    }

    /// Remove a child node from this collection
    public func removeLayoutableChild(_ child: LayoutableNode) {
        if let index = layoutableChildren.firstIndex(where: { $0 === child }) {
            layoutableChildren.remove(at: index)

            // Remove from SpriteKit hierarchy if it's an SKNode
            if let skNode = child as? SKNode {
                skNode.removeFromParent()
            }

            invalidateLayout()
        }
    }

    /// Remove a child node and return its index
    /// - Returns: The index of the removed child, or nil if not found
    public func removeLayoutableChildWithIndex(_ child: LayoutableNode) -> Int? {
        print("   ➖ removeLayoutableChildWithIndex called")
        print("      Children before: \(layoutableChildren.count)")

        if let index = layoutableChildren.firstIndex(where: { $0 === child }) {
            print("      Found child at index \(index), removing...")
            layoutableChildren.remove(at: index)

            // Remove from SpriteKit hierarchy if it's an SKNode
            if let skNode = child as? SKNode {
                skNode.removeFromParent()
                print("      Removed from SKNode hierarchy")
            }

            invalidateLayout()
            print("      Children after: \(layoutableChildren.count), layout invalidated")
            return index
        }
        print("      ⚠️ WARNING: Child not found in layoutableChildren!")
        return nil
    }

    /// Insert a child node at a specific index
    public func insertLayoutableChild(_ child: LayoutableNode, at index: Int) {
        print("   ➕ insertLayoutableChild at index \(index)")
        print("      Children before: \(layoutableChildren.count)")

        // Check if child is already in the array
        if let existingIndex = layoutableChildren.firstIndex(where: { $0 === child }) {
            print("      ⚠️ WARNING: Child already exists at index \(existingIndex)!")
            print("      This will create a duplicate entry!")
        }

        let safeIndex = min(max(0, index), layoutableChildren.count)
        layoutableChildren.insert(child, at: safeIndex)

        // Add to SpriteKit hierarchy if it's an SKNode
        if let skNode = child as? SKNode {
            addChild(skNode)
            print("      Inserted SKNode at index \(safeIndex)")
        }

        invalidateLayout()
        print("      Children after: \(layoutableChildren.count), layout invalidated")

        // Verify no duplicates
        let uniqueChildren = Set(layoutableChildren.map { ObjectIdentifier($0) })
        if uniqueChildren.count != layoutableChildren.count {
            print("      ❌ ERROR: Duplicate entries detected in layoutableChildren!")
            print("      Unique: \(uniqueChildren.count), Total: \(layoutableChildren.count)")
        }
    }

    /// Find the deepest layoutable node at the given point
    /// Uses chain of responsibility for nested collections
    /// - Parameter point: Point in this node's coordinate space
    /// - Returns: The node at that point, or nil
    public func layoutableNode(at point: CGPoint) -> LayoutableNode? {
        // Iterate in reverse to check top-most nodes first (respecting addition order/z-index)
        let candidates = layoutableChildren.reversed()

        for child in candidates {
            if let childCollection = child as? SKCollectionNode {
                let localPoint = convert(point, to: childCollection)
                if let found = childCollection.layoutableNode(at: localPoint) {
                    return found
                }
            }
        }

        for child in candidates {
            if let skNode = child as? SKNode {
                // Get the node's frame in parent coordinates
                let nodeFrame = skNode.frame

                // Check if the point (in parent coordinates) is within the node's frame
                if nodeFrame.contains(point) {
                    return child
                }
            }
        }

        return nil
    }

    /// Mark the layout as needing recalculation
    public func invalidateLayout() {
        needsLayout = true
        // Clear the cached layout attributes when children change
        layout.invalidateLayout()
        layoutDelegate?.nodeDidInvalidateLayout(self)
    }

    /// Perform layout if needed
    public func layoutIfNeeded() {
        guard needsLayout else { return }
        guard layoutFrame.width > 0 && layoutFrame.height > 0 else {
            // Don't layout with zero or invalid bounds
            return
        }
        needsLayout = false
        performLayout()
    }

    /// Force layout to be performed immediately, regardless of needsLayout flag
    public func forceLayout() {
        print("🔄 forceLayout called on collection")
        print("   layoutFrame: \(layoutFrame)")
        print("   children count: \(layoutableChildren.count)")
        guard layoutFrame.width > 0 && layoutFrame.height > 0 else {
            print("   ❌ Invalid bounds, skipping layout")
            // Don't layout with zero or invalid bounds
            return
        }
        print("   ✅ Performing layout")
        needsLayout = false
        performLayout()
        print("   Layout complete. First child position: \(layoutableChildren.first.map { ($0 as? SKNode)?.position ?? .zero } ?? .zero)")
    }

    // MARK: - Node Pool Methods

    /// Dequeue a reusable node from the pool, or create a new one if none available
    /// - Parameters:
    ///   - identifier: The reuse identifier for the type of node
    ///   - create: Closure that creates a new node if one is not available in the pool
    /// - Returns: A reusable node, either from the pool or newly created
    public func dequeueReusableNode<T: ReusableNode>(
        withIdentifier identifier: String,
        create: () -> T
    ) async -> T {
        guard let pool = nodePool else {
            // No pool configured, just create a new node
            return create()
        }

        return await pool.dequeueReusableNode(withIdentifier: identifier, create: create)
    }

    /// Remove all children and return reusable nodes to the pool
    public func recycleAllChildren() async {
        // Return reusable children to the pool
        let reusableChildren = layoutableChildren.compactMap { $0 as? ReusableNode }
        if let pool = nodePool {
            await pool.enqueueForReuse(reusableChildren)
        }

        // Remove all children
        for child in layoutableChildren {
            if let skNode = child as? SKNode {
                skNode.removeFromParent()
            }
        }

        layoutableChildren.removeAll()
        invalidateLayout()
    }

    /// Remove specific children and return them to the pool if they're reusable
    /// - Parameter children: The children to remove and recycle
    public func recycleChildren(_ children: [LayoutableNode]) async {
        for child in children {
            removeLayoutableChild(child)

            // Return to pool if reusable
            if let reusableNode = child as? ReusableNode, let pool = nodePool {
                await pool.enqueueForReuse(reusableNode)
            }
        }
    }

    // MARK: - LayoutableNodeDelegate

    /// Called when a child node invalidates its layout
    public func nodeDidInvalidateLayout(_ node: LayoutableNode) {
        invalidateLayout()
    }

    // MARK: - Private Methods

    /// Calculate and apply layout to all children
    private func performLayout() {
        print("   🎯 performLayout starting")
        print("      Layout type: \(type(of: layout))")
        print("      layoutFrame: \(layoutFrame)")
        print("      children count: \(layoutableChildren.count)")
        // Layout children in local coordinate space
        // Use layoutFrame.size as the bounds for layout calculation
        let localBounds = CGRect(
            x: 0,
            y: 0,
            width: layoutFrame.width,
            height: layoutFrame.height
        )

        let context = LayoutContext(
            bounds: localBounds,
            contentInsets: contentInsets
        )

        let attributes = layout.layoutAttributes(in: context)
        print("      attributes count: \(attributes.count)")

        for attr in attributes {
            guard attr.index < layoutableChildren.count else {
                print("      ⚠️ Attribute index \(attr.index) out of bounds (children: \(layoutableChildren.count))")
                continue
            }
            let child = layoutableChildren[attr.index]

            // Children are positioned in local coordinate space relative to this node's origin
            // Convert from layout coordinates (top-left origin, Y down) to SpriteKit local (center origin, Y up)
            let localFrame = CGRect(
                x: attr.frame.minX - localBounds.width / 2,
                y: localBounds.height / 2 - attr.frame.maxY,
                width: attr.frame.width,
                height: attr.frame.height
            )

            print("      Child \(attr.index): layout frame=\(attr.frame), local frame=\(localFrame), zIndex=\(attr.zIndex)")

            // For SKCollectionNode children, set size in layoutFrame and position separately
            if let childCollection = child as? SKCollectionNode {
                print("      📦 Child is a collection:")
                print("         attr.frame from layout: \(attr.frame)")
                print("         Setting layoutFrame size: \(attr.frame.width) x \(attr.frame.height)")
                // Set layoutFrame with just size (no position offset)
                childCollection.layoutFrame = CGRect(x: 0, y: 0, width: attr.frame.width, height: attr.frame.height)
                // Set position in parent's local coordinate space
                childCollection.position = CGPoint(x: localFrame.midX, y: localFrame.midY)
                childCollection.layoutZIndex = attr.zIndex
                // Set z-position directly from layout's z-index
                childCollection.zPosition = CGFloat(attr.zIndex)
                print("         Child collection layoutFrame after setting: \(childCollection.layoutFrame)")
                // Trigger child layout
                childCollection.layoutIfNeeded()
            } else {
                // For other layoutable nodes (like LayoutableSKShapeNode), set full frame
                child.layoutFrame = localFrame
                child.layoutZIndex = attr.zIndex
                // Set z-position directly from layout's z-index
                if let skNode = child as? SKNode {
                    skNode.zPosition = CGFloat(attr.zIndex)
                }
            }
        }

        // Update border frames for child collections
        updateChildBorders()
    }

    private func updateChildBorders() {
        // Update border frames for any child collections that have borders
        for child in layoutableChildren {
            if let childCollection = child as? SKCollectionNode {
                // Find any child node that's a border frame (SKShapeNode with name starting with "child_border_")
                for node in childCollection.children {
                    // Check if it's our debug border or a sub-collection's border
                    if let borderFrame = node as? SKShapeNode, let name = borderFrame.name,
                       name == "debug_border" || name.hasPrefix("child_border_") {

                        let rect = CGRect(
                            x: -childCollection.layoutFrame.width / 2,
                            y: -childCollection.layoutFrame.height / 2,
                            width: childCollection.layoutFrame.width,
                            height: childCollection.layoutFrame.height
                        )
                        borderFrame.path = CGPath(rect: rect, transform: nil)
                    }
                }
            }
        }
    }

    private func updateDebugBorder() {
        guard let color = debugBorderColor else {
            // Remove debug border if color is nil
            debugBorder?.removeFromParent()
            debugBorder = nil
            return
        }

        // Create debug border if it doesn't exist
        if debugBorder == nil {
            let border = SKShapeNode()
            border.name = "debug_border"
            border.strokeColor = color
            border.lineWidth = debugBorderWidth
            border.fillColor = .clear
            border.zPosition = 1000 // Place on top
            addChild(border)
            debugBorder = border
        }

        // Update border properties
        debugBorder?.strokeColor = color
        debugBorder?.lineWidth = debugBorderWidth

        // Update border path based on layoutFrame
        let rect = CGRect(
            x: -layoutFrame.width / 2,
            y: -layoutFrame.height / 2,
            width: layoutFrame.width,
            height: layoutFrame.height
        )
        debugBorder?.path = CGPath(rect: rect, transform: nil)
    }
}
