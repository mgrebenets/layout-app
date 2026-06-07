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
    private var highlighted = false   // a legal candidate — outlined to invite a click
    private var selected = false      // the picked candidate — lifts and outlines strongly

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
        let radius = size.width * 0.10
        body.path = CGPath(roundedRect: CGRect(x: -size.width / 2, y: -size.height / 2,
                                                width: size.width, height: size.height),
                           cornerWidth: radius, cornerHeight: radius, transform: nil)
        body.lineWidth = max(1.5, size.width * 0.026)
        // Fonts and corner insets scale with the card so it stays proportional at any size (the
        // ratios reproduce the original 78×108 look — ~23 / ~15 pt, inset 5 / 4).
        centerLabel.fontSize = max(12, size.width * 0.30)
        cornerLabel.fontSize = max(9, size.width * 0.19)
        cornerLabel2.fontSize = cornerLabel.fontSize
        cornerLabel.position = CGPoint(x: -size.width / 2 + size.width * 0.064, y: size.height / 2 - size.height * 0.037)
        cornerLabel2.position = CGPoint(x: size.width / 2 - size.width * 0.064, y: -size.height / 2 + size.height * 0.037)
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
            let color: SKColor = face.isRed ? .systemRed : .black
            for label in [centerLabel, cornerLabel, cornerLabel2] {
                label.text = face.text
                label.fontColor = color
                label.isHidden = false
            }
        } else {
            body.fillColor = SKColor(red: 0.16, green: 0.30, blue: 0.62, alpha: 1.0)
            for label in [centerLabel, cornerLabel, cornerLabel2] { label.isHidden = true }
        }
        applyStroke() // outline reflects highlight/selection; lift is owned by setSelected
    }

    /// Outline a card to mark it a legal candidate. Purely cosmetic — does not move the card.
    public func setHighlighted(_ on: Bool) {
        guard highlighted != on else { return }
        highlighted = on
        applyStroke()
    }

    /// Pick a card: it lifts up and takes a strong outline so the choice is obvious before commit.
    /// The lift animates over `duration` (pass 0 for an instant set, e.g. on resize or in tests).
    public func setSelected(_ on: Bool, duration: TimeInterval) {
        guard selected != on else { return }
        selected = on
        applyStroke()
        let liftedY = selected ? cardSize.height * 0.18 : 0
        body.removeAction(forKey: "lift")
        if duration > 0 {
            body.run(.moveTo(y: liftedY, duration: duration), withKey: "lift")
        } else {
            body.position.y = liftedY
        }
    }

    /// Stroke colour/width by state (selected > highlighted > plain). Instant — no motion involved,
    /// so re-asserting it from `applyFace` never disturbs an in-flight lift on `body`.
    private func applyStroke() {
        switch (selected, highlighted) {
        case (true, _):
            body.strokeColor = .systemYellow
            body.lineWidth = 4
        case (false, true):
            body.strokeColor = .systemTeal
            body.lineWidth = 3
        case (false, false):
            body.strokeColor = faceUp ? .darkGray : .white
            body.lineWidth = 2
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
