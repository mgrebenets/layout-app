//
//  SolitaireScene.swift
//  LayoutApp macOS
//
//  Playable Klondike on GameEngine's SolitaireGame. The board reuses the LayoutKit card library: a
//  CardTableNode lays out the stock, waste, four foundations, and seven tableau fans, and animates
//  cards to their slots after each move. Input is direct manipulation:
//   • drag a face-up card (a tableau drag carries the run on top of it) onto a foundation or tableau;
//   • click a card to send it straight to its foundation (the classic shortcut);
//   • click the stock to deal (or recycle the waste once it's empty).
//

import SpriteKit
import GameEngine
import LayoutKit

final class SolitaireScene: SKScene {

    private var rules = SolitaireRules()
    private var game = SolitaireGame()
    private var state: SolitaireState!
    private var busy = false
    private var lastPlacements: [Int: CardPlacement] = [:]
    private let me = SeatID(0)

    // Drag state.
    private var dragCards: [Int] = []                 // card values being dragged (head first)
    private var dragOffsets: [Int: CGPoint] = [:]     // each dragged node's offset from the cursor
    private var dragStart: CGPoint = .zero
    private var dragMoved = false

    private let cardSize = CGSize(width: 78, height: 108)
    private let faceUpFan: CGFloat = 30
    private let faceDownFan: CGFloat = 14

    private let boardNode = SKNode()      // pile placeholders, behind the cards
    private let cardTable = CardTableNode()
    private let uiNode = SKNode()
    private let controlsNode = SKNode()
    private let statusLabel = SKLabelNode()
    private let messageLabel = SKLabelNode()

    private let stock = ZoneID.deck
    private let waste = ZoneID("waste")
    private func tableau(_ i: Int) -> ZoneID { game.tableau(i) }
    private func foundation(_ i: Int) -> ZoneID { game.foundation(i) }

    // MARK: - Lifecycle

    override func didMove(to view: SKView) {
        scaleMode = .resizeFill
        backgroundColor = SKColor(red: 0.10, green: 0.32, blue: 0.20, alpha: 1.0)
        anchorPoint = .zero
        boardNode.zPosition = -10
        addChild(boardNode)
        addChild(cardTable)
        for node in [uiNode, controlsNode] { node.zPosition = 100; addChild(node) }
        configure(statusLabel, size: 15, font: "AvenirNext-DemiBold"); statusLabel.zPosition = 100
        configure(messageLabel, size: 26, font: "AvenirNext-Bold"); messageLabel.zPosition = 100
        addChild(statusLabel)
        addChild(messageLabel)
        cardTable.faceProvider = { [weak self] id in
            guard let self, let state = self.state else { return nil }
            let face = state.registry.face(CardID(id))
            return CardFaceView(text: face.description, isRed: face.suit.color == .red)
        }
        startGame()
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        guard state != nil, !busy else { return }
        applyState(duration: 0)
    }

    // MARK: - Geometry

    private var margin: CGFloat { 28 }
    private var columnSpacing: CGFloat { (size.width - margin * 2) / 7 }
    private func columnX(_ c: Int) -> CGFloat { margin + columnSpacing * (CGFloat(c) + 0.5) }
    private var topRowY: CGFloat { size.height - margin - cardSize.height / 2 }
    private var tableauTopY: CGFloat { topRowY - cardSize.height - 24 }
    private var stockPos: CGPoint { CGPoint(x: columnX(0), y: topRowY) }
    private var wastePos: CGPoint { CGPoint(x: columnX(1), y: topRowY) }
    private func foundationPos(_ i: Int) -> CGPoint { CGPoint(x: columnX(3 + i), y: topRowY) }

    private func rect(around center: CGPoint, pad: CGFloat = 0) -> CGRect {
        CGRect(x: center.x - cardSize.width / 2 - pad, y: center.y - cardSize.height / 2 - pad,
               width: cardSize.width + pad * 2, height: cardSize.height + pad * 2)
    }

    // MARK: - Game flow

    private func startGame() {
        game = SolitaireGame(rules: rules)
        state = game.setup(seatCount: 1, seed: UInt64.random(in: UInt64.min...UInt64.max))
        cardTable.reset()
        busy = true
        applyState(duration: 0.3) { [weak self] in self?.busy = false }
    }

    private func perform(_ move: SolitaireMove) {
        busy = true
        foldInto(&state, game.lower(move, in: state))
        var guardCount = 0
        while true {
            let batch = game.advance(state)
            if batch.isEmpty { break }
            foldInto(&state, batch)
            guardCount += 1
            if guardCount > 10_000 { break }
        }
        applyState(duration: 0.2) { [weak self] in self?.busy = false }
    }

    /// Lay every card out for the current state and animate it home. Re-homes any dragged nodes too.
    private func applyState(duration: TimeInterval, completion: @escaping () -> Void = {}) {
        lastPlacements = placements(for: state)
        renderStaticUI()
        cardTable.apply(lastPlacements, duration: duration) { completion() }
    }

    private func foldInto(_ s: inout SolitaireState, _ effects: [Effect<SolitaireEffect>]) {
        for effect in effects {
            switch effect {
            case let .core(coreEffect): s.core.apply(coreEffect)
            case let .game(gameEffect): game.apply(gameEffect, to: &s)
            }
        }
    }

    // MARK: - Input

    override func mouseDown(with event: NSEvent) {
        guard !busy else { return }
        let point = event.location(in: self)
        let hit = nodes(at: point)

        if hit.contains(where: { $0.name == "ctrl_draw" }) {
            rules.drawCount = rules.drawCount == 1 ? 3 : 1; startGame(); return
        }
        if hit.contains(where: { $0.name == "ctrl_redeals" }) {
            rules.redealLimit = nextRedealLimit(rules.redealLimit); startGame(); return
        }
        if hit.contains(where: { $0.name == "btn_newgame" }) { startGame(); return }

        if game.outcome(state) != nil { startGame(); return } // click anywhere to start a new deal

        if rect(around: stockPos, pad: 12).contains(point) {
            if game.legalMoves(for: me, in: state).contains(.draw) { perform(.draw) }
            return
        }
        guard let card = cardID(at: hit), let source = zoneContaining(card), isDraggable(card, in: source) else { return }
        beginDrag(card, from: source, at: point)
    }

    override func mouseDragged(with event: NSEvent) {
        guard !dragCards.isEmpty else { return }
        let point = event.location(in: self)
        if hypot(point.x - dragStart.x, point.y - dragStart.y) > 6 { dragMoved = true }
        for value in dragCards {
            if let node = cardTable.node(value), let offset = dragOffsets[value] {
                node.position = CGPoint(x: point.x + offset.x, y: point.y + offset.y)
            }
        }
    }

    override func mouseUp(with event: NSEvent) {
        guard !dragCards.isEmpty else { return }
        let head = CardID(dragCards[0])
        let point = event.location(in: self)
        let moved = dragMoved
        dragCards = []; dragOffsets = [:]; dragMoved = false

        if !moved {
            // A click (no drag): send the card straight to its foundation if it can go.
            if let dest = foundationDestination(for: head) { perform(.move(head, to: dest)); return }
            applyState(duration: 0.16); return
        }
        if let target = pile(at: point), game.legalMoves(for: me, in: state).contains(.move(head, to: target)) {
            perform(.move(head, to: target))
        } else {
            applyState(duration: 0.16) // snap back
        }
    }

    private func beginDrag(_ card: CardID, from source: ZoneID, at point: CGPoint) {
        if source.name == "tableau", let cards = state.core[source]?.cards, let i = cards.firstIndex(of: card) {
            dragCards = cards[i...].map { $0.value }
        } else {
            dragCards = [card.value]
        }
        dragStart = point
        dragMoved = false
        dragOffsets = [:]
        for (k, value) in dragCards.enumerated() {
            guard let node = cardTable.node(value) else { continue }
            dragOffsets[value] = CGPoint(x: node.position.x - point.x, y: node.position.y - point.y)
            node.setLayer(100_000 + CGFloat(k)) // lift the dragged run above everything
        }
    }

    private func isDraggable(_ card: CardID, in zone: ZoneID) -> Bool {
        guard state.core.faceUp.contains(card) else { return false }
        switch zone.name {
        case "tableau": return true
        case "waste", "foundation": return state.core[zone]?.top == card
        default: return false
        }
    }

    private func foundationDestination(for card: CardID) -> ZoneID? {
        for move in game.legalMoves(for: me, in: state) {
            if case let .move(c, dest) = move, c == card, dest.name == "foundation" { return dest }
        }
        return nil
    }

    private func zoneContaining(_ card: CardID) -> ZoneID? {
        for (id, zone) in state.core.zones where zone.contains(card) { return id }
        return nil
    }

    private func cardID(at hits: [SKNode]) -> CardID? {
        for hit in hits {
            var node: SKNode? = hit
            while let current = node {
                if let name = current.name, name.hasPrefix("card_"), let value = Int(name.dropFirst("card_".count)) {
                    return CardID(value)
                }
                node = current.parent
            }
        }
        return nil
    }

    /// The destination pile a drop point lands on — foundations first, then tableau columns.
    private func pile(at point: CGPoint) -> ZoneID? {
        for i in 0..<4 where rect(around: foundationPos(i), pad: 18).contains(point) { return foundation(i) }
        for c in 0..<7 where abs(point.x - columnX(c)) < columnSpacing / 2 && point.y < topRowY - cardSize.height / 2 + 12 {
            return tableau(c)
        }
        return nil
    }

    private func nextRedealLimit(_ current: Int?) -> Int? {
        switch current {
        case .none: return 3
        case .some(3): return 0
        default: return nil
        }
    }

    // MARK: - Placements

    private func placements(for s: SolitaireState) -> [Int: CardPlacement] {
        var p: [Int: CardPlacement] = [:]

        for (i, card) in (s.core[stock]?.cards ?? []).enumerated() {
            p[card.value] = CardPlacement(position: stockPos, zPosition: CGFloat(i), size: cardSize, faceUp: false)
        }

        let wasteCards = s.core[waste]?.cards ?? []
        for (i, card) in wasteCards.enumerated() {
            let fromTop = wasteCards.count - 1 - i // 0 = top (playable), older fan to the left
            let dx = -CGFloat(min(fromTop, 2)) * 17
            p[card.value] = CardPlacement(position: CGPoint(x: wastePos.x + dx, y: wastePos.y),
                                          zPosition: 1000 + CGFloat(i), size: cardSize, faceUp: true)
        }

        for f in 0..<4 {
            for (i, card) in (s.core[foundation(f)]?.cards ?? []).enumerated() {
                p[card.value] = CardPlacement(position: foundationPos(f),
                                              zPosition: 2000 + CGFloat(f) * 100 + CGFloat(i), size: cardSize, faceUp: true)
            }
        }

        for t in 0..<7 {
            var y = tableauTopY
            for (i, card) in (s.core[tableau(t)]?.cards ?? []).enumerated() {
                let up = s.core.faceUp.contains(card)
                p[card.value] = CardPlacement(position: CGPoint(x: columnX(t), y: y),
                                              zPosition: 3000 + CGFloat(t) * 100 + CGFloat(i), size: cardSize, faceUp: up)
                y -= up ? faceUpFan : faceDownFan
            }
        }
        return p
    }

    // MARK: - Board / UI

    private func renderStaticUI() {
        drawBoard()
        controlsNode.removeAllChildren()

        let onFoundations = (0..<4).reduce(0) { $0 + (state.core[foundation($1)]?.count ?? 0) }
        statusLabel.position = CGPoint(x: columnX(2), y: topRowY)
        statusLabel.text = "\(onFoundations) / 52"

        let won = game.outcome(state) != nil
        messageLabel.position = CGPoint(x: size.width / 2, y: size.height * 0.42)
        messageLabel.text = won ? "You win!  —  click for a new game" : ""

        let y: CGFloat = 26
        let cx = size.width / 2
        controlsNode.addChild(rulePill("Draw: \(rules.drawCount)", name: "ctrl_draw", at: CGPoint(x: cx - 170, y: y)))
        let redeals = rules.redealLimit.map(String.init) ?? "∞"
        controlsNode.addChild(rulePill("Redeals: \(redeals)", name: "ctrl_redeals", at: CGPoint(x: cx, y: y)))
        controlsNode.addChild(rulePill("New game", name: "btn_newgame", at: CGPoint(x: cx + 170, y: y)))
    }

    /// Faint outlines marking every pile, so empty slots read; a ↻ marks a recyclable empty stock.
    private func drawBoard() {
        boardNode.removeAllChildren()
        var slots = [stockPos, wastePos]
        slots += (0..<4).map(foundationPos)
        for s in slots { boardNode.addChild(slot(at: s)) }
        for c in 0..<7 { boardNode.addChild(slot(at: CGPoint(x: columnX(c), y: tableauTopY))) }

        if (state.core[stock]?.isEmpty ?? true), game.legalMoves(for: me, in: state).contains(.draw) {
            let recycle = SKLabelNode(text: "↻")
            recycle.fontName = "AvenirNext-Bold"; recycle.fontSize = 30
            recycle.fontColor = SKColor(white: 1.0, alpha: 0.4)
            recycle.verticalAlignmentMode = .center; recycle.position = stockPos
            boardNode.addChild(recycle)
        }
    }

    private func slot(at point: CGPoint) -> SKShapeNode {
        let node = SKShapeNode(rectOf: cardSize, cornerRadius: 8)
        node.strokeColor = SKColor(white: 1.0, alpha: 0.22)
        node.lineWidth = 2
        node.fillColor = .clear
        node.position = point
        return node
    }

    private func rulePill(_ text: String, name: String, at point: CGPoint) -> SKNode {
        let pill = SKShapeNode(rectOf: CGSize(width: 150, height: 30), cornerRadius: 15)
        pill.fillColor = SKColor(white: 1.0, alpha: 0.12)
        pill.strokeColor = SKColor(white: 1.0, alpha: 0.4)
        pill.name = name
        let label = SKLabelNode(text: text)
        label.fontName = "AvenirNext-DemiBold"; label.fontSize = 12; label.fontColor = .white
        label.verticalAlignmentMode = .center; label.horizontalAlignmentMode = .center
        pill.addChild(label)
        pill.position = point
        return pill
    }

    private func configure(_ label: SKLabelNode, size: CGFloat, font: String) {
        label.fontName = font
        label.fontSize = size
        label.fontColor = .white
        label.verticalAlignmentMode = .center
        label.horizontalAlignmentMode = .center
    }
}
