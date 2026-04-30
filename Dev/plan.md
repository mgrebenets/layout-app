# Collection Node System Implementation Plan

**Note: Keep this document updated as progress is made. Mark completed phases with ✅ and update current status.**

## Overview
Implement a collection node system for SpriteKit that manages layoutable children with:
- Protocol-based design (LayoutableNode, CollectionNode, ReusableNode)
- Automatic layout invalidation and updates
- Support for nesting (collection nodes inside collection nodes)
- **Node pooling/reuse (CRITICAL for performance)**
- Works purely in SpriteKit coordinate space

## Design Principles
- Build on existing layout system (StackLayout, DiagonalLayout, CircularLayout)
- Simple callback-based child observation (delegate pattern)
- Collection nodes manage their own padding/insets
- Layouts handle item-to-item spacing (gaps)
- Each step can be integrated and verified independently

---

## Phase 1: Protocol Foundations ✅ COMPLETED

### Phase 1.1: Create LayoutableNode.swift ✅
- Protocol for nodes that can be positioned by layout system
- Properties: `layoutFrame`, `layoutZIndex`, `layoutDelegate`
- Location: `/Nodes/LayoutableNode.swift`

### Phase 1.2: Create CollectionNode.swift protocol ✅
- Protocol for nodes that manage collections of children
- Properties: `layout`, `layoutableChildren`
- Methods: `addLayoutableChild()`, `removeLayoutableChild()`, `invalidateLayout()`, `layoutIfNeeded()`
- Location: `/Nodes/CollectionNode.swift`

### Phase 1.3: Create ReusableNode.swift protocol ✅
- Protocol for nodes that can be reused from a pool
- Properties: `reuseIdentifier`
- Methods: `prepareForReuse()`
- Location: `/Nodes/ReusableNode.swift`

### Phase 1 Verification ✅
- Build succeeds
- Protocols compile without errors

---

## Phase 2: Basic SKCollectionNode Implementation ✅ COMPLETED

### Phase 2.1: Create SKCollectionNode ✅
- Implements CollectionNode, CollectionLayoutDataSource, LayoutableNodeDelegate
- Manages children in local coordinate space
- Converts from layout coordinates (UIKit-style) to SpriteKit local coordinates
- Acts as its own data source via `numberOfItems` property
- Location: `/Nodes/SKCollectionNode.swift`

**Key Implementation Details:**
- Uses `layoutableChildren` instead of `children` (to avoid SKNode conflict)
- Methods: `addLayoutableChild()`, `removeLayoutableChild()` (to avoid SKNode.addChild ambiguity)
- `layoutFrame` represents size only, position managed via `SKNode.position`
- Converts layout attributes to local coordinate space in `performLayout()`

### Phase 2.2: Create LayoutableSKShapeNode ✅
- Wrapper for SKShapeNode that conforms to LayoutableNode
- Automatically updates path based on layoutFrame
- Location: `/Nodes/LayoutableSKShapeNode.swift`

### Phase 2.3: Integrate one test container ✅
- Replace circular layout container in GameScene with SKCollectionNode
- Verify layout matches existing behavior
- All configuration options still work (right-click menu, etc.)

### Phase 2.4: Migrate all containers ✅
- Migrated diagonal layout to SKCollectionNode
- Migrated stack layouts (top, bottom, left, right) to SKCollectionNode
- Simplified all update methods to just swap layout and call `layoutIfNeeded()`

### Phase 2.5: Remove redundancy ✅
- Removed `LayoutDataSource` class
- SKCollectionNode acts as its own data source
- Container tuples no longer store separate dataSource

### Phase 2 Verification ✅
- All layouts work correctly
- Configuration changes work
- Right-click menus work
- Item count changes work

---

## Phase 3: Coordinate Space and Nesting ✅ COMPLETED

### Phase 3.1: Coordinate space handling ✅ DONE
Already implemented - SKCollectionNode handles UIKit to SpriteKit coordinate conversion in local space.

### Phase 3.2: Nested collection support ✅ DONE
- SKCollectionNode can contain other SKCollectionNodes
- Test: 4 child collections arranged in 2x2 grid, each with 3 diagonal items
- Coordinate transforms work correctly through hierarchy
- Fixed infinite loop in DynamicGridLayout when gaps are 0
- Fixed layoutDelegate circular dependency issue

### Phase 3.3: Layout switching ⏸️ TODO
- Test changing layout type at runtime (e.g., Stack → Circular)
- Ensure no crashes or memory leaks
- Children should maintain their order

### Phase 3 Verification ✅ DONE
- Nested collections render correctly
- Coordinate transforms work through multiple levels
- No infinite loops or circular dependencies

---

## Phase 4: GridLayout Implementation ✅ COMPLETED

### Phase 4.1: Create GridLayout.swift ✅
- Classic fixed-cell grid with specified number of rows and columns
- Properties: `rows`, `columns`, `itemSizing`, `zOrder`
- Unlike DynamicGridLayout (which calculates columns dynamically), GridLayout has fixed grid dimensions
- Items fill cells in row-major order (left-to-right, top-to-bottom)
- Location: `/GridLayout.swift`
- **Fixed**: Moved `GridAlignment` to separate file (`/GridAlignment.swift`) to resolve redeclaration conflict

### Phase 4.2: Use GridLayout for center test ✅
- Replace DynamicGridLayout in nested collections test with GridLayout
- Use 2x2 grid for parent collection
- Verify nested collections render correctly

### Phase 4 Verification ✅
- GridLayout arranges items in fixed grid correctly
- Works with nested collections
- Alignment options work correctly
- **Compilation fixed**: No more `GridAlignment` redeclaration errors

---

## Phase 5: Node Pooling/Reuse System ✅ COMPLETED

**WHY CRITICAL**: Large pool of reusable nodes allocated at start, nodes move between collections without allocation overhead.

### Phase 5.1: Create NodePool.swift ✅
- Generic pool for reusable nodes
- Methods: `dequeue(identifier:)`, `enqueue(node:)`, `clear()`, `poolSize(for:)`
- Maintains separate queues per reuse identifier
- Thread-safe with Swift Actor (no manual locking required)
- Configurable max pool size per identifier
- Pool statistics tracking (created, reused, reuse rate)
- Location: `/LayoutKit/Nodes/NodePool.swift`

### Phase 5.2: Create reusable shape node ✅
- LayoutableSKShapeNode + ReusableNode conformance
- Implements `prepareForReuse()` to reset visual state
- Resets: fillColor, strokeColor, lineWidth, alpha, children, transform, layout properties
- Standard reuse identifier: "LayoutableSKShapeNode"
- Location: `/LayoutKit/Nodes/LayoutableSKShapeNode.swift`

### Phase 5.3: Integrate pool with SKCollectionNode ✅
- Added optional `nodePool` property to SKCollectionNode
- Method `dequeueReusableNode(withIdentifier:create:)` - async method, tries pool first, creates if needed
- Method `recycleAllChildren()` - async method, removes all children and returns them to pool
- Method `recycleChildren(_:)` - async method, removes specific children and returns to pool
- Pool integration is opt-in (works without pool too)
- Location: `/LayoutKit/Nodes/SKCollectionNode.swift`

### Phase 5.4: Documentation ✅
- Created comprehensive pooling guide with async/await examples
- Shows basic usage, complete example, statistics monitoring
- Custom reusable node example
- Best practices and performance impact
- Location: `/LayoutKit/LayoutKit.docc/NodePooling.md`

### Phase 5 Verification ✅
- Build succeeds with no errors
- NodePool is thread-safe via Swift Actor
- Statistics tracking works
- Documentation covers all use cases with async/await patterns
- Ready for integration into app code

---

## Phase 6: Migration ✅ COMPLETED

All containers migrated to SKCollectionNode:
- Stack layouts (top, bottom, left, right)
- Diagonal layout
- Circular layout

---

## Phase 7: Optional Enhancements ⏸️ DEFERRED

### Phase 6.1: Debug visualization ⏸️
- Visual indicators for layout bounds
- Highlight nodes being laid out
- Show coordinate spaces

### Phase 6.2: Layout logging ⏸️
- Log layout calculations
- Performance metrics
- Invalidation tracking

### Phase 6.3: Layout validation ⏸️
- Detect layout cycles
- Warn about excessive invalidations
- Validate frame bounds

---

## Phase 8: Enhanced RelativeSizing ✅ COMPLETED

### Phase 8.1: Flexible dimension specifications ✅
- Replaced single `baseDimension` + `aspectRatio` approach with independent `widthSpec` and `heightSpec`
- Each dimension can be calculated based on:
  - Container width/height with percentage
  - Container smallest/largest dimension with percentage
  - Item's own width/height with percentage (for aspect ratio)
- Location: `/Layout/RelativeSizing.swift`

### Phase 8.2: Circular dependency detection ✅
- Detects when width depends on height and height depends on width
- Logs warning and uses fallback size (100x100)
- Prevents layout failures from invalid configurations

### Phase 8.3: Backward compatibility ✅
- Maintains old `init(baseDimension:containerPercentage:aspectRatio:)` initializer
- Computed properties `baseDimension`, `containerPercentage`, `aspectRatio` extract values from specs
- Existing code continues to work without changes

### Phase 8 Examples:

**Old API (still works):**
```swift
RelativeSizing(baseDimension: .width, containerPercentage: 0.5, aspectRatio: 1.0)
```

**New API - Independent dimensions:**
```swift
// Width = 50% of container width, Height = 30% of container height
RelativeSizing(
    widthSpec: .containerWidth(percentage: 0.5),
    heightSpec: .containerHeight(percentage: 0.3)
)

// Width = 40% of container width, Height maintains 2:1 aspect ratio
RelativeSizing(
    widthSpec: .containerWidth(percentage: 0.4),
    heightSpec: .itemWidth(percentage: 0.5)  // height = width * 0.5
)

// Width based on height, Height based on smallest dimension
RelativeSizing(
    widthSpec: .itemHeight(percentage: 1.5),  // width = height * 1.5
    heightSpec: .containerSmallest(percentage: 0.3)
)
```

### Phase 8 Verification ✅
- Build succeeds
- All existing layouts continue to work
- UI menus still function correctly
- New flexible API available for future use

---

## Phase 9: Refactor Context Menus ✅ COMPLETED

### Phase 9.1: Extract menu components ✅
- Created separate reusable menu files in `LayoutApp macOS/ContextMenus/`:
  - `StackLayoutMenu.swift` - For stack layouts with single axis alignment
  - `DiagonalLayoutMenu.swift` - For diagonal layouts with horizontal/vertical alignment
  - `CircularLayoutMenu.swift` - For circular layouts with angle and radius controls
  - `DynamicGridLayoutMenu.swift` - For dynamic grid layouts with 2D alignment
- Each menu is now independent and reusable

### Phase 9.2: Simplify GameViewController ✅
- Reduced GameViewController from 1184 lines to 251 lines
- Removed all embedded menu view definitions
- GameViewController now only handles popover presentation
- Menus are imported and instantiated with configuration

### Phase 9 Verification ✅
- Build succeeds
- All menu types work correctly
- Code is now more maintainable and organized

---

## Phase 10: Snapshot-Based Layout Tests ✅ COMPLETED

### Phase 10.1: Set up snapshot testing framework ✅
- Integrated swift-snapshot-testing library
- Configured test target for macOS
- Created test infrastructure for rendering SKCollectionNode to images
- Location: Test target in Xcode project

### Phase 10.2: Create baseline snapshots ✅
- Generated reference snapshots for each layout type:
  - StackLayout (horizontal and vertical)
  - DiagonalLayout
  - CircularLayout
  - GridLayout
  - DynamicGridLayout
  - WaterfallLayout
- Tested various configurations (alignment, gaps, insets, item counts)
- Tested nested collections
- Stored baselines in version control

### Phase 10.3: Create layout test cases ✅
- Test fixed sizing vs relative sizing
- Test different alignment options
- Test edge cases (zero items, single item, many items)
- Test coordinate conversion accuracy
- Test z-ordering

### Phase 10.4: Integration with CI ✅
- Added snapshot tests to build scheme
- Configured CI to fail on snapshot mismatches
- Documented how to update snapshots when layout changes are intentional

### Phase 10 Verification ✅
- All layouts have snapshot test coverage
- Tests catch layout regressions
- Tests pass consistently across runs
- Clear documentation for maintaining snapshots

---

## Current Status

**Last Updated**: Phase 10 completed - Snapshot-based layout tests fully implemented

**What Works**:
- ✅ All layout types (Stack, Diagonal, Circular, Grid, DynamicGrid, Waterfall) use SKCollectionNode
- ✅ SKCollectionNode acts as its own data source
- ✅ Coordinate conversion handled correctly
- ✅ Configuration menus work
- ✅ Item count changes work
- ✅ All update methods simplified
- ✅ Nested collections with GridLayout
- ✅ Flexible RelativeSizing with independent dimension specs
- ✅ Circular dependency detection in sizing
- ✅ Context menus refactored into separate reusable files
- ✅ Node pooling system fully implemented with Swift Actor (async/await)
- ✅ Snapshot testing for all layout types

**Next Steps**:
1. **Phase 3.3**: Test layout switching (optional, if needed)
2. **Phase 7**: Optional enhancements (debug visualization, logging, validation) - deferred

**Known Issues**:
- None currently tracked

---

## Notes

- Keep SpriteKit coordinate space internal to collection nodes
- GameScene works in UIKit coordinates, collection nodes convert
- Insets belong to collection nodes, gaps belong to layouts
- Always test each phase before moving to the next
