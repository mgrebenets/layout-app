//
//  DurakScene.swift
//  LayoutApp macOS
//
//  Playable two-player Durak (you vs. a simple AI) driven by GameEngine's DurakGame. You pick the
//  cards to play: click a hand card to attack, or to beat the current attack while defending; use
//  the Take / Pass buttons otherwise. Hands and the table render through SKCollectionNode fans.
//  The AI (seat 1) plays after a short "thinking" delay so its moves are watchable.
//

import SpriteKit
import GameEngine
import LayoutKit

final class DurakScene: SKScene {

    private var game = DurakGame()
    private var state: DurakState!
    private let ai = DurakAI()
    private var aiThinking = false

    private let me = SeatID(0)        // human, bottom
    private let opponent = SeatID(1)  // AI, top

    private let tableNode = SKNode()
    private let controlsNode = SKNode()
    private let statusLabel = SKLabelNode()
    private let hintLabel = SKLabelNode()

    private func hand(_ seat: SeatID) -> ZoneID { ZoneID("hand", owner: seat) }

    // MARK: - Lifecycle

    override func didMove(to view: SKView) {
        scaleMode = .resizeFill
        backgroundColor = SKColor(red: 0.10, green: 0.30, blue: 0.22, alpha: 1.0)
        anchorPoint = .zero
        addChild(tableNode)
        addChild(controlsNode)
        configure(statusLabel, size: 20, font: "AvenirNext-DemiBold")
        configure(hintLabel, size: 13, font: "AvenirNext-Regular", alpha: 0.7)
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
        game = DurakGame()
        state = game.setup(seatCount: 2, seed: UInt64.random(in: UInt64.min...UInt64.max))
        aiThinking = false
        render()
        scheduleAITurnIfNeeded() // opponent may be the first attacker
    }

    // MARK: - Input

    override func mouseDown(with event: NSEvent) {
        if game.outcome(state) != nil { startNewGame(); return }
        guard !aiThinking else { return }

        let hit = nodes(at: event.location(in: self))
        if hit.contains(where: { $0.name == "btn_take" }) { humanMove(.take); return }
        if hit.contains(where: { $0.name == "btn_pass" }) { humanMove(.pass); return }
        if let cardNode = hit.first(where: { ($0.name ?? "").hasPrefix("card_") }),
           let value = Int((cardNode.name ?? "").dropFirst("card_".count)) {
            handleCardClick(CardID(value))
        }
    }

    private func handleCardClick(_ card: CardID) {
        guard state.core.currentSeat == me else { return }
        switch state.phase {
        case .attacking:
            humanMove(.attack(card))
        case .defending:
            // Beat the first unbeaten attack this card can legally beat.
            let legal = game.legalMoves(for: me, in: state)
            if let move = legal.first(where: {
                if case let .defend(_, with) = $0 { return with == card } else { return false }
            }) {
                humanMove(move)
            }
        }
    }

    private func humanMove(_ move: DurakMove) {
        guard !aiThinking, game.outcome(state) == nil, state.core.currentSeat == me else { return }
        guard game.legalMoves(for: me, in: state).contains(move) else { return }
        fold(game.lower(move, in: state))
        render()
        scheduleAITurnIfNeeded()
    }

    // MARK: - AI

    private func scheduleAITurnIfNeeded() {
        guard game.outcome(state) == nil, state.core.currentSeat == opponent else { return }
        aiThinking = true
        render()
        run(.sequence([.wait(forDuration: 0.6), .run { [weak self] in self?.aiStep() }]))
    }

    private func aiStep() {
        guard let move = ai.move(for: opponent, in: state, game: game) else {
            aiThinking = false; render(); return
        }
        fold(game.lower(move, in: state))
        if game.outcome(state) == nil, state.core.currentSeat == opponent {
            render()
            run(.sequence([.wait(forDuration: 0.6), .run { [weak self] in self?.aiStep() }]))
        } else {
            aiThinking = false
            render()
        }
    }

    private func fold(_ effects: [Effect<DurakEffect>]) {
        for effect in effects {
            switch effect {
            case let .core(coreEffect): state.core.apply(coreEffect)
            case let .game(gameEffect): game.apply(gameEffect, to: &state)
            }
        }
    }

    // MARK: - Rendering

    private func render() {
        tableNode.removeAllChildren()
        controlsNode.removeAllChildren()

        drawHand(opponent, faceUp: false, rowY: size.height - 90)
        drawDeck()
        drawTable()
        drawHand(me, faceUp: true, rowY: 90)
        drawControls()

        statusLabel.position = CGPoint(x: size.width / 2, y: size.height - 28)
        statusLabel.text = statusText()
        hintLabel.position = CGPoint(x: size.width / 2, y: 168)
        hintLabel.text = hintText()
    }

    private func drawHand(_ seat: SeatID, faceUp: Bool, rowY: CGFloat) {
        let cards = state.core[hand(seat)]?.cards ?? []
        guard !cards.isEmpty else { return }
        let count = cards.count

        // Size cards to fit the available width so every card is fully visible (no overlap).
        // Small hands keep a comfortable max size; large hands shrink to fit.
        let available = size.width * 0.82
        let cardWidth = min(92, available / CGFloat(count))
        let cardHeight = min(120, cardWidth * 1.45)
        let labelFont = min(22, max(9, cardWidth * 0.32))

        let collection = SKCollectionNode(layoutBuilder: { node in
            StackLayout(
                axis: .horizontal,
                itemSizing: RelativeSizing(
                    widthSpec: .containerWidth(percentage: 1.0 / CGFloat(count)),
                    heightSpec: .containerHeight(percentage: 1.0)
                ),
                gapPercentage: 0,
                alignment: .center,
                zOrder: .ascending,
                dataSource: node
            )
        })
        // layoutFrame width == total card width → the hand is centred on the collection's position.
        collection.layoutFrame = CGRect(x: 0, y: 0, width: cardWidth * CGFloat(count), height: cardHeight)
        for card in cards {
            let node = makeCardNode(face: faceUp ? state.registry.face(card) : nil,
                                    faceUp: faceUp, labelFontSize: labelFont)
            if faceUp { node.name = "card_\(card.value)" }
            collection.addLayoutableChild(node)
        }
        collection.layoutIfNeeded()
        collection.position = CGPoint(x: size.width / 2, y: rowY)
        tableNode.addChild(collection)
    }

    private func drawTable() {
        let pairs = state.table
        guard !pairs.isEmpty else { return }
        let spacing: CGFloat = 100
        var x = size.width / 2 - CGFloat(pairs.count - 1) * spacing / 2
        for pair in pairs {
            let attack = makeCardNode(face: state.registry.face(pair.attack), faceUp: true)
            attack.layoutFrame = CGRect(x: 0, y: 0, width: 80, height: 112)
            attack.position = CGPoint(x: x, y: size.height / 2)
            tableNode.addChild(attack)
            if let defense = pair.defense {
                let node = makeCardNode(face: state.registry.face(defense), faceUp: true)
                node.layoutFrame = CGRect(x: 0, y: 0, width: 80, height: 112)
                node.position = CGPoint(x: x + 18, y: size.height / 2 - 24)
                node.zPosition = 1
                tableNode.addChild(node)
            }
            x += spacing
        }
    }

    private func drawDeck() {
        let deck = state.core[.deck]?.cards ?? []
        let deckX: CGFloat = 120
        let deckY = size.height / 2

        if let trumpCard = deck.first { // bottom of the deck, turned up
            let trump = makeCardNode(face: state.registry.face(trumpCard), faceUp: true)
            trump.layoutFrame = CGRect(x: 0, y: 0, width: 80, height: 112)
            trump.zRotation = .pi / 2
            trump.position = CGPoint(x: deckX + 34, y: deckY)
            tableNode.addChild(trump)
        }
        if !deck.isEmpty {
            let back = makeCardNode(face: nil, faceUp: false)
            back.layoutFrame = CGRect(x: 0, y: 0, width: 80, height: 112)
            back.position = CGPoint(x: deckX, y: deckY)
            tableNode.addChild(back)
        }
        tableNode.addChild(textLabel("Deck: \(deck.count)   Trump: \(state.trump.symbol)",
                                     x: deckX + 18, y: deckY - 82, size: 13))
    }

    private func drawControls() {
        guard state.core.currentSeat == me, game.outcome(state) == nil, !aiThinking else { return }
        let legal = game.legalMoves(for: me, in: state)
        let point = CGPoint(x: size.width - 120, y: size.height / 2)
        if legal.contains(.take) {
            controlsNode.addChild(button("Take", name: "btn_take", at: point))
        } else if legal.contains(.pass) {
            controlsNode.addChild(button("Pass / Bita", name: "btn_pass", at: point))
        }
    }

    // MARK: - Nodes

    private func makeCardNode(face: StandardFace?, faceUp: Bool, labelFontSize: CGFloat = 22) -> LayoutableSKShapeNode {
        let node = LayoutableSKShapeNode()
        node.lineWidth = 2
        if faceUp, let face {
            node.fillColor = .white
            node.strokeColor = .darkGray
            let label = SKLabelNode(text: face.description)
            label.fontName = "Menlo-Bold"
            label.fontSize = labelFontSize
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

    private func button(_ text: String, name: String, at point: CGPoint) -> SKNode {
        let pill = SKShapeNode(rectOf: CGSize(width: 160, height: 38), cornerRadius: 19)
        pill.fillColor = SKColor(white: 1.0, alpha: 0.16)
        pill.strokeColor = SKColor(white: 1.0, alpha: 0.5)
        pill.name = name
        let label = SKLabelNode(text: text)
        label.fontName = "AvenirNext-DemiBold"
        label.fontSize = 15
        label.fontColor = .white
        label.verticalAlignmentMode = .center
        label.horizontalAlignmentMode = .center
        pill.addChild(label)
        pill.position = point
        return pill
    }

    private func configure(_ label: SKLabelNode, size: CGFloat, font: String, alpha: CGFloat = 1.0) {
        label.fontName = font
        label.fontSize = size
        label.fontColor = SKColor(white: 1.0, alpha: alpha)
        label.verticalAlignmentMode = .center
        label.horizontalAlignmentMode = .center
    }

    private func textLabel(_ text: String, x: CGFloat, y: CGFloat, size: CGFloat) -> SKLabelNode {
        let label = SKLabelNode(text: text)
        label.fontName = "AvenirNext-Medium"
        label.fontSize = size
        label.fontColor = SKColor(white: 1.0, alpha: 0.9)
        label.verticalAlignmentMode = .center
        label.horizontalAlignmentMode = .center
        label.position = CGPoint(x: x, y: y)
        return label
    }

    // MARK: - Status text

    private func statusText() -> String {
        switch game.outcome(state) {
        case .winner(let seat):
            return seat == me ? "You win! Opponent is the durak 🎉  —  click to replay"
                              : "You are the durak.  —  click to replay"
        case .winners, .draw:
            return "Draw.  —  click to replay"
        case nil:
            if aiThinking || state.core.currentSeat == opponent { return "Trump \(state.trump.symbol)   ·   Opponent is thinking…" }
            let action = state.phase == .attacking ? "attack" : "defend, or Take"
            return "Trump \(state.trump.symbol)   ·   Your turn — \(action)"
        }
    }

    private func hintText() -> String {
        if game.outcome(state) != nil { return "" }
        guard state.core.currentSeat == me, !aiThinking else { return "" }
        return state.phase == .attacking ? "Click a card to attack" : "Click a card to beat the attack"
    }
}
