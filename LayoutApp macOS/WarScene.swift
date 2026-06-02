//
//  WarScene.swift
//  LayoutApp macOS
//
//  A playable War scene driven by GameEngine's WarGame. Every deal, comparison, war, and win comes
//  from the engine; this scene renders state and feeds clicks back as the forced move.
//
//  - Rules are editable on the fly via two pills at the top (war face-down count 1–3, and
//    fixed/shuffled winnings). Changing them rebuilds the WarGame with new rules; the in-progress
//    game continues under them.
//  - The engine's `advance` steps one beat at a time, so wars are watchable: a tied pair lays its
//    face-down + face-up cards, held on the table, and resolves on the next click.
//  - Each played pile is an SKCollectionNode with a horizontal StackLayout, so the war cards fan
//    out side by side instead of stacking.
//

import SpriteKit
import GameEngine
import LayoutKit

final class WarScene: SKScene {

    private var rules = WarRules()
    private var game = WarGame()
    private var state: WarState!

    private enum Phase { case awaitingPlay, awaitingResolution }
    private var phase: Phase = .awaitingPlay

    private let seat0 = SeatID(0) // bottom — "You"
    private let seat1 = SeatID(1) // top — "Opponent"

    private let tableNode = SKNode()
    private let controlsNode = SKNode()
    private let statusLabel = SKLabelNode()
    private let hintLabel = SKLabelNode()

    private func stock(_ seat: SeatID) -> ZoneID { ZoneID("stock", owner: seat) }
    private func played(_ seat: SeatID) -> ZoneID { ZoneID("played", owner: seat) }

    // MARK: - Lifecycle

    override func didMove(to view: SKView) {
        scaleMode = .resizeFill
        backgroundColor = SKColor(red: 0.10, green: 0.35, blue: 0.18, alpha: 1.0)
        anchorPoint = .zero

        addChild(tableNode)
        addChild(controlsNode)
        configure(statusLabel, size: 22, font: "AvenirNext-DemiBold")
        configure(hintLabel, size: 14, font: "AvenirNext-Regular", alpha: 0.7)
        addChild(statusLabel)
        addChild(hintLabel)

        startNewGame()
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        guard state != nil else { return }
        render()
    }

    private func startNewGame() {
        game = WarGame(rules: rules)
        state = game.setup(seatCount: 2, seed: UInt64.random(in: UInt64.min...UInt64.max))
        phase = .awaitingPlay
        render()
    }

    // MARK: - Input

    override func mouseDown(with event: NSEvent) {
        let location = event.location(in: self)
        let hit = nodes(at: location)
        if hit.contains(where: { $0.name == "ctrl_warcount" }) { cycleWarCount(); return }
        if hit.contains(where: { $0.name == "ctrl_shuffle" }) { toggleShuffle(); return }
        if hit.contains(where: { $0.name == "ctrl_twobeatsace" }) { toggleTwoBeatsAce(); return }
        step()
    }

    private func cycleWarCount() {
        rules.warFaceDownCount = rules.warFaceDownCount % 3 + 1 // 1 → 2 → 3 → 1
        game = WarGame(rules: rules)
        render()
    }

    private func toggleShuffle() {
        rules.shuffleWinnings.toggle()
        game = WarGame(rules: rules)
        render()
    }

    private func toggleTwoBeatsAce() {
        rules.twoBeatsAce.toggle()
        game = WarGame(rules: rules)
        render()
    }

    /// One click = play both cards (if a comparison isn't already pending), or process one
    /// resolution beat (a war lay-down or a sweep).
    private func step() {
        if game.outcome(state) != nil { startNewGame(); return }

        switch phase {
        case .awaitingPlay:
            var guardCount = 0
            while !comparisonPending {
                let seat = state.core.currentSeat
                guard let move = game.legalMoves(for: seat, in: state).first else { break }
                fold(game.lower(move, in: state))
                settleTurnHandoffs()
                guardCount += 1
                if guardCount > 1000 { break }
            }
            if comparisonPending { phase = .awaitingResolution }

        case .awaitingResolution:
            fold(game.advance(state)) // one card-moving batch: war lay-down or resolution
            settleTurnHandoffs()
            phase = comparisonPending ? .awaitingResolution : .awaitingPlay
        }
        render()
    }

    // MARK: - Engine stepping

    private func fold(_ effects: [Effect<WarEffect>]) {
        for case let .core(coreEffect) in effects {
            state.core.apply(coreEffect)
        }
    }

    /// Apply purely administrative `advance` batches (turn hand-offs) immediately, leaving any
    /// card-moving batch (war lay-down / sweep) for a deliberate click.
    private func settleTurnHandoffs() {
        var guardCount = 0
        while true {
            let batch = game.advance(state)
            if batch.isEmpty || batchMovesCards(batch) { return }
            fold(batch)
            guardCount += 1
            if guardCount > 1000 { return }
        }
    }

    private func batchMovesCards(_ batch: [Effect<WarEffect>]) -> Bool {
        for case let .core(coreEffect) in batch {
            switch coreEffect {
            case .move, .moveToBottom: return true
            default: continue
            }
        }
        return false
    }

    private var comparisonPending: Bool {
        let p0 = state.core[played(seat0)]?.count ?? 0
        let p1 = state.core[played(seat1)]?.count ?? 0
        return p0 == p1 && p0 >= 1
    }

    // MARK: - Rendering

    private func render() {
        tableNode.removeAllChildren()
        controlsNode.removeAllChildren()

        drawSeat(seat1, name: "Opponent", rowY: size.height * 0.70)
        drawSeat(seat0, name: "You", rowY: size.height * 0.30)

        statusLabel.position = CGPoint(x: size.width / 2, y: size.height / 2)
        statusLabel.text = statusText()
        hintLabel.position = CGPoint(x: size.width / 2, y: size.height / 2 - 26)
        hintLabel.text = hintText()

        controlsNode.addChild(controlPill("War cards: \(rules.warFaceDownCount)",
                                          name: "ctrl_warcount",
                                          at: CGPoint(x: size.width / 2 - 200, y: size.height - 30)))
        controlsNode.addChild(controlPill("Winnings: \(rules.shuffleWinnings ? "Shuffled" : "Fixed")",
                                          name: "ctrl_shuffle",
                                          at: CGPoint(x: size.width / 2, y: size.height - 30)))
        controlsNode.addChild(controlPill("2 beats A: \(rules.twoBeatsAce ? "On" : "Off")",
                                          name: "ctrl_twobeatsace",
                                          at: CGPoint(x: size.width / 2 + 200, y: size.height - 30)))
    }

    private func drawSeat(_ seat: SeatID, name: String, rowY: CGFloat) {
        let centerX = size.width / 2
        let stockX = centerX - 210
        let playedCenterX = centerX + 70
        let playedWidth = size.width * 0.42

        let stockCount = state.core[stock(seat)]?.count ?? 0
        if stockCount > 0 {
            let back = makeCardNode(face: nil, faceUp: false)
            back.layoutFrame = CGRect(x: 0, y: 0, width: 86, height: 120)
            back.position = CGPoint(x: stockX, y: rowY)
            tableNode.addChild(back)
        }
        tableNode.addChild(textLabel("Stock: \(stockCount)", x: stockX, y: rowY - 82, size: 14))
        tableNode.addChild(textLabel(name, x: stockX, y: rowY + 82, size: 16, bold: true))

        let pile = playedPileCollection(for: seat, width: playedWidth)
        pile.position = CGPoint(x: playedCenterX, y: rowY)
        tableNode.addChild(pile)
    }

    /// A played pile rendered as a horizontal fan via SKCollectionNode + StackLayout.
    private func playedPileCollection(for seat: SeatID, width: CGFloat) -> SKCollectionNode {
        let cards = state.core[played(seat)]?.cards ?? []
        let overlap = cards.count > 3
        let collection = SKCollectionNode(layoutBuilder: { node in
            StackLayout(
                axis: .horizontal,
                itemSizing: RelativeSizing(
                    widthSpec: .containerHeight(percentage: 0.72),
                    heightSpec: .containerHeight(percentage: 0.95)
                ),
                gapPercentage: overlap ? -0.35 : 0.18,
                alignment: .center,
                zOrder: .ascending,
                dataSource: node
            )
        })
        collection.layoutFrame = CGRect(x: 0, y: 0, width: width, height: 126)
        for card in cards {
            let faceUp = state.core.faceUp.contains(card)
            let face = faceUp ? state.registry.face(card) : nil
            collection.addLayoutableChild(makeCardNode(face: face, faceUp: faceUp))
        }
        collection.layoutIfNeeded()
        return collection
    }

    private func makeCardNode(face: StandardFace?, faceUp: Bool) -> LayoutableSKShapeNode {
        let node = LayoutableSKShapeNode()
        node.lineWidth = 2
        if faceUp, let face {
            node.fillColor = .white
            node.strokeColor = .darkGray
            let label = SKLabelNode(text: face.description)
            label.fontName = "Menlo-Bold"
            label.fontSize = 24
            label.fontColor = (face.suit.color == .red) ? .systemRed : .black
            label.verticalAlignmentMode = .center
            label.horizontalAlignmentMode = .center
            label.zPosition = 1
            node.addChild(label)
        } else {
            node.fillColor = SKColor(red: 0.16, green: 0.30, blue: 0.62, alpha: 1.0)
            node.strokeColor = .white
        }
        return node
    }

    // MARK: - Labels & controls

    private func configure(_ label: SKLabelNode, size: CGFloat, font: String, alpha: CGFloat = 1.0) {
        label.fontName = font
        label.fontSize = size
        label.fontColor = SKColor(white: 1.0, alpha: alpha)
        label.verticalAlignmentMode = .center
        label.horizontalAlignmentMode = .center
    }

    private func textLabel(_ text: String, x: CGFloat, y: CGFloat, size: CGFloat, bold: Bool = false) -> SKLabelNode {
        let label = SKLabelNode(text: text)
        label.fontName = bold ? "AvenirNext-DemiBold" : "AvenirNext-Medium"
        label.fontSize = size
        label.fontColor = SKColor(white: 1.0, alpha: 0.9)
        label.verticalAlignmentMode = .center
        label.horizontalAlignmentMode = .center
        label.position = CGPoint(x: x, y: y)
        return label
    }

    private func controlPill(_ text: String, name: String, at point: CGPoint) -> SKNode {
        let pill = SKShapeNode(rectOf: CGSize(width: 180, height: 30), cornerRadius: 15)
        pill.fillColor = SKColor(white: 1.0, alpha: 0.12)
        pill.strokeColor = SKColor(white: 1.0, alpha: 0.4)
        pill.name = name
        let label = SKLabelNode(text: text)
        label.fontName = "AvenirNext-DemiBold"
        label.fontSize = 13
        label.fontColor = .white
        label.verticalAlignmentMode = .center
        label.horizontalAlignmentMode = .center
        pill.addChild(label)
        pill.position = point
        return pill
    }

    // MARK: - Status text

    private func statusText() -> String {
        if case let .winner(seat) = game.outcome(state) {
            return seat == seat0 ? "You win the game! 🎉" : "Opponent wins the game."
        }
        if phase == .awaitingResolution { return battleSummary() }
        return "Ready"
    }

    private func battleSummary() -> String {
        guard let c0 = state.core[played(seat0)]?.top,
              let c1 = state.core[played(seat1)]?.top else { return "" }
        let f0 = state.registry.face(c0)
        let f1 = state.registry.face(c1)
        if f0.rank == f1.rank { return "\(f0) vs \(f1) — War!" }
        return "\(f0) vs \(f1) — \(game.beats(f0.rank, f1.rank) ? "you take it" : "opponent takes it")"
    }

    private func hintText() -> String {
        if game.outcome(state) != nil { return "Click to play again" }
        return phase == .awaitingResolution ? "Click to resolve" : "Click to play both cards"
    }
}
