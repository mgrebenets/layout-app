import Foundation
import Testing
import SpriteKit
@testable import LayoutKit

@MainActor
@Suite("NodeCoordinator Tests")
struct NodeCoordinatorTests {

    // MARK: - Fixture

    /// Source: 100x200 at scene (200, 300). Children sized 100x40 (3 stacked vertically).
    /// Target: 200x200 at scene (600, 300). Empty. Children would be sized 200x80 (different).
    private struct Fixture {
        let scene: SKScene
        let source: SKCollectionNode
        let target: SKCollectionNode
        let coordinator: NodeCoordinator
        let delegate: RecordingDelegate

        var sourceShapes: [LayoutableSKShapeNode] {
            source.layoutableChildren.compactMap { $0 as? LayoutableSKShapeNode }
        }

        var targetShapes: [LayoutableSKShapeNode] {
            target.layoutableChildren.compactMap { $0 as? LayoutableSKShapeNode }
        }
    }

    private func makeFixture(sourceItemCount: Int = 3) -> Fixture {
        let scene = SKScene(size: CGSize(width: 800, height: 600))

        let source = makeCollection(
            widthPercent: 1.0,
            heightPercent: 0.2,
            sceneSize: CGSize(width: 100, height: 200),
            scenePosition: CGPoint(x: 200, y: 300),
            in: scene
        )
        for _ in 0..<sourceItemCount {
            source.addLayoutableChild(makeShapeNode())
        }
        source.layoutIfNeeded()

        let target = makeCollection(
            widthPercent: 1.0,
            heightPercent: 0.4,
            sceneSize: CGSize(width: 200, height: 200),
            scenePosition: CGPoint(x: 600, y: 300),
            in: scene
        )
        target.layoutIfNeeded()

        let coordinator = NodeCoordinator()
        let delegate = RecordingDelegate()
        coordinator.delegate = delegate
        coordinator.setParentContainer(scene)
        coordinator.register(collection: source)
        coordinator.register(collection: target)

        return Fixture(
            scene: scene,
            source: source,
            target: target,
            coordinator: coordinator,
            delegate: delegate
        )
    }

    private func makeCollection(
        widthPercent: CGFloat,
        heightPercent: CGFloat,
        sceneSize: CGSize,
        scenePosition: CGPoint,
        in scene: SKScene
    ) -> SKCollectionNode {
        let sizing = RelativeSizing(
            widthSpec: .containerWidth(percentage: widthPercent),
            heightSpec: .containerHeight(percentage: heightPercent)
        )
        let collection = SKCollectionNode(
            layoutBuilder: { dataSource in
                StackLayout(
                    axis: .vertical,
                    itemSizing: sizing,
                    itemSpacing: 0,
                    gapPercentage: 1.0, // touching (gap=0 means complete overlap in StackLayout)
                    alignment: .leading,
                    zOrder: .ascending,
                    dataSource: dataSource
                )
            },
            contentInsets: Insets(uniform: 0)
        )
        collection.position = scenePosition
        scene.addChild(collection)
        collection.layoutFrame = CGRect(origin: .zero, size: sceneSize)
        return collection
    }

    private func makeShapeNode() -> LayoutableSKShapeNode {
        let node = LayoutableSKShapeNode()
        node.fillColor = .red
        node.strokeColor = .black
        node.lineWidth = 1
        return node
    }

    // MARK: - Membership / parent pointer

    @Test("Drop on a different collection moves the node to the target")
    func dropOnDifferentCollectionMovesNode() {
        let f = makeFixture()
        let dragged = f.sourceShapes[1]
        let pickUp = f.scene.convert(.zero, from: dragged)
        let drop = f.target.position

        f.coordinator.handleTouchBegan(at: pickUp, in: f.scene)
        f.coordinator.handleTouchMoved(to: drop)
        f.coordinator.handleTouchEnded(at: drop)

        #expect(f.targetShapes.contains { $0 === dragged })
        #expect(!f.sourceShapes.contains { $0 === dragged })
        #expect(dragged.parent === f.target)
        #expect(f.coordinator.isTracking == false)
    }

    @Test("Drop in empty space returns the node to its source at the original index")
    func dropInEmptySpaceReturnsToOriginalIndex() {
        let f = makeFixture()
        let dragged = f.sourceShapes[1]
        let pickUp = f.scene.convert(.zero, from: dragged)
        let emptyPoint = CGPoint(x: 400, y: 100) // outside both collections

        f.coordinator.handleTouchBegan(at: pickUp, in: f.scene)
        f.coordinator.handleTouchMoved(to: emptyPoint)
        f.coordinator.handleTouchEnded(at: emptyPoint)

        #expect(f.sourceShapes.count == 3)
        #expect(f.sourceShapes[1] === dragged)
        #expect(dragged.parent === f.source)
    }

    @Test("Touch ended without leaving source bounds leaves membership unchanged")
    func tapInsideSourceLeavesMembershipUnchanged() {
        let f = makeFixture()
        let dragged = f.sourceShapes[1]
        let pickUp = f.scene.convert(.zero, from: dragged)

        f.coordinator.handleTouchBegan(at: pickUp, in: f.scene)
        f.coordinator.handleTouchEnded(at: pickUp)

        #expect(f.sourceShapes.count == 3)
        #expect(f.sourceShapes[1] === dragged)
        #expect(dragged.parent === f.source)
    }

    // MARK: - Delegate policy

    @Test("canTrackNode veto prevents tracking")
    func canTrackVetoBlocksTracking() {
        let f = makeFixture()
        f.delegate.canTrack = false
        let dragged = f.sourceShapes[1]
        let pickUp = f.scene.convert(.zero, from: dragged)

        f.coordinator.handleTouchBegan(at: pickUp, in: f.scene)

        #expect(f.coordinator.isTracking == false)
        #expect(f.sourceShapes[1] === dragged)
    }

    @Test("canMoveNode veto returns the node to source despite a drop on target")
    func canMoveVetoReturnsNodeToSource() {
        let f = makeFixture()
        f.delegate.canMove = false
        let dragged = f.sourceShapes[1]
        let pickUp = f.scene.convert(.zero, from: dragged)
        let drop = f.target.position

        f.coordinator.handleTouchBegan(at: pickUp, in: f.scene)
        f.coordinator.handleTouchMoved(to: drop)
        f.coordinator.handleTouchEnded(at: drop)

        #expect(!f.targetShapes.contains { $0 === dragged })
        #expect(f.sourceShapes.contains { $0 === dragged })
        #expect(dragged.parent === f.source)
    }

    @Test("Tracking and reset transformations are invoked once each across a drag cycle")
    func trackAndResetInvokedOnce() {
        let f = makeFixture()
        let dragged = f.sourceShapes[1]
        let pickUp = f.scene.convert(.zero, from: dragged)
        let drop = f.target.position

        f.coordinator.handleTouchBegan(at: pickUp, in: f.scene)
        f.coordinator.handleTouchMoved(to: drop)
        f.coordinator.handleTouchEnded(at: drop)

        #expect(f.delegate.trackingTransformInvocations == 1)
        #expect(f.delegate.resetTransformInvocations == 1)
    }

    // MARK: - Sizing invariants (the regressions Max has seen)

    @Test("Free node retains source-sized geometry mid-drag")
    func freeNodeKeepsSourceSizeDuringDrag() {
        let f = makeFixture()
        let dragged = f.sourceShapes[1]
        let originalSize = dragged.layoutFrame.size
        #expect(originalSize == CGSize(width: 100, height: 40))

        let pickUp = f.scene.convert(.zero, from: dragged)
        let drag = CGPoint(x: 400, y: 100)
        f.coordinator.handleTouchBegan(at: pickUp, in: f.scene)
        f.coordinator.handleTouchMoved(to: drag)

        // Node is now free (parented to the scene). Its layoutFrame must be unchanged.
        #expect(dragged.parent === f.scene)
        #expect(dragged.layoutFrame.size == originalSize)
        // Path bounding box reflects the size too — guards against shape-not-redrawn bugs.
        #expect(dragged.path?.boundingBox.size.width == originalSize.width)
        #expect(dragged.path?.boundingBox.size.height == originalSize.height)
    }

    @Test("Node dropped into a different-sized target adopts target's sizing rule")
    func dropAdoptsTargetSizing() {
        let f = makeFixture()
        let dragged = f.sourceShapes[1]
        #expect(dragged.layoutFrame.size == CGSize(width: 100, height: 40))

        let pickUp = f.scene.convert(.zero, from: dragged)
        let drop = f.target.position
        f.coordinator.handleTouchBegan(at: pickUp, in: f.scene)
        f.coordinator.handleTouchMoved(to: drop)
        f.coordinator.handleTouchEnded(at: drop)

        // Target sizes children at containerWidth*1.0 x containerHeight*0.4 = 200 x 80.
        #expect(dragged.layoutFrame.size == CGSize(width: 200, height: 80))
        #expect(dragged.path?.boundingBox.size.width == 200)
        #expect(dragged.path?.boundingBox.size.height == 80)
    }

    @Test("Return-to-source after drag preserves source sizing")
    func returnToSourcePreservesSize() {
        let f = makeFixture()
        let dragged = f.sourceShapes[1]
        let originalSize = dragged.layoutFrame.size

        let pickUp = f.scene.convert(.zero, from: dragged)
        let emptyPoint = CGPoint(x: 400, y: 100)
        f.coordinator.handleTouchBegan(at: pickUp, in: f.scene)
        f.coordinator.handleTouchMoved(to: emptyPoint)
        f.coordinator.handleTouchEnded(at: emptyPoint)

        #expect(dragged.layoutFrame.size == originalSize)
        #expect(dragged.path?.boundingBox.size.width == originalSize.width)
        #expect(dragged.path?.boundingBox.size.height == originalSize.height)
    }
}

// MARK: - Recording delegate

@MainActor
private final class RecordingDelegate: NodeCoordinatorDelegate {
    var canTrack = true
    var canMove = true
    var trackingTransformInvocations = 0
    var resetTransformInvocations = 0

    func nodeCoordinator(
        _ coordinator: NodeCoordinator,
        canTrackNode node: LayoutableNode,
        inCollection sourceCollection: SKCollectionNode
    ) -> Bool {
        canTrack
    }

    func nodeCoordinator(
        _ coordinator: NodeCoordinator,
        canMoveNode node: LayoutableNode,
        from sourceCollection: SKCollectionNode,
        to targetCollection: SKCollectionNode
    ) -> Bool {
        canMove
    }

    func nodeCoordinator(
        _ coordinator: NodeCoordinator,
        trackingTransformationFor node: LayoutableNode
    ) -> ((SKNode) -> Void)? {
        return { [weak self] _ in
            self?.trackingTransformInvocations += 1
        }
    }

    func nodeCoordinator(
        _ coordinator: NodeCoordinator,
        resetTransformationFor node: LayoutableNode
    ) -> ((SKNode) -> Void)? {
        return { [weak self] _ in
            self?.resetTransformInvocations += 1
        }
    }
}
