//
//  CardTableNode.swift
//  LayoutKit
//
//  Owns durable CardNodes keyed by an Int id and animates them toward a target layout. Each render
//  is "here is where every card should now be" — cards glide/flip/rotate to their new placement, so
//  deals/moves/sweeps are visible. Game-agnostic: the caller supplies placements and a face lookup.
//

import SpriteKit

public struct CardPlacement: Equatable {
    public var position: CGPoint
    public var zRotation: CGFloat
    public var zPosition: CGFloat
    public var size: CGSize
    public var faceUp: Bool
    public var highlighted: Bool   // a legal candidate — outlined
    public var selected: Bool      // the picked candidate — lifted + outlined

    public init(position: CGPoint,
                zRotation: CGFloat = 0,
                zPosition: CGFloat = 0,
                size: CGSize = CGSize(width: 80, height: 112),
                faceUp: Bool = false,
                highlighted: Bool = false,
                selected: Bool = false) {
        self.position = position
        self.zRotation = zRotation
        self.zPosition = zPosition
        self.size = size
        self.faceUp = faceUp
        self.highlighted = highlighted
        self.selected = selected
    }
}

public final class CardTableNode: SKNode {

    private var nodes: [Int: CardNode] = [:]
    public var faceProvider: (Int) -> CardFaceView? = { _ in nil }

    public override init() { super.init() }
    public required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    /// Drop all cards (e.g. between rounds).
    public func reset() {
        for node in nodes.values { node.removeFromParent() }
        nodes.removeAll()
    }

    /// The durable node for a card id, if present — lets a scene drag it directly between `apply`s.
    public func node(_ id: Int) -> CardNode? { nodes[id] }

    /// Animate every card to its placement over `duration`; cards no longer placed fade out.
    /// `completion` fires once after `duration`.
    public func apply(_ placements: [Int: CardPlacement], duration: TimeInterval, completion: @escaping () -> Void) {
        for (id, node) in nodes where placements[id] == nil {
            node.run(.sequence([.fadeOut(withDuration: duration), .removeFromParent()]))
            nodes[id] = nil
        }
        for (id, placement) in placements {
            let node: CardNode
            if let existing = nodes[id] {
                node = existing
            } else {
                node = CardNode()
                node.name = "card_\(id)"
                node.position = placement.position
                node.zRotation = placement.zRotation
                node.setFace(faceProvider(id), faceUp: placement.faceUp)
                addChild(node)
                nodes[id] = node
            }
            node.configure(size: placement.size)
            node.setLayer(placement.zPosition)
            node.setHighlighted(placement.highlighted)
            node.setSelected(placement.selected, duration: duration)
            if node.faceUp != placement.faceUp {
                node.flip(to: placement.faceUp, face: faceProvider(id), duration: duration)
            } else {
                node.setFace(faceProvider(id), faceUp: placement.faceUp)
            }
            node.run(.group([
                .move(to: placement.position, duration: duration),
                .rotate(toAngle: placement.zRotation, duration: duration, shortestUnitArc: true),
            ]))
        }
        run(.sequence([.wait(forDuration: duration), .run(completion)]))
    }
}
