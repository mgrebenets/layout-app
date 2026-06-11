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

    // Drag-and-drop state for the human's single-card plays.
    private var dragCard: CardID?
    private var dragStart: CGPoint = .zero
    private var dragOffset: CGPoint = .zero
    private var dragMoved = false

    private let me = SeatID(0)
    private var seed: UInt64 = 0   // the current round's deal seed — shown in the top bar

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
        // Re-flow on any resize — including the SpriteView's initial resize from the scene's start size to
        // the real window, which lands mid-deal-animation. Skip only mid-drag. (Card moves are keyed, so a
        // re-apply replaces rather than races the in-flight deal.)
        guard state != nil, dragCard == nil else { return }
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
        seed = UInt64.random(in: 1...999_999_999)
        state = match.newRound(seed: seed)
        roundResolved = false
        dragCard = nil
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
        dragCard = nil
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

    #if os(macOS) // pointer input — iOS touch handling is a later step
    override func mouseDown(with event: NSEvent) {
        let point = event.location(in: self)
        let hit = nodes(at: point)

        // Rule pills are allowed even mid-animation.
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

        // A hand card: double-click plays it directly; otherwise begin a drag.
        if let card = cardID(at: hit), state.core[hand(me)]?.contains(card) == true {
            if event.clickCount >= 2 { playCard(card) } else { beginDrag(card, at: point) }
        }
    }

    override func mouseDragged(with event: NSEvent) {
        guard let card = dragCard, let node = cardTable.node(card.value) else { return }
        let point = event.location(in: self)
        if hypot(point.x - dragStart.x, point.y - dragStart.y) > 6 { dragMoved = true }
        node.position = CGPoint(x: point.x + dragOffset.x, y: point.y + dragOffset.y)
    }

    override func mouseUp(with event: NSEvent) {
        guard let card = dragCard else { return }
        let point = event.location(in: self)
        let moved = dragMoved
        clearDragHighlights()
        dragCard = nil
        // A drag plays the card on drop; a bare click (no drag) does nothing for a single card.
        if moved { resolveDrop(card, at: point) } else { snapBack() }
    }
    #endif

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

    /// Lift a hand card to drag it; while defending, reactively outline the attacks it can beat (the only
    /// highlight in the new UX — no standing legal-move glow).
    private func beginDrag(_ card: CardID, at point: CGPoint) {
        guard let node = cardTable.node(card.value) else { return }
        dragCard = card
        dragStart = point
        dragMoved = false
        dragOffset = CGPoint(x: node.position.x - point.x, y: node.position.y - point.y)
        node.setLayer(90_000)
        if state.phase == .defending {
            for pair in state.table where pair.defense == nil
                && DurakGame.beats(state.registry.face(card), state.registry.face(pair.attack), trump: state.trump) {
                cardTable.node(pair.attack.value)?.setHighlighted(true)
            }
        }
    }

    /// Resolve a drop: above the hand is a play (attack, or defend the attack under the cursor / leftmost it
    /// can beat); otherwise — or if the play is illegal — the card snaps home.
    private func resolveDrop(_ card: CardID, at point: CGPoint) {
        var move: DurakMove?
        if point.y > handY + cardSize.height * 0.2 { // dragged up out of the hand → a play
            switch state.phase {
            case .attacking, .takingThrowIn:
                move = .attack(card)
            case .defending:
                move = defenseMove(with: card, onto: attackCard(at: point)) ?? defenseMove(with: card)
            }
        }
        if let move, game.legalMoves(for: me, in: state).contains(move) {
            perform(move)
        } else {
            snapBack()
        }
    }

    /// Double-click play: attack with the card, or beat the leftmost attack it can in defence.
    private func playCard(_ card: CardID) {
        let move: DurakMove?
        switch state.phase {
        case .attacking, .takingThrowIn: move = .attack(card)
        case .defending: move = defenseMove(with: card)
        }
        if let move { humanMove(move) }
    }

    /// A legal defence using `card`, optionally against a specific attack (else the leftmost it can beat).
    private func defenseMove(with card: CardID, onto attack: CardID? = nil) -> DurakMove? {
        game.legalMoves(for: me, in: state).first {
            guard case let .defend(a, w) = $0 else { return false }
            return w == card && (attack == nil || a == attack)
        }
    }

    /// The undefended attack whose card node contains `point` (for targeted defence drops).
    private func attackCard(at point: CGPoint) -> CardID? {
        for pair in state.table where pair.defense == nil {
            if let node = cardTable.node(pair.attack.value), node.contains(point) { return pair.attack }
        }
        return nil
    }

    private func snapBack() {
        lastPlacements = placements(for: state)
        cardTable.apply(lastPlacements, duration: 0.16) {}
    }

    private func clearDragHighlights() {
        for pair in state.table { cardTable.node(pair.attack.value)?.setHighlighted(false) }
    }

    private func humanMove(_ move: DurakMove) {
        guard !busy, game.outcome(state) == nil, state.core.currentSeat == me,
              game.legalMoves(for: me, in: state).contains(move) else { return }
        perform(move)
    }

    // MARK: - Geometry (responsive — cards scale with the window, like Solitaire, via CardMetrics)

    /// Your hand / table cards: as large as fits a fraction of the width, capped by height.
    private var cardSize: CGSize { CardMetrics.fit(maxWidth: size.width * 0.082, maxHeight: size.height * 0.165) }
    /// Opponents' (face-down) cards are smaller so several fans fit around the top.
    private var opponentCardSize: CGSize { CGSize(width: cardSize.width * 0.62, height: cardSize.height * 0.62) }
    /// Your hand sits just above the two rows of rule pills along the bottom.
    private var handY: CGFloat { cardSize.height / 2 + 78 }
    private var tableCenter: CGPoint { CGPoint(x: size.width / 2, y: size.height * 0.52) }
    /// Stock (with the trump turned up beside it) on the left, discard on the right.
    private var deckPos: CGPoint { CGPoint(x: cardSize.width * 0.62 + 24, y: size.height * 0.5) }
    private var discardPos: CGPoint { CGPoint(x: size.width - cardSize.width * 0.62 - 24, y: size.height * 0.5) }
    /// Take / Pass button: right side, in the gap between the hand and the table.
    private var actionButtonPos: CGPoint {
        let handTop = handY + cardSize.height / 2
        let tableBottom = tableCenter.y - cardSize.height / 2
        return CGPoint(x: size.width - 120, y: (handTop + tableBottom) / 2)
    }

    /// Seat positions for the 1–3 opponents (centre + horizontal fan width), arranged around the top so the
    /// table reads nicely at 2, 3, and 4 players.
    private func opponentLayout(_ count: Int) -> [(center: CGPoint, fanWidth: CGFloat)] {
        let w = size.width, h = size.height
        switch count {
        case 1:  return [(CGPoint(x: w * 0.50, y: h * 0.86), w * 0.34)]                  // 2 players: one across
        case 2:  return [(CGPoint(x: w * 0.30, y: h * 0.85), w * 0.26),                  // 3 players: upper corners
                         (CGPoint(x: w * 0.70, y: h * 0.85), w * 0.26)]
        default: return [(CGPoint(x: w * 0.18, y: h * 0.82), w * 0.22),                  // 4 players: corners + top
                         (CGPoint(x: w * 0.50, y: h * 0.88), w * 0.28),
                         (CGPoint(x: w * 0.82, y: h * 0.82), w * 0.22)]
        }
    }

    // MARK: - Card placements (target layout)

    private func placements(for s: DurakState) -> [Int: CardPlacement] {
        var p: [Int: CardPlacement] = [:]
        let cardSize = self.cardSize

        // Stock, with the trump turned face-up sideways beside it.
        let deck = deckPos
        for (i, card) in (s.core[.deck]?.cards ?? []).enumerated() {
            if i == 0 {
                p[card.value] = CardPlacement(position: CGPoint(x: deck.x + cardSize.width * 0.5, y: deck.y),
                                              zRotation: .pi / 2, zPosition: 0, size: cardSize, faceUp: true)
            } else {
                p[card.value] = CardPlacement(position: deck, zPosition: CGFloat(i), size: cardSize, faceUp: false)
            }
        }

        // Discard pile (face down, off to the right).
        for (i, card) in (s.core[.discard]?.cards ?? []).enumerated() {
            p[card.value] = CardPlacement(position: discardPos, zPosition: 1000 + CGFloat(i), size: cardSize, faceUp: false)
        }

        // Attack / defence pairs across the centre; spacing shrinks if there are many.
        let pairs = s.table
        if !pairs.isEmpty {
            let spacing = min(cardSize.width * 1.3, (size.width * 0.66) / CGFloat(pairs.count))
            var x = tableCenter.x - CGFloat(pairs.count - 1) * spacing / 2
            for (k, pair) in pairs.enumerated() {
                p[pair.attack.value] = CardPlacement(position: CGPoint(x: x, y: tableCenter.y),
                                                     zPosition: 2000 + CGFloat(k) * 2, size: cardSize, faceUp: true)
                if let defense = pair.defense {
                    p[defense.value] = CardPlacement(position: CGPoint(x: x + cardSize.width * 0.22, y: tableCenter.y - cardSize.height * 0.22),
                                                     zPosition: 2000 + CGFloat(k) * 2 + 1, size: cardSize, faceUp: true)
                }
                x += spacing
            }
        }

        // Your hand along the bottom; opponents fanned around the top per player count.
        placeHand(s, seat: me, faceUp: true, center: CGPoint(x: size.width / 2, y: handY),
                  cardSize: cardSize, maxWidth: size.width * 0.9, baseZ: 3000, into: &p)
        let opponents = (1..<s.core.seatCount).map { SeatID($0) }
        let layout = opponentLayout(opponents.count)
        for (i, seat) in opponents.enumerated() {
            placeHand(s, seat: seat, faceUp: false, center: layout[i].center,
                      cardSize: opponentCardSize, maxWidth: layout[i].fanWidth, baseZ: 4000 + CGFloat(i) * 200, into: &p)
        }
        return p
    }

    /// Fan a seat's cards across `maxWidth`, centred on `center`, overlapping as needed when the hand grows.
    private func placeHand(_ s: DurakState, seat: SeatID, faceUp: Bool, center: CGPoint, cardSize: CGSize,
                           maxWidth: CGFloat, baseZ: CGFloat, into p: inout [Int: CardPlacement]) {
        let cards = s.core[hand(seat)]?.cards ?? []
        guard !cards.isEmpty else { return }
        let step = cards.count > 1 ? min(cardSize.width + 6, (maxWidth - cardSize.width) / CGFloat(cards.count - 1)) : 0
        let startX = center.x - step * CGFloat(cards.count - 1) / 2
        for (i, card) in cards.enumerated() {
            p[card.value] = CardPlacement(position: CGPoint(x: startX + step * CGFloat(i), y: center.y),
                                          zPosition: baseZ + CGFloat(i), size: cardSize, faceUp: faceUp)
        }
    }

    // MARK: - Static UI (labels, pills, buttons, status)

    private func renderStaticUI() {
        uiNode.removeAllChildren()
        controlsNode.removeAllChildren()

        drawTopBar()

        let opponents = (1..<match.playerCount).map { SeatID($0) }
        let layout = opponentLayout(opponents.count)
        for (i, seat) in opponents.enumerated() {
            let center = layout[i].center
            let isTurn = state.core.currentSeat == seat && game.outcome(state) == nil
            let role = seat == state.defender ? "Defender"
                     : seat == state.principalAttacker ? "Lead attacker" : "Attacker"
            let count = state.core[hand(seat)]?.count ?? 0
            let label = textLabel("Player \(seat.index)  ·  \(role)  ·  \(count)",
                                  x: center.x, y: center.y - opponentCardSize.height / 2 - 16, size: 13)
            label.fontColor = isTurn ? .systemYellow : SKColor(white: 1.0, alpha: 0.85)
            if isTurn { label.fontName = "AvenirNext-Bold" }
            uiNode.addChild(label)
        }

        drawControls()
        drawRulePills()

        let handTop = handY + cardSize.height / 2
        statusLabel.position = CGPoint(x: size.width / 2, y: handTop + 30)
        statusLabel.text = statusText()
        hintLabel.position = CGPoint(x: size.width / 2, y: handTop + 10)
        hintLabel.text = hintText()
    }

    /// A match bar pinned along the top: each player's loss tally (with the loss limit), the trump, the deck
    /// count, and the deal seed. Fills the otherwise-empty top strip with the at-a-glance match state.
    private func drawTopBar() {
        let barHeight: CGFloat = 34
        let cy = size.height - barHeight / 2 - 8
        let strip = SKShapeNode(rectOf: CGSize(width: size.width - 24, height: barHeight), cornerRadius: barHeight / 2)
        strip.fillColor = SKColor(white: 1.0, alpha: 0.08)
        strip.strokeColor = SKColor(white: 1.0, alpha: 0.18)
        strip.position = CGPoint(x: size.width / 2, y: cy)
        uiNode.addChild(strip)

        let scores = (0..<match.playerCount).map { s -> String in
            let seat = SeatID(s)
            return "\(seat == me ? "You" : "P\(s)") ✖\(match.losses(for: seat))"
        }.joined(separator: "   ")
        let limit = match.lossLimit > 0 ? " (to \(match.lossLimit))" : ""
        let deckCount = state.core[.deck]?.count ?? 0
        let label = centeredLabel(
            "\(scores)\(limit)      ·      Trump \(state.trump.symbol)      ·      Deck \(deckCount)      ·      Seed \(seed)",
            size: 14)
        label.position = CGPoint(x: size.width / 2, y: cy)
        uiNode.addChild(label)
    }

    private func drawControls() {
        guard state.core.currentSeat == me, game.outcome(state) == nil, !busy else { return }
        let legal = game.legalMoves(for: me, in: state)
        let point = actionButtonPos
        if legal.contains(.take) {
            controlsNode.addChild(button("Take", name: "btn_take", at: point))
        } else if legal.contains(.pass) {
            controlsNode.addChild(button(state.phase == .takingThrowIn ? "Done" : "Pass / Bita", name: "btn_pass", at: point))
        }
    }

    private func drawRulePills() {
        let cx = size.width / 2
        let rowA: CGFloat = 22
        let spanA = min(172, (size.width - 60) / 4)
        let xa = (0..<4).map { cx + (CGFloat($0) - 1.5) * spanA }
        controlsNode.addChild(rulePill("Throw-in: \(match.rules.allowThrowIn ? "On" : "Off")", name: "ctrl_throwin", at: CGPoint(x: xa[0], y: rowA)))
        controlsNode.addChild(rulePill("On take: \(match.rules.throwInOnTake ? "On" : "Off")", name: "ctrl_throwontake", at: CGPoint(x: xa[1], y: rowA)))
        let order = match.rules.throwInPriority == .principalFirst ? "Principal" : "Round-robin"
        controlsNode.addChild(rulePill("Priority: \(order)", name: "ctrl_priority", at: CGPoint(x: xa[2], y: rowA)))
        controlsNode.addChild(rulePill("First ≤5: \(match.rules.firstAttackMaxFive ? "On" : "Off")", name: "ctrl_firstmax", at: CGPoint(x: xa[3], y: rowA)))

        let rowB: CGFloat = 54
        let spanB = min(172, (size.width - 60) / 3)
        let xb = (0..<3).map { cx + (CGFloat($0) - 1) * spanB }
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
        // Trump, deck, and the loss tally now live in the top bar — keep the status line about the turn.
        if busy || state.core.currentSeat != me {
            return "Player \(state.core.currentSeat.index) is playing…"
        }
        let role = me == state.defender ? "You defend" : "You attack"
        let action: String
        switch state.phase {
        case .attacking: action = "attack"
        case .defending: action = "defend, or Take"
        case .takingThrowIn: action = "throw in more, or Done"
        }
        return "\(role) — \(action)"
    }

    private func hintText() -> String {
        if game.outcome(state) != nil { return "" }
        guard state.core.currentSeat == me, !busy else { return "" }
        switch state.phase {
        case .attacking: return "Drag a card up to attack — or double-click it"
        case .defending: return "Drag a card onto the attack to beat it (or double-click), or Take"
        case .takingThrowIn: return "Drag matching cards in (or double-click), or Done"
        }
    }
}
