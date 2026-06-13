//
//  WarScene.swift
//  LayoutApp
//
//  A playable War scene driven by GameEngine's WarGame. Every deal, comparison, war, and win comes
//  from the engine; this scene renders state and feeds clicks back as the forced move.
//
//  - Rules are editable on the fly via three pills at the top (war face-down count 1–3, fixed/shuffled
//    winnings, and whether a 2 beats an Ace). Changing them rebuilds the WarGame; the game continues.
//  - The engine's `advance` steps one beat at a time, so wars are watchable: a tied pair lays its
//    face-down + face-up cards, held on the table, and resolves on the next click.
//  - Rendering uses the shared `CardTableNode`: each render is a full `state → placements` snapshot and
//    cards glide between the stock and the played fan (the same model as Durak/Solitaire).
//

import SpriteKit
import GameEngine
import LayoutKit

final class WarScene: PointerInputScene {

    private var rules = WarRules()
    private var game = WarGame()
    private var state: WarState!

    private enum Phase { case awaitingPlay, awaitingResolution }
    private var phase: Phase = .awaitingPlay

    private let seat0 = SeatID(0) // bottom — "You"
    private let seat1 = SeatID(1) // top — "Opponent"

    private let cardTable = CardTableNode()
    private let labelsNode = SKNode()
    private let controlsNode = SKNode()
    private let statusLabel = SKLabelNode()
    private let hintLabel = SKLabelNode()
    private var lastPlacements: [Int: CardPlacement] = [:]

    private func stock(_ seat: SeatID) -> ZoneID { ZoneID("stock", owner: seat) }
    private func played(_ seat: SeatID) -> ZoneID { ZoneID("played", owner: seat) }

    // MARK: - Lifecycle

    override func didMove(to view: SKView) {
        scaleMode = .resizeFill
        backgroundColor = SKColor(red: 0.10, green: 0.35, blue: 0.18, alpha: 1.0)
        anchorPoint = .zero

        addChild(cardTable)
        for node in [labelsNode, controlsNode] { node.zPosition = 10_000; addChild(node) }
        configure(statusLabel, size: 22, font: "AvenirNext-DemiBold"); statusLabel.zPosition = 10_000
        configure(hintLabel, size: 14, font: "AvenirNext-Regular", alpha: 0.7); hintLabel.zPosition = 10_000
        addChild(statusLabel)
        addChild(hintLabel)

        cardTable.faceProvider = { [weak self] id in
            guard let self, let state = self.state else { return nil }
            let face = state.registry.face(CardID(id))
            return CardFaceView(text: face.description, isRed: face.suit.color == .red)
        }

        startNewGame()
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        guard state != nil else { return }
        render(animated: false)
    }

    private func startNewGame() {
        game = WarGame(rules: rules)
        state = game.setup(seatCount: 2, seed: UInt64.random(in: UInt64.min...UInt64.max))
        phase = .awaitingPlay
        render(animated: false)
    }

    // MARK: - Input

    override func pointerDown(at point: CGPoint, tapCount: Int) {
        let hit = nodes(at: point)
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

    // MARK: - Geometry (responsive — cards scale with the window, via CardMetrics)

    private var cardSize: CGSize { CardMetrics.fit(maxWidth: size.width * 0.08, maxHeight: size.height * 0.20) }
    private func rowY(_ seat: SeatID) -> CGFloat { size.height * (seat == seat1 ? 0.66 : 0.32) }
    private var stockX: CGFloat { size.width / 2 - size.width * 0.22 }
    private var playedCenterX: CGFloat { size.width / 2 + size.width * 0.08 }
    private var playedWidth: CGFloat { size.width * 0.42 }

    // MARK: - Rendering

    private func render(animated: Bool = true) {
        labelsNode.removeAllChildren()
        controlsNode.removeAllChildren()

        lastPlacements = placements(for: state)
        cardTable.apply(lastPlacements, duration: animated ? 0.2 : 0) {}

        drawSeatLabels(seat1, name: "Opponent")
        drawSeatLabels(seat0, name: "You")

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

    /// Stock stacks face-down at the seat's stock spot; the played pile fans out horizontally (overlapping
    /// once it grows past a few cards). Cards keep their ids, so a play glides from stock into the fan.
    private func placements(for s: WarState) -> [Int: CardPlacement] {
        var p: [Int: CardPlacement] = [:]
        let cs = cardSize
        for seat in [seat0, seat1] {
            let y = rowY(seat)
            for (i, card) in (s.core[stock(seat)]?.cards ?? []).enumerated() {
                p[card.value] = CardPlacement(position: CGPoint(x: stockX, y: y),
                                              zPosition: CGFloat(i), size: cs, faceUp: false)
            }
            let pile = s.core[played(seat)]?.cards ?? []
            guard !pile.isEmpty else { continue }
            let overlap = pile.count > 3
            let desired = cs.width * (overlap ? 0.62 : 1.16)
            let step = pile.count > 1 ? min(desired, (playedWidth - cs.width) / CGFloat(pile.count - 1)) : 0
            let startX = playedCenterX - step * CGFloat(pile.count - 1) / 2
            for (i, card) in pile.enumerated() {
                p[card.value] = CardPlacement(position: CGPoint(x: startX + step * CGFloat(i), y: y),
                                              zPosition: 1000 + CGFloat(i), size: cs,
                                              faceUp: s.core.faceUp.contains(card))
            }
        }
        return p
    }

    private func drawSeatLabels(_ seat: SeatID, name: String) {
        let y = rowY(seat)
        let count = state.core[stock(seat)]?.count ?? 0
        labelsNode.addChild(textLabel("Stock: \(count)", x: stockX, y: y - cardSize.height * 0.68, size: 14))
        labelsNode.addChild(textLabel(name, x: stockX, y: y + cardSize.height * 0.68, size: 16, bold: true))
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
