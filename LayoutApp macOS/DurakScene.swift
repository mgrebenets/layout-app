//
//  DurakScene.swift
//  LayoutApp macOS
//
//  Playable Durak (you vs. AIs, 2–4 players) on GameEngine's DurakMatch. Cards are durable nodes
//  managed by CardTableNode: after each move the scene folds the engine's effect batches one beat at
//  a time and animates every card to its new place, so deals/attacks/defends/sweeps are watchable
//  (input is locked until the animation settles). Labels, rule pills, and buttons are static UI.
//

import SpriteKit
import GameEngine
import LayoutKit

final class DurakScene: SKScene {

    private var match = DurakMatch(playerCount: 3)
    private var state: DurakState!
    private let ai = DurakAI()
    private var roundResolved = false
    private var busy = false                     // true while an animation is playing
    private var lastPlacements: [Int: CardPlacement] = [:]
    private var selectedCard: CardID?            // the human's lifted candidate, awaiting commit

    private let me = SeatID(0)
    private let tableCardSize = CGSize(width: 80, height: 112)

    private let cardTable = CardTableNode()
    private let uiNode = SKNode()
    private let controlsNode = SKNode()
    private let statusLabel = SKLabelNode()
    private let hintLabel = SKLabelNode()

    private var game: DurakGame { match.game }
    private func hand(_ seat: SeatID) -> ZoneID { ZoneID("hand", owner: seat) }

    // MARK: - Lifecycle

    override func didMove(to view: SKView) {
        scaleMode = .resizeFill
        backgroundColor = SKColor(red: 0.10, green: 0.30, blue: 0.22, alpha: 1.0)
        anchorPoint = .zero
        addChild(cardTable)
        for node in [uiNode, controlsNode] { node.zPosition = 100; addChild(node) }
        configure(statusLabel, size: 20, font: "AvenirNext-DemiBold"); statusLabel.zPosition = 100
        configure(hintLabel, size: 13, font: "AvenirNext-Regular", alpha: 0.7); hintLabel.zPosition = 100
        addChild(statusLabel)
        addChild(hintLabel)
        cardTable.faceProvider = { [weak self] id in
            guard let self, let state = self.state else { return nil }
            let face = state.registry.face(CardID(id))
            return CardFaceView(text: face.description, isRed: face.suit.color == .red)
        }
        startMatch()
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        guard state != nil, !busy else { return }
        lastPlacements = placements(for: state)
        cardTable.apply(lastPlacements, duration: 0) {}
        renderStaticUI()
    }

    // MARK: - Match / round flow

    private func startMatch() {
        match = DurakMatch(playerCount: match.playerCount, rules: match.rules,
                           lossLimit: match.lossLimit, teachingDurak: match.teachingDurak)
        startRound()
    }

    private func startRound() {
        state = match.newRound(seed: UInt64.random(in: UInt64.min...UInt64.max))
        roundResolved = false
        selectedCard = nil
        cardTable.reset()
        lastPlacements = placements(for: state)
        busy = true
        renderStaticUI()
        cardTable.apply(lastPlacements, duration: 0.3) { [weak self] in
            guard let self else { return }
            self.busy = false
            self.refreshInputLayer()
            self.scheduleAIIfNeeded()
        }
    }

    // MARK: - Applying a move (fold beats, animate each)

    private func perform(_ move: DurakMove) {
        busy = true
        selectedCard = nil
        var snapshots: [DurakState] = []
        var s = state!
        foldInto(&s, game.lower(move, in: s))
        snapshots.append(s)
        var guardCount = 0
        while true {
            let batch = game.advance(s)
            if batch.isEmpty { break }
            foldInto(&s, batch)
            snapshots.append(s)
            guardCount += 1
            if guardCount > 10_000 { break }
        }
        animate(snapshots, 0)
    }

    private func animate(_ snapshots: [DurakState], _ index: Int) {
        guard index < snapshots.count else { finishTurn(); return }
        state = snapshots[index]
        renderStaticUI()
        let next = placements(for: state)
        if next == lastPlacements {
            animate(snapshots, index + 1) // nothing moved (e.g. a turn hand-off) — no animation beat
        } else {
            lastPlacements = next
            cardTable.apply(next, duration: 0.3) { [weak self] in self?.animate(snapshots, index + 1) }
        }
    }

    private func finishTurn() {
        busy = false
        if !roundResolved, game.outcome(state) != nil {
            roundResolved = true
            match.recordRound(state)
        }
        renderStaticUI()
        refreshInputLayer()
        scheduleAIIfNeeded()
    }

    /// Re-apply the settled layout so legal-move highlights and the lifted candidate appear (a no-op
    /// during animations and on non-human turns — `placements(for:)` only decorates then).
    private func refreshInputLayer() {
        guard state != nil, !busy else { return }
        lastPlacements = placements(for: state)
        cardTable.apply(lastPlacements, duration: 0.12) {}
    }

    private func scheduleAIIfNeeded() {
        guard !busy, game.outcome(state) == nil, state.core.currentSeat != me else { return }
        renderStaticUI()
        run(.sequence([.wait(forDuration: 0.4), .run { [weak self] in self?.aiStep() }]))
    }

    private func aiStep() {
        guard !busy, game.outcome(state) == nil, state.core.currentSeat != me,
              let move = ai.move(for: state.core.currentSeat, in: state, game: game) else { return }
        perform(move)
    }

    private func foldInto(_ s: inout DurakState, _ effects: [Effect<DurakEffect>]) {
        for effect in effects {
            switch effect {
            case let .core(coreEffect): s.core.apply(coreEffect)
            case let .game(gameEffect): game.apply(gameEffect, to: &s)
            }
        }
    }

    // MARK: - Input

    override func mouseDown(with event: NSEvent) {
        let hit = nodes(at: event.location(in: self))

        if hit.contains(where: { $0.name == "ctrl_players" }) {
            let next = match.playerCount >= 4 ? 2 : match.playerCount + 1
            match = DurakMatch(playerCount: next, rules: match.rules,
                               lossLimit: match.lossLimit, teachingDurak: match.teachingDurak)
            startRound(); return
        }
        if hit.contains(where: { $0.name == "ctrl_teaching" }) { match.teachingDurak.toggle(); renderStaticUI(); return }
        if hit.contains(where: { $0.name == "ctrl_loselimit" }) {
            match.lossLimit = (match.lossLimit == 0) ? 1 : (match.lossLimit >= 5 ? 0 : match.lossLimit + 1)
            renderStaticUI(); return
        }
        if hit.contains(where: { $0.name == "ctrl_throwin" }) { match.rules.allowThrowIn.toggle(); renderStaticUI(); return }
        if hit.contains(where: { $0.name == "ctrl_throwontake" }) { match.rules.throwInOnTake.toggle(); renderStaticUI(); return }
        if hit.contains(where: { $0.name == "ctrl_priority" }) {
            match.rules.throwInPriority = (match.rules.throwInPriority == .principalFirst) ? .roundRobin : .principalFirst
            renderStaticUI(); return
        }
        if hit.contains(where: { $0.name == "ctrl_firstmax" }) { match.rules.firstAttackMaxFive.toggle(); renderStaticUI(); return }

        guard !busy else { return }
        if game.outcome(state) != nil {
            if match.isOver { startMatch() } else { startRound() }
            return
        }
        guard state.core.currentSeat == me else { return }
        if hit.contains(where: { $0.name == "btn_take" }) { humanMove(.take); return }
        if hit.contains(where: { $0.name == "btn_pass" }) { humanMove(.pass); return }
        if hit.contains(where: { $0.name == "btn_play" }) { commitSelected(); return }
        if let card = cardID(at: hit) {
            handleCardClick(card)
        } else if selectedCard != nil {
            selectedCard = nil            // clicked empty space — cancel the candidate
            refreshInputLayer()
        }
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

    /// First click on a legal card lifts it as a candidate; clicking it again (or Play) commits.
    /// Clicking another legal card switches the candidate. Illegal cards are ignored.
    private func handleCardClick(_ card: CardID) {
        guard legalHandCardValues(in: state).contains(card.value) else { return }
        if selectedCard == card {
            commitSelected()
        } else {
            selectedCard = card
            refreshInputLayer()
        }
    }

    /// Play the lifted candidate: attack with it, or beat the first attack it can in defence.
    private func commitSelected() {
        guard let card = selectedCard else { return }
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

    /// The values of the human's hand cards that begin a legal move right now (for highlighting).
    private func legalHandCardValues(in s: DurakState) -> Set<Int> {
        var result: Set<Int> = []
        for move in game.legalMoves(for: me, in: s) {
            switch move {
            case let .attack(card): result.insert(card.value)
            case let .defend(_, with): result.insert(with.value)
            case .take, .pass: break
            }
        }
        return result
    }

    private func humanMove(_ move: DurakMove) {
        guard !busy, game.outcome(state) == nil, state.core.currentSeat == me,
              game.legalMoves(for: me, in: state).contains(move) else { return }
        perform(move)
    }

    // MARK: - Card placements (target layout)

    private func placements(for s: DurakState) -> [Int: CardPlacement] {
        var p: [Int: CardPlacement] = [:]

        let deckPos = CGPoint(x: 120, y: size.height / 2)
        for (i, card) in (s.core[.deck]?.cards ?? []).enumerated() {
            if i == 0 { // trump (bottom of the deck), turned up
                p[card.value] = CardPlacement(position: CGPoint(x: deckPos.x + 34, y: deckPos.y),
                                              zRotation: .pi / 2, zPosition: 0, size: tableCardSize, faceUp: true)
            } else {
                p[card.value] = CardPlacement(position: deckPos, zPosition: CGFloat(i), size: tableCardSize, faceUp: false)
            }
        }

        let discardPos = CGPoint(x: size.width - 110, y: size.height / 2 + 130)
        for (i, card) in (s.core[.discard]?.cards ?? []).enumerated() {
            p[card.value] = CardPlacement(position: discardPos, zPosition: 1000 + CGFloat(i), size: tableCardSize, faceUp: false)
        }

        let pairs = s.table
        if !pairs.isEmpty {
            let spacing: CGFloat = 100
            var x = size.width / 2 - CGFloat(pairs.count - 1) * spacing / 2
            for (k, pair) in pairs.enumerated() {
                p[pair.attack.value] = CardPlacement(position: CGPoint(x: x, y: size.height / 2),
                                                     zPosition: 2000 + CGFloat(k) * 2, size: tableCardSize, faceUp: true)
                if let defense = pair.defense {
                    p[defense.value] = CardPlacement(position: CGPoint(x: x + 18, y: size.height / 2 - 24),
                                                     zPosition: 2000 + CGFloat(k) * 2 + 1, size: tableCardSize, faceUp: true)
                }
                x += spacing
            }
        }

        placeHand(s, seat: me, faceUp: true, centerX: size.width / 2, rowY: 140, cardHeight: 120,
                  maxWidth: size.width * 0.86, baseZ: 3000, into: &p)
        let opponents = (1..<s.core.seatCount).map { SeatID($0) }
        for (i, seat) in opponents.enumerated() {
            let slot = opponentSlot(i, opponents.count)
            placeHand(s, seat: seat, faceUp: false, centerX: slot.x, rowY: slot.y, cardHeight: 66,
                      maxWidth: 220, baseZ: 4000 + CGFloat(i) * 200, into: &p)
        }
        decorateForInput(&p, s)
        return p
    }

    /// When it's the human's settled turn, outline the cards they may play and lift their candidate.
    /// Gated on `!busy` so animation snapshots and AI turns stay undecorated.
    private func decorateForInput(_ p: inout [Int: CardPlacement], _ s: DurakState) {
        guard !busy, s.core.currentSeat == me, game.outcome(s) == nil else { return }
        for value in legalHandCardValues(in: s) {
            p[value]?.highlighted = true
        }
        if let selected = selectedCard {
            p[selected.value]?.selected = true
        }
    }

    private func placeHand(_ s: DurakState, seat: SeatID, faceUp: Bool, centerX: CGFloat, rowY: CGFloat,
                           cardHeight: CGFloat, maxWidth: CGFloat, baseZ: CGFloat, into p: inout [Int: CardPlacement]) {
        let cards = s.core[hand(seat)]?.cards ?? []
        guard !cards.isEmpty else { return }
        let cardWidth = cardHeight * 0.76
        let step = cards.count > 1 ? min(cardWidth + 6, (maxWidth - cardWidth) / CGFloat(cards.count - 1)) : 0
        let startX = centerX - step * CGFloat(cards.count - 1) / 2
        for (i, card) in cards.enumerated() {
            p[card.value] = CardPlacement(position: CGPoint(x: startX + step * CGFloat(i), y: rowY),
                                          zPosition: baseZ + CGFloat(i),
                                          size: CGSize(width: cardWidth, height: cardHeight), faceUp: faceUp)
        }
    }

    private func opponentSlot(_ i: Int, _ count: Int) -> CGPoint {
        let y = size.height - 100
        guard count > 1 else { return CGPoint(x: size.width / 2, y: y) }
        let left: CGFloat = 220, right = size.width - 220
        return CGPoint(x: left + (right - left) * CGFloat(i) / CGFloat(count - 1), y: y)
    }

    // MARK: - Static UI (labels, pills, buttons, status)

    private func renderStaticUI() {
        uiNode.removeAllChildren()
        controlsNode.removeAllChildren()

        let opponents = (1..<match.playerCount).map { SeatID($0) }
        for (i, seat) in opponents.enumerated() {
            let slot = opponentSlot(i, opponents.count)
            let isTurn = state.core.currentSeat == seat && game.outcome(state) == nil
            let role = seat == state.defender ? "Defender"
                     : seat == state.principalAttacker ? "Lead attacker" : "Attacker"
            let count = state.core[hand(seat)]?.count ?? 0
            let losses = match.losses(for: seat)
            let lossText = losses > 0 ? "  ·  ✖\(losses)" : ""
            let label = textLabel("Player \(seat.index)  ·  \(role)  ·  \(count)\(lossText)",
                                  x: slot.x, y: slot.y - 56, size: 13)
            label.fontColor = isTurn ? .systemYellow : SKColor(white: 1.0, alpha: 0.85)
            if isTurn { label.fontName = "AvenirNext-Bold" }
            uiNode.addChild(label)
        }

        let deckCount = state.core[.deck]?.count ?? 0
        uiNode.addChild(textLabel("Deck: \(deckCount)   Trump: \(state.trump.symbol)",
                                  x: 138, y: size.height / 2 - 82, size: 13))

        drawControls()
        drawRulePills()

        statusLabel.position = CGPoint(x: size.width / 2, y: 252)
        statusLabel.text = statusText()
        hintLabel.position = CGPoint(x: size.width / 2, y: 224)
        hintLabel.text = hintText()
    }

    private func drawControls() {
        guard state.core.currentSeat == me, game.outcome(state) == nil, !busy else { return }
        let legal = game.legalMoves(for: me, in: state)
        let point = CGPoint(x: size.width - 120, y: size.height / 2)
        if legal.contains(.take) {
            controlsNode.addChild(button("Take", name: "btn_take", at: point))
        } else if legal.contains(.pass) {
            controlsNode.addChild(button(state.phase == .takingThrowIn ? "Done" : "Pass / Bita", name: "btn_pass", at: point))
        }
        if selectedCard != nil {
            controlsNode.addChild(button("Play", name: "btn_play", at: CGPoint(x: point.x, y: point.y - 52)))
        }
    }

    private func drawRulePills() {
        let cx = size.width / 2
        let rowA: CGFloat = 22
        let xa: [CGFloat] = [cx - 258, cx - 86, cx + 86, cx + 258]
        controlsNode.addChild(rulePill("Throw-in: \(match.rules.allowThrowIn ? "On" : "Off")", name: "ctrl_throwin", at: CGPoint(x: xa[0], y: rowA)))
        controlsNode.addChild(rulePill("On take: \(match.rules.throwInOnTake ? "On" : "Off")", name: "ctrl_throwontake", at: CGPoint(x: xa[1], y: rowA)))
        let order = match.rules.throwInPriority == .principalFirst ? "Principal" : "Round-robin"
        controlsNode.addChild(rulePill("Priority: \(order)", name: "ctrl_priority", at: CGPoint(x: xa[2], y: rowA)))
        controlsNode.addChild(rulePill("First ≤5: \(match.rules.firstAttackMaxFive ? "On" : "Off")", name: "ctrl_firstmax", at: CGPoint(x: xa[3], y: rowA)))

        let rowB: CGFloat = 54
        let xb: [CGFloat] = [cx - 172, cx, cx + 172]
        controlsNode.addChild(rulePill("Players: \(match.playerCount)", name: "ctrl_players", at: CGPoint(x: xb[0], y: rowB)))
        controlsNode.addChild(rulePill("Teaching: \(match.teachingDurak ? "On" : "Off")", name: "ctrl_teaching", at: CGPoint(x: xb[1], y: rowB)))
        controlsNode.addChild(rulePill("Lose at: \(match.lossLimit == 0 ? "∞" : String(match.lossLimit))", name: "ctrl_loselimit", at: CGPoint(x: xb[2], y: rowB)))
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

    private func statusText() -> String {
        if game.outcome(state) != nil {
            if match.isOver, let loser = match.loser {
                let who = loser == me ? "You" : "Player \(loser.index)"
                return "\(who) lost the match (\(match.lossLimit) losses)  —  click for a new match"
            }
            if let durak = match.lastDurak {
                let who = durak == me ? "You are" : "Player \(durak.index) is"
                return "\(who) the durak this round  —  click for the next round"
            }
            return "Round drawn  —  click for the next round"
        }
        let trump = "Trump \(state.trump.symbol)"
        if busy || state.core.currentSeat != me {
            return "\(trump)   ·   Player \(state.core.currentSeat.index) is playing…"
        }
        let role = me == state.defender ? "you defend" : "you attack"
        let action: String
        switch state.phase {
        case .attacking: action = "attack"
        case .defending: action = "defend, or Take"
        case .takingThrowIn: action = "throw in more, or Done"
        }
        let mine = match.losses(for: me)
        let losses = mine > 0 ? "   ·   your losses: \(mine)" : ""
        return "\(trump)   ·   \(role) — \(action)\(losses)"
    }

    private func hintText() -> String {
        if game.outcome(state) != nil { return "" }
        guard state.core.currentSeat == me, !busy else { return "" }
        if selectedCard != nil { return "Click the card again or Play to confirm  ·  click elsewhere to cancel" }
        switch state.phase {
        case .attacking: return "Click a card to attack"
        case .defending: return "Click a card to beat the attack, or Take"
        case .takingThrowIn: return "Throw in matching cards, or click Done"
        }
    }
}
