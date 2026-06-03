//
//  DurakScene.swift
//  LayoutApp macOS
//
//  Playable Durak (you vs. simple AIs) for 2–4 players, driven by GameEngine's DurakGame. You are
//  seat 0 at the bottom; opponents fan out across the top. Click a hand card to attack or to beat
//  the open attack; use Take / Pass(Done) otherwise. Live pills toggle player count and rules
//  (throw-in, throw-on-take, and throw-in priority). All non-human seats are played by DurakAI with
//  a short "thinking" delay, and `advance` resolves the throw-in cycle between moves.
//

import SpriteKit
import GameEngine
import LayoutKit

final class DurakScene: SKScene {

    private var playerCount = 3
    private var rules = DurakRules()
    private var game = DurakGame()
    private var state: DurakState!
    private let ai = DurakAI()
    private var aiThinking = false

    // Match (series of rounds) state.
    private var teachingDurak = false
    private var lossLimit = 0            // 0 = unlimited; otherwise the match ends at this many losses
    private var lossCounts: [SeatID: Int] = [:]
    private var lastDurak: SeatID?
    private var roundResolved = false

    private let me = SeatID(0)

    private let tableNode = SKNode()
    private let controlsNode = SKNode()
    private let statusLabel = SKLabelNode()
    private let hintLabel = SKLabelNode()

    private func hand(_ seat: SeatID) -> ZoneID { ZoneID("hand", owner: seat) }
    private func isAttacker(_ seat: SeatID) -> Bool { seat != state.defender }

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
        startMatch()
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        guard state != nil else { return }
        render()
    }

    private func startMatch() {
        lossCounts = [:]
        lastDurak = nil
        startRound()
    }

    private func startRound() {
        game = DurakGame(rules: rules)
        state = game.setup(seatCount: playerCount,
                           seed: UInt64.random(in: UInt64.min...UInt64.max),
                           openingAttacker: openingAttacker())
        aiThinking = false
        roundResolved = false
        settle()
        render()
        scheduleAIIfNeeded() // a non-human seat may be the first attacker
    }

    /// Who attacks first this round: lowest trump on round 1 (nil → engine decides), otherwise from
    /// the previous loser and the "teaching the durak" rule.
    private func openingAttacker() -> SeatID? {
        guard let durak = lastDurak else { return nil }
        let n = playerCount
        return teachingDurak ? SeatID((durak.index - 1 + n) % n) // loser defends → seat to their right attacks
                             : durak                              // loser attacks first
    }

    private var matchOver: Bool {
        lossLimit > 0 && lossCounts.values.contains { $0 >= lossLimit }
    }

    private var matchLoser: SeatID? {
        guard lossLimit > 0 else { return nil }
        return (0..<playerCount).map { SeatID($0) }.first { (lossCounts[$0] ?? 0) >= lossLimit }
    }

    // MARK: - Input

    override func mouseDown(with event: NSEvent) {
        let hit = nodes(at: event.location(in: self))

        // Live controls work at any time.
        if hit.contains(where: { $0.name == "ctrl_players" }) {
            playerCount = playerCount >= 4 ? 2 : playerCount + 1; startMatch(); return
        }
        if hit.contains(where: { $0.name == "ctrl_teaching" }) {
            teachingDurak.toggle(); render(); return
        }
        if hit.contains(where: { $0.name == "ctrl_loselimit" }) {
            lossLimit = (lossLimit == 0) ? 1 : (lossLimit >= 5 ? 0 : lossLimit + 1) // 1…5 then unlimited
            render(); return
        }
        if hit.contains(where: { $0.name == "ctrl_throwin" }) {
            rules.allowThrowIn.toggle(); game = DurakGame(rules: rules); render(); return
        }
        if hit.contains(where: { $0.name == "ctrl_throwontake" }) {
            rules.throwInOnTake.toggle(); game = DurakGame(rules: rules); render(); return
        }
        if hit.contains(where: { $0.name == "ctrl_priority" }) {
            rules.throwInPriority = (rules.throwInPriority == .principalFirst) ? .roundRobin : .principalFirst
            game = DurakGame(rules: rules); render(); return
        }
        if hit.contains(where: { $0.name == "ctrl_firstmax" }) {
            rules.firstAttackMaxFive.toggle(); game = DurakGame(rules: rules); render(); return
        }

        if game.outcome(state) != nil {
            if matchOver { startMatch() } else { startRound() }
            return
        }
        guard !aiThinking, state.core.currentSeat == me else { return }

        if hit.contains(where: { $0.name == "btn_take" }) { humanMove(.take); return }
        if hit.contains(where: { $0.name == "btn_pass" }) { humanMove(.pass); return }
        if let cardNode = hit.first(where: { ($0.name ?? "").hasPrefix("card_") }),
           let value = Int((cardNode.name ?? "").dropFirst("card_".count)) {
            handleCardClick(CardID(value))
        }
    }

    private func handleCardClick(_ card: CardID) {
        switch state.phase {
        case .attacking, .takingThrowIn:
            humanMove(.attack(card))
        case .defending:
            let legal = game.legalMoves(for: me, in: state)
            if let move = legal.first(where: {
                if case let .defend(_, with) = $0 { return with == card } else { return false }
            }) {
                humanMove(move)
            }
        }
    }

    private func humanMove(_ move: DurakMove) {
        guard !aiThinking, game.outcome(state) == nil, state.core.currentSeat == me,
              game.legalMoves(for: me, in: state).contains(move) else { return }
        fold(game.lower(move, in: state))
        settle()
        render()
        scheduleAIIfNeeded()
    }

    // MARK: - AI / engine stepping

    private func scheduleAIIfNeeded() {
        guard game.outcome(state) == nil, state.core.currentSeat != me else { return }
        aiThinking = true
        render()
        run(.sequence([.wait(forDuration: 0.55), .run { [weak self] in self?.aiStep() }]))
    }

    private func aiStep() {
        guard game.outcome(state) == nil, state.core.currentSeat != me else { aiThinking = false; render(); return }
        guard let move = ai.move(for: state.core.currentSeat, in: state, game: game) else {
            aiThinking = false; render(); return
        }
        fold(game.lower(move, in: state))
        settle()
        if game.outcome(state) == nil, state.core.currentSeat != me {
            render()
            run(.sequence([.wait(forDuration: 0.55), .run { [weak self] in self?.aiStep() }]))
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

    /// Run the engine's automatic transitions (throw-in offers, auto-passes, bout resolution).
    private func advanceToFixpoint() {
        var guardCount = 0
        while true {
            let batch = game.advance(state)
            if batch.isEmpty { break }
            fold(batch)
            guardCount += 1
            if guardCount > 10_000 { break }
        }
    }

    /// Advance to a fixpoint and, when a round ends, record the durak's loss (exactly once).
    private func settle() {
        advanceToFixpoint()
        guard !roundResolved, let outcome = game.outcome(state) else { return }
        roundResolved = true
        if case let .winners(safe) = outcome,
           let durak = (0..<playerCount).map({ SeatID($0) }).first(where: { !safe.contains($0) }) {
            lastDurak = durak
            lossCounts[durak, default: 0] += 1
        }
    }

    // MARK: - Rendering

    private func render() {
        tableNode.removeAllChildren()
        controlsNode.removeAllChildren()

        drawOpponents()
        drawDeck()
        drawTable()
        drawHand(me, faceUp: true, rowY: 140, cardHeight: 120)
        drawControls()
        drawRulePills()

        statusLabel.position = CGPoint(x: size.width / 2, y: 252)
        statusLabel.text = statusText()
        hintLabel.position = CGPoint(x: size.width / 2, y: 224)
        hintLabel.text = hintText()
    }

    private func drawOpponents() {
        let opponents = (1..<playerCount).map { SeatID($0) }
        let topY = size.height - 92
        for (i, seat) in opponents.enumerated() {
            let x: CGFloat
            if opponents.count == 1 {
                x = size.width / 2
            } else {
                let left: CGFloat = 220, right = size.width - 220
                x = left + (right - left) * CGFloat(i) / CGFloat(opponents.count - 1)
            }
            drawOpponent(seat, center: CGPoint(x: x, y: topY))
        }
    }

    private func drawOpponent(_ seat: SeatID, center: CGPoint) {
        // A small face-down fan + a label with role/count, highlighted when it's this seat's turn.
        let cardHeight: CGFloat = 66
        let cardSize = CGSize(width: cardHeight * 0.72, height: cardHeight)
        let count = state.core[hand(seat)]?.count ?? 0
        let collection = SKCollectionNode(layoutBuilder: { node in
            StackLayout(axis: .horizontal,
                        itemSizing: RelativeSizing(widthSpec: .containerHeight(percentage: 0.72),
                                                   heightSpec: .containerHeight(percentage: 1.0)),
                        gapPercentage: 0.5, alignment: .center, zOrder: .ascending, dataSource: node)
        })
        collection.layoutFrame = CGRect(x: 0, y: 0, width: 220, height: cardHeight)
        for _ in 0..<count { collection.addLayoutableChild(makeCardNode(face: nil, faceUp: false, size: cardSize)) }
        collection.layoutIfNeeded()
        collection.position = center
        tableNode.addChild(collection)

        let isTurn = (state.core.currentSeat == seat) && game.outcome(state) == nil
        let role = seat == state.defender ? "Defender"
                 : seat == state.principalAttacker ? "Lead attacker" : "Attacker"
        let losses = lossCounts[seat] ?? 0
        let lossText = losses > 0 ? "  ·  ✖\(losses)" : ""
        let label = textLabel("Player \(seat.index)  ·  \(role)  ·  \(count)\(lossText)",
                              x: center.x, y: center.y - cardHeight / 2 - 16, size: 13)
        label.fontColor = isTurn ? .systemYellow : SKColor(white: 1.0, alpha: 0.85)
        if isTurn { label.fontName = "AvenirNext-Bold" }
        tableNode.addChild(label)
    }

    private func drawHand(_ seat: SeatID, faceUp: Bool, rowY: CGFloat, cardHeight: CGFloat) {
        let cards = state.core[hand(seat)]?.cards ?? []
        guard !cards.isEmpty else { return }
        let cardSize = CGSize(width: cardHeight * 0.76, height: cardHeight)
        let collection = SKCollectionNode(layoutBuilder: { node in
            StackLayout(axis: .horizontal,
                        itemSizing: RelativeSizing(widthSpec: .containerHeight(percentage: 0.76),
                                                   heightSpec: .containerHeight(percentage: 1.0)),
                        gapPercentage: 1.0, alignment: .center, zOrder: .ascending, dataSource: node)
        })
        collection.layoutFrame = CGRect(x: 0, y: 0, width: size.width * 0.92, height: cardHeight)
        for card in cards {
            let node = makeCardNode(face: faceUp ? state.registry.face(card) : nil, faceUp: faceUp, size: cardSize)
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
            let attack = makeCardNode(face: state.registry.face(pair.attack), faceUp: true, size: CGSize(width: 80, height: 112))
            attack.layoutFrame = CGRect(x: 0, y: 0, width: 80, height: 112)
            attack.position = CGPoint(x: x, y: size.height / 2)
            tableNode.addChild(attack)
            if let defense = pair.defense {
                let node = makeCardNode(face: state.registry.face(defense), faceUp: true, size: CGSize(width: 80, height: 112))
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
        if let trumpCard = deck.first {
            let trump = makeCardNode(face: state.registry.face(trumpCard), faceUp: true, size: CGSize(width: 80, height: 112))
            trump.layoutFrame = CGRect(x: 0, y: 0, width: 80, height: 112)
            trump.zRotation = .pi / 2
            trump.position = CGPoint(x: deckX + 34, y: deckY)
            tableNode.addChild(trump)
        }
        if !deck.isEmpty {
            let back = makeCardNode(face: nil, faceUp: false, size: CGSize(width: 80, height: 112))
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
            controlsNode.addChild(button(state.phase == .takingThrowIn ? "Done" : "Pass / Bita", name: "btn_pass", at: point))
        }
    }

    private func drawRulePills() {
        let cx = size.width / 2
        // Bottom row: per-deal rules.
        let rowA: CGFloat = 22
        let xa: [CGFloat] = [cx - 258, cx - 86, cx + 86, cx + 258]
        controlsNode.addChild(rulePill("Throw-in: \(rules.allowThrowIn ? "On" : "Off")", name: "ctrl_throwin", at: CGPoint(x: xa[0], y: rowA)))
        controlsNode.addChild(rulePill("On take: \(rules.throwInOnTake ? "On" : "Off")", name: "ctrl_throwontake", at: CGPoint(x: xa[1], y: rowA)))
        let order = rules.throwInPriority == .principalFirst ? "Principal" : "Round-robin"
        controlsNode.addChild(rulePill("Priority: \(order)", name: "ctrl_priority", at: CGPoint(x: xa[2], y: rowA)))
        controlsNode.addChild(rulePill("First ≤5: \(rules.firstAttackMaxFive ? "On" : "Off")", name: "ctrl_firstmax", at: CGPoint(x: xa[3], y: rowA)))

        // Upper row: match settings.
        let rowB: CGFloat = 54
        let xb: [CGFloat] = [cx - 172, cx, cx + 172]
        controlsNode.addChild(rulePill("Players: \(playerCount)", name: "ctrl_players", at: CGPoint(x: xb[0], y: rowB)))
        controlsNode.addChild(rulePill("Teaching: \(teachingDurak ? "On" : "Off")", name: "ctrl_teaching", at: CGPoint(x: xb[1], y: rowB)))
        controlsNode.addChild(rulePill("Lose at: \(lossLimit == 0 ? "∞" : String(lossLimit))", name: "ctrl_loselimit", at: CGPoint(x: xb[2], y: rowB)))
    }

    // MARK: - Nodes

    private func makeCardNode(face: StandardFace?, faceUp: Bool, size cardSize: CGSize, labelFontSize: CGFloat = 22) -> LayoutableSKShapeNode {
        let node = LayoutableSKShapeNode()
        node.lineWidth = 2
        guard faceUp, let face else {
            node.fillColor = SKColor(red: 0.16, green: 0.30, blue: 0.62, alpha: 1.0)
            node.strokeColor = .white
            return node
        }
        node.fillColor = .white
        node.strokeColor = .darkGray
        let color: SKColor = (face.suit.color == .red) ? .systemRed : .black

        let center = SKLabelNode(text: face.description)
        center.fontName = "Menlo-Bold"
        center.fontSize = labelFontSize
        center.fontColor = color
        center.verticalAlignmentMode = .center
        center.horizontalAlignmentMode = .center
        center.zPosition = 1
        node.addChild(center)

        let corner = SKLabelNode(text: face.description)
        corner.fontName = "Menlo-Bold"
        corner.fontSize = max(10, min(15, cardSize.width * 0.22))
        corner.fontColor = color
        corner.verticalAlignmentMode = .top
        corner.horizontalAlignmentMode = .left
        corner.position = CGPoint(x: -cardSize.width / 2 + 5, y: cardSize.height / 2 - 4)
        corner.zPosition = 1
        node.addChild(corner)
        return node
    }

    private func button(_ text: String, name: String, at point: CGPoint) -> SKNode {
        let pill = SKShapeNode(rectOf: CGSize(width: 160, height: 38), cornerRadius: 19)
        pill.fillColor = SKColor(white: 1.0, alpha: 0.16)
        pill.strokeColor = SKColor(white: 1.0, alpha: 0.5)
        pill.name = name
        pill.addChild(centeredLabel(text, size: 15))
        pill.position = point
        return pill
    }

    private func rulePill(_ text: String, name: String, at point: CGPoint) -> SKNode {
        let pill = SKShapeNode(rectOf: CGSize(width: 156, height: 28), cornerRadius: 14)
        pill.fillColor = SKColor(white: 1.0, alpha: 0.12)
        pill.strokeColor = SKColor(white: 1.0, alpha: 0.4)
        pill.name = name
        pill.addChild(centeredLabel(text, size: 11))
        pill.position = point
        return pill
    }

    private func centeredLabel(_ text: String, size: CGFloat) -> SKLabelNode {
        let label = SKLabelNode(text: text)
        label.fontName = "AvenirNext-DemiBold"
        label.fontSize = size
        label.fontColor = .white
        label.verticalAlignmentMode = .center
        label.horizontalAlignmentMode = .center
        return label
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
        if game.outcome(state) != nil {
            if matchOver, let loser = matchLoser {
                let who = loser == me ? "You" : "Player \(loser.index)"
                return "\(who) lost the match (\(lossLimit) losses)  —  click for a new match"
            }
            if let durak = lastDurak {
                let who = durak == me ? "You are" : "Player \(durak.index) is"
                return "\(who) the durak this round  —  click for the next round"
            }
            return "Round drawn  —  click for the next round"
        }
        let trump = "Trump \(state.trump.symbol)"
        if aiThinking || state.core.currentSeat != me {
            return "\(trump)   ·   Player \(state.core.currentSeat.index) is thinking…"
        }
        let role = me == state.defender ? "you defend" : "you attack"
        let action: String
        switch state.phase {
        case .attacking: action = "attack"
        case .defending: action = "defend, or Take"
        case .takingThrowIn: action = "throw in more, or Done"
        }
        let mine = lossCounts[me] ?? 0
        let losses = mine > 0 ? "   ·   your losses: \(mine)" : ""
        return "\(trump)   ·   \(role) — \(action)\(losses)"
    }

    private func hintText() -> String {
        if game.outcome(state) != nil { return "" }
        guard state.core.currentSeat == me, !aiThinking else { return "" }
        switch state.phase {
        case .attacking: return "Click a card to attack"
        case .defending: return "Click a card to beat the attack, or Take"
        case .takingThrowIn: return "Throw in matching cards, or click Done"
        }
    }
}
