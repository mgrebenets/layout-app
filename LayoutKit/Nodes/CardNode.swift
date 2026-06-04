//
//  CardNode.swift
//  LayoutKit
//
//  A durable card view: one per card id, persists across states so it can be animated (moved,
//  rotated, flipped) instead of rebuilt. Game-agnostic — it shows a `CardFaceView` (display text +
//  colour) or a back. See `CardTableNode` for layering/animation.
//

import SpriteKit

/// What to draw on a card's face — decoupled from any game's card type.
public struct CardFaceView: Equatable {
    public var text: String   // e.g. "A♠", "10♥"
    public var isRed: Bool
    public init(text: String, isRed: Bool) {
        self.text = text
        self.isRed = isRed
    }
}

public final class CardNode: SKNode {

    private let body = SKShapeNode()
    private let centerLabel = SKLabelNode(text: "")
    private let cornerLabel = SKLabelNode(text: "")   // top-left, upright
    private let cornerLabel2 = SKLabelNode(text: "")  // bottom-right, upside down
    private var cardSize = CGSize(width: 80, height: 112)
    private var face: CardFaceView?
    public private(set) var faceUp = false

    public override init() {
        super.init()
        addChild(body)
        body.addChild(centerLabel)
        body.addChild(cornerLabel)
        body.addChild(cornerLabel2)
        for label in [centerLabel, cornerLabel, cornerLabel2] {
            label.fontName = "Menlo-Bold"
            label.zPosition = 0.1
        }
        centerLabel.verticalAlignmentMode = .center
        centerLabel.horizontalAlignmentMode = .center
        cornerLabel.verticalAlignmentMode = .top
        cornerLabel.horizontalAlignmentMode = .left
        // Mirror of the top-left pip through the card centre → bottom-right, reading upside down.
        cornerLabel2.verticalAlignmentMode = .top
        cornerLabel2.horizontalAlignmentMode = .left
        cornerLabel2.zRotation = .pi
        configure(size: cardSize)
    }

    public required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    public func configure(size: CGSize) {
        cardSize = size
        body.path = CGPath(roundedRect: CGRect(x: -size.width / 2, y: -size.height / 2,
                                                width: size.width, height: size.height),
                           cornerWidth: 8, cornerHeight: 8, transform: nil)
        body.lineWidth = 2
        centerLabel.fontSize = max(12, min(24, size.width * 0.30))
        cornerLabel.fontSize = max(10, min(15, size.width * 0.22))
        cornerLabel2.fontSize = cornerLabel.fontSize
        cornerLabel.position = CGPoint(x: -size.width / 2 + 5, y: size.height / 2 - 4)
        cornerLabel2.position = CGPoint(x: size.width / 2 - 5, y: -size.height / 2 + 4)
        applyFace()
    }

    public func setFace(_ face: CardFaceView?, faceUp: Bool) {
        self.face = face
        self.faceUp = faceUp
        applyFace()
    }

    private func applyFace() {
        if faceUp, let face {
            body.fillColor = .white
            body.strokeColor = .darkGray
            let color: SKColor = face.isRed ? .systemRed : .black
            for label in [centerLabel, cornerLabel, cornerLabel2] {
                label.text = face.text
                label.fontColor = color
                label.isHidden = false
            }
        } else {
            body.fillColor = SKColor(red: 0.16, green: 0.30, blue: 0.62, alpha: 1.0)
            body.strokeColor = .white
            for label in [centerLabel, cornerLabel, cornerLabel2] { label.isHidden = true }
        }
    }

    /// Put this card on a layer. SpriteKit z is additive down the hierarchy, so the band goes on the
    /// node itself while children keep *small relative* offsets — otherwise a back card's labels
    /// (large absolute z) add up to sit above a front card's body. Cards must be spaced ≥1 apart.
    public func setLayer(_ base: CGFloat) {
        zPosition = base // children keep their small relative z set in init/configure
    }

    /// Flip to a new face over `duration`, swapping the artwork at the midpoint.
    public func flip(to faceUp: Bool, face: CardFaceView?, duration: TimeInterval) {
        let half = duration / 2
        body.run(.sequence([
            .scaleX(to: 0, duration: half),
            .run { [weak self] in self?.setFace(face, faceUp: faceUp) },
            .scaleX(to: 1, duration: half),
        ]))
    }
}
