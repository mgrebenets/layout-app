# LayoutApp - SpriteKit Collection Layout System

A macOS application demonstrating a flexible, protocol-based layout system for SpriteKit that manages collections of nodes with automatic layout invalidation, nesting support, and multiple layout strategies.

## Project Overview

This project implements a collection node system for SpriteKit inspired by UICollectionView's architecture, featuring:

- **Protocol-based design** with `LayoutableNode`, `CollectionNode`, and `ReusableNode`
- **Multiple layout strategies**: Stack, Diagonal, Circular, Grid, DynamicGrid, and Waterfall
- **Automatic layout invalidation and updates**
- **Nested collection support** (collections inside collections)
- **Coordinate space conversion** between UIKit-style (top-left origin) and SpriteKit (center origin)
- **Node pooling/reuse** for performance optimization
- **Relative sizing** with flexible dimension specifications
- **Context menus** for runtime layout configuration

## Architecture

### Core Protocols

Located in `/Nodes/`:

- **`LayoutableNode`**: Protocol for nodes that can be positioned by the layout system
  - Properties: `layoutFrame`, `layoutZIndex`, `layoutDelegate`

- **`CollectionNode`**: Protocol for nodes that manage collections of children
  - Properties: `layout`, `layoutableChildren`
  - Methods: `addLayoutableChild()`, `removeLayoutableChild()`, `invalidateLayout()`, `layoutIfNeeded()`
- **`ReusableNode`**: Protocol for nodes that can be reused from a pool
  - Properties: `reuseIdentifier`
  - Methods: `prepareForReuse()`

### Key Implementation: SKCollectionNode

`SKCollectionNode.swift` in `/Nodes/` is the main implementation that:
- Extends `SKNode` and implements `CollectionNode`, `CollectionLayoutDataSource`, `LayoutableNodeDelegate`
- Manages children in local coordinate space
- Converts from layout coordinates (UIKit-style, top-left origin, Y-down) to SpriteKit local coordinates (center origin, Y-up)
- Acts as its own data source via `numberOfItems` property
- Supports debug borders for visualization
- Uses `layoutableChildren` instead of `children` to avoid SKNode conflicts

### Node Pooling System

The `NodePool` actor (`/LayoutKit/Nodes/NodePool.swift`) provides a generic, thread-safe mechanism for reusing `ReusableNode` instances, significantly reducing memory allocations and improving performance for dynamic collections.


**Important coordinate space behavior:**
- `layoutFrame` represents size only; position is managed via `SKNode.position`
- Children are positioned in local coordinate space relative to the node's origin
- Coordinate conversion happens in `performLayout()`

### Layout Strategies

Located in `/Layout/`:

1. **`StackLayout`**: Linear layout (horizontal/vertical) with alignment options
2. **`DiagonalLayout`**: Diagonal arrangement with configurable alignment
3. **`CircularLayout`**: Arranges items in a circle with angle and radius controls
4. **`GridLayout`**: Classic fixed-cell grid with specified rows and columns
5. **`DynamicGridLayout`**: Grid that calculates columns dynamically based on item size
6. **`WaterfallLayout`**: Pinterest-style masonry layout

All layouts conform to the `CollectionLayout` protocol and use:
- **`LayoutContext`**: Provides bounds and content insets for layout calculations
- **`LayoutAttributes`**: Describes frame and z-index for each item
- **`CollectionLayoutDataSource`**: Provides item count to layouts

### Sizing System

**`RelativeSizing`** (`/Layout/RelativeSizing.swift`) provides flexible dimension specifications:

```swift
// Old API (still supported)
RelativeSizing(baseDimension: .width, containerPercentage: 0.5, aspectRatio: 1.0)

// New API - Independent dimensions
RelativeSizing(
    widthSpec: .containerWidth(percentage: 0.5),
    heightSpec: .containerHeight(percentage: 0.3)
)

// Aspect ratio based on item dimensions
RelativeSizing(
    widthSpec: .containerWidth(percentage: 0.4),
    heightSpec: .itemWidth(percentage: 0.5)  // height = width * 0.5
)
```

Features:
- Each dimension can be based on container width/height, container smallest/largest dimension, or item's own dimensions
- Circular dependency detection (warns and uses fallback size)
- Backward compatible with old API

### Context Menus

Refactored into separate reusable components in `/LayoutApp macOS/ContextMenus/`:

- `StackLayoutMenu.swift` - Single axis alignment controls
- `DiagonalLayoutMenu.swift` - Horizontal/vertical alignment
- `CircularLayoutMenu.swift` - Angle and radius controls
- `DynamicGridLayoutMenu.swift` - 2D alignment controls

Each menu is independent and can be imported and instantiated with configuration.

### Node Coordination System

The `NodeCoordinator` (`/LayoutKit/Coordination/NodeCoordinator.swift`) orchestrates drag-and-drop operations for `LayoutableNode`s between `SKCollectionNode`s. It uses a `NodeCoordinatorDelegate` for policy decisions (e.g., `canTrackNode`, `canMoveNode`) and handles automatic layout updates during interactions.


## Project Structure

```
layout/
├── Nodes/
│   ├── LayoutableNode.swift       # Protocol for layoutable nodes
│   ├── CollectionNode.swift       # Protocol for collection containers
│   ├── ReusableNode.swift         # Protocol for node pooling (planned)
│   ├── SKCollectionNode.swift     # Main collection node implementation
│   └── LayoutableSKShapeNode.swift # SKShapeNode wrapper
├── Layout/
│   ├── CollectionLayout.swift     # Layout protocol
│   ├── CollectionLayoutDataSource.swift
│   ├── LayoutContext.swift        # Layout calculation context
│   ├── LayoutAttributes.swift     # Item positioning/sizing result
│   ├── StackLayout.swift          # Linear layouts
│   ├── DiagonalLayout.swift       # Diagonal arrangements
│   ├── CircularLayout.swift       # Circular arrangements
│   ├── GridLayout.swift           # Fixed grid layout
│   ├── DynamicGridLayout.swift    # Dynamic grid layout
│   ├── WaterfallLayout.swift      # Masonry layout
│   ├── CachedLayout.swift         # Layout caching decorator
│   ├── RelativeSizing.swift       # Flexible sizing system
│   ├── Alignment.swift            # Alignment options
│   ├── Insets.swift               # Content insets
│   └── ZOrder.swift               # Z-ordering strategies
├── LayoutApp macOS/
│   ├── GameScene.swift            # Main SpriteKit scene
│   ├── GameViewController.swift   # View controller (251 lines)
│   └── ContextMenus/              # Reusable menu components
└── plan.md                        # Detailed implementation plan
```

## Development Status

See `plan.md` for comprehensive implementation details and progress tracking.

**Completed Phases:**
- Phase 1: Protocol Foundations
- Phase 2: Basic SKCollectionNode Implementation
- Phase 3: Coordinate Space and Nesting
- Phase 4: GridLayout Implementation
- Phase 6: Migration to SKCollectionNode
- Phase 8: Enhanced RelativeSizing
- Phase 9: Refactor Context Menus

**Deferred:**
- Phase 5: Node Pooling/Reuse System (deferred for future performance optimization)
- Phase 7: Optional Enhancements (debug visualization, logging, validation)

**Known Issues:**
- Context menus don't appear when right-clicking on center collections (diagonal, circular, grid)

## Key Design Decisions

1. **Coordinate Space Separation**: Keep SpriteKit coordinate space internal to collection nodes; GameScene works in UIKit coordinates, collection nodes convert

2. **Insets vs Gaps**:
   - Insets belong to collection nodes (padding around content)
   - Gaps belong to layouts (spacing between items)

3. **Data Source Pattern**: SKCollectionNode acts as its own data source to eliminate redundancy

4. **Layout Invalidation**: Children don't set layoutDelegate on their children to prevent cascading invalidations

5. **Naming Conventions**: Use `layoutableChildren` and `addLayoutableChild()` to avoid conflicts with SKNode's built-in methods

## Building and Running

1. Open `LayoutApp.xcodeproj` in Xcode
2. Select the "LayoutApp macOS" scheme
3. Build and run (Cmd+R)

The application displays multiple layout containers:
- Stack layouts (top, bottom, left, right edges)
- Diagonal layout
- Circular layout
- Nested grid layout with collections inside collections

Right-click on containers to access configuration menus for runtime layout adjustments.

## Future Enhancements

1. **Node Pooling**: Implement reusable node pool for large collections (Phase 5)
2. **Layout Switching**: Support changing layout types at runtime (Phase 3.3)
3. **Debug Tools**: Visual indicators, performance metrics, layout validation (Phase 7)
4. **Fix Context Menus**: Resolve popover issues on center collections

## Contributing

When working on this project:
1. Keep `plan.md` updated with progress and status changes
2. Test each phase independently before moving forward
3. Maintain coordinate space separation between layout system and SpriteKit
4. Use context menus for testing layout configuration changes
5. Consider performance implications for large collections (node pooling)

## Technical Notes

- **Swift Concurrency**: Protocols marked with `Sendable` where appropriate
- **Coordinate Conversion Formula** (layout to SpriteKit local):
  ```swift
  x = attr.frame.minX - localBounds.width / 2
  y = localBounds.height / 2 - attr.frame.maxY
  ```
- **Debug Borders**: Set `debugBorderColor` on SKCollectionNode to visualize layout bounds
- **Layout Caching**: Use `CachedLayout` wrapper to optimize repeated layout calculations
