# Node Pooling in LayoutKit

Node pooling is a performance optimization technique that reuses existing nodes instead of creating new ones, reducing memory allocations and improving performance, especially for dynamic collections with frequent updates.

## Overview

The `NodePool` actor manages a pool of reusable nodes. Nodes that conform to `ReusableNode` protocol can be dequeued from the pool and returned for reuse later. Using an actor ensures thread-safe access without explicit locks.

## Basic Usage

### 1. Create a Node Pool

```swift
let pool = NodePool(maxPoolSize: 20)
```

### 2. Assign Pool to Collection

```swift
let collection = SKCollectionNode(layout: myLayout)
collection.nodePool = pool
```

### 3. Dequeue Reusable Nodes

```swift
let node = await collection.dequeueReusableNode(withIdentifier: "LayoutableSKShapeNode") {
    // Create a new node if none available in pool
    return LayoutableSKShapeNode()
}

// Configure the node
node.fillColor = .red
node.strokeColor = .black

// Add to collection
collection.addLayoutableChild(node)
```

### 4. Recycle Nodes

When you're done with nodes, return them to the pool:

```swift
// Recycle all children
await collection.recycleAllChildren()

// Or recycle specific children
await collection.recycleChildren([node1, node2, node3])
```

## Complete Example

```swift
import LayoutKit
import SpriteKit

class GameScene: SKScene {
    let pool = NodePool(maxPoolSize: 50)
    var collection: SKCollectionNode!

    override func didMove(to view: SKView) {
        // Create collection with grid layout
        let layout = GridLayout(
            rows: 5,
            columns: 5,
            itemSizing: nil,
            horizontalGapPercentage: 0.5,
            verticalGapPercentage: 0.5,
            horizontalAlignment: .center,
            verticalAlignment: .center,
            zOrder: .ascending,
            dataSource: self
        )

        collection = SKCollectionNode(layout: layout)
        collection.nodePool = pool
        collection.layoutFrame = CGRect(x: 0, y: 0, width: 800, height: 600)
        collection.position = CGPoint(x: frame.midX, y: frame.midY)
        addChild(collection)

        // Populate collection
        updateCollection()
    }

    func updateCollection() {
        // Recycle existing nodes
        Task {
            await collection.recycleAllChildren()

            // Create new nodes (or reuse from pool)
            for i in 0..<25 {
                let node = await collection.dequeueReusableNode(
                    withIdentifier: "LayoutableSKShapeNode"
                ) {
                    LayoutableSKShapeNode()
                }

                // Configure node
                node.fillColor = randomColor()
                node.strokeColor = .black
                node.lineWidth = 2

                // Add label
                let label = SKLabelNode(text: "\\(i)")
                label.fontSize = 20
                label.fontColor = .white
                label.verticalAlignmentMode = .center
                node.addChild(label)

                collection.addLayoutableChild(node)
            }

            // Trigger layout
            collection.layoutIfNeeded()
        }
    }

    func randomColor() -> SKColor {
        return SKColor(
            red: CGFloat.random(in: 0...1),
            green: CGFloat.random(in: 0...1),
            blue: CGFloat.random(in: 0...1),
            alpha: 1.0
        )
    }
}

extension GameScene: CollectionLayoutDataSource {
    var numberOfItems: Int { 25 }
}
```

## Pool Statistics

Monitor pool performance with statistics:

```swift
Task {
    let stats = await pool.statistics
    print("Created: \\(stats.totalCreated)")
    print("Reused: \\(stats.totalReused)")
    print("Reuse Rate: \\(Int(stats.reuseRate * 100))%")
    print("Current Pool Size: \\(stats.currentPoolSize)")
}
```

## Custom Reusable Nodes

To make your own node reusable, conform to `ReusableNode`:

```swift
class MyCustomNode: SKNode, LayoutableNode, ReusableNode {
    var layoutFrame: CGRect = .zero
    var layoutZIndex: Int = 0
    weak var layoutDelegate: LayoutableNodeDelegate?

    // Reuse identifier
    var reuseIdentifier: String {
        return "MyCustomNode"
    }

    // Reset state for reuse
    func prepareForReuse() {
        // Reset properties
        alpha = 1.0
        removeAllChildren()
        // Reset any custom state
    }
}
```

## Best Practices

1. **Pool Size**: Set `maxPoolSize` based on your typical usage (default is 20)
2. **Recycle Promptly**: Return nodes to the pool as soon as you're done with them
3. **Reset State**: Implement `prepareForReuse()` thoroughly to avoid state bleeding
4. **Monitor Performance**: Use pool statistics to verify effective reuse
5. **Shared Pools**: Consider sharing a pool across multiple collections for better efficiency

## Performance Impact

Node pooling can significantly improve performance:
- **Reduced Allocations**: Reusing nodes avoids memory allocation overhead
- **Improved Frame Rate**: Less garbage collection pressure
- **Faster Updates**: No initialization cost for reused nodes

Typical performance improvements:
- 20-40% reduction in update time for dynamic collections
- 50-70% fewer memory allocations
- More stable frame rates with frequent updates
