//
//  BuraScene.swift
//  LayoutApp macOS
//
//  Playable Bura (you vs. a simple AI) on GameEngine's BuraGame. Cards are durable nodes managed by
//  CardTableNode: after each move the scene folds the engine's effect batches one beat at a time and
//  animates every card, so leads, beats, sweeps to the won pile, and refills are watchable (input is
//  locked until the animation settles).
//
//  Input model (per the "less hand-holding, fewer gestures" direction): no standing legal-move
//  highlight. A single click *pops* a card into a pending set; a double-click plays a single card
//  immediately; a context button (Lead / Beat / Give) commits a multi-card set and only appears when
//  the popped set is actually a legal move. Bura needs a set because the leader plays 1–3 same-suit
//  cards and the responder answers with the same number.
//

import SpriteKit
import GameEngine
import LayoutKit

final class BuraScene: SKScene {

    private var rules = BuraRules()
    private var game = BuraGame()
    private var state: BuraState!
    private let ai = BuraAI()
    private var busy = false                     // true while an animation is playing
    private var lastPlacements: [Int: CardPlacement] = [:]
    private var selected: [Int] = []             // popped card values, building a lead/respond set
    private var awaitingTap: (() -> Void)?       // a beat is held on the table until the player clicks

    private let me = SeatID(0)
    private let opp = SeatID(1)
    private let tableCardSize = CGSize(width: 80, height: 112)

    private let cardTable = CardTableNode()
    private let uiNode = SKNode()
    private let controlsNode = SKNode()
    private let statusLabel = SKLabelNode()
    private let hintLabel = SKLabelNode()

    private func won(_ seat: SeatID) -> ZoneID { ZoneID("won", owner: seat) }
    private func face(_ card: CardID) -> StandardFace { state.registry.face(card) }
    private var isMyTurn: Bool { game.outcome(state) == nil && state.core.currentSeat == me }

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
        startGame()
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        guard state != nil, !busy else { return }
        lastPlacements = placements(for: state)
        cardTable.apply(lastPlacements, duration: 0) {}
        renderStaticUI()
    }

    // MARK: - Game flow

    private func startGame() {
        game = BuraGame(rules: rules)
        state = game.setup(seatCount: 2, seed: UInt64.random(in: UInt64.min...UInt64.max))
        selected = []
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

    private func perform(_ move: BuraMove) {
        busy = true
        selected = []
        // After the opponent answers, hold the completed trick (snapshot 0) on the table until the
        // player clicks, so they can see what was beaten or dropped before it sweeps away.
        let holdAfter: Int = {
            if case .respond = move, state.core.currentSeat == opp { return 0 }
            return -1
        }()
        var snapshots: [BuraState] = []
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
        animate(snapshots, 0, holdAfter: holdAfter)
    }

    private func animate(_ snapshots: [BuraState], _ index: Int, holdAfter: Int) {
        guard index < snapshots.count else { finishTurn(); return }
        state = snapshots[index]
        renderStaticUI()
        let advance: () -> Void = { [weak self] in self?.animate(snapshots, index + 1, holdAfter: holdAfter) }
        // After this beat, pause for a tap if asked (and there's more to come).
        let proceed: () -> Void = (index == holdAfter && index + 1 < snapshots.count)
            ? { [weak self] in self?.holdForTap(advance) }
            : advance

        let next = placements(for: state)
        if next == lastPlacements {
            proceed() // nothing moved this beat (e.g. a turn hand-off)
        } else {
            lastPlacements = next
            cardTable.apply(next, duration: 0.3) { proceed() }
        }
    }

    /// Freeze the animation on the current beat; the next click resumes it.
    private func holdForTap(_ resume: @escaping () -> Void) {
        awaitingTap = resume
        renderStaticUI()
    }

    private func finishTurn() {
        busy = false
        renderStaticUI()
        refreshInputLayer()
        scheduleAIIfNeeded()
    }

    /// Re-apply the settled layout so a popped candidate lifts/drops, and re-render the controls so
    /// the commit button (Lead / Beat / Give) appears as soon as the popped set is a legal move.
    private func refreshInputLayer() {
        guard state != nil, !busy else { return }
        renderStaticUI()
        lastPlacements = placements(for: state)
        cardTable.apply(lastPlacements, duration: 0.12) {}
    }

    private func scheduleAIIfNeeded() {
        guard !busy, game.outcome(state) == nil, state.core.currentSeat == opp else { return }
        run(.sequence([.wait(forDuration: 0.45), .run { [weak self] in self?.aiStep() }]))
    }

    private func aiStep() {
        guard !busy, game.outcome(state) == nil, state.core.currentSeat == opp,
              let move = ai.move(for: opp, in: state, game: game) else { return }
        perform(move)
    }

    private func foldInto(_ s: inout BuraState, _ effects: [Effect<BuraEffect>]) {
        for effect in effects {
            switch effect {
            case let .core(coreEffect): s.core.apply(coreEffect)
            case let .game(gameEffect): game.apply(gameEffect, to: &s)
            }
        }
    }

    // MARK: - Input

    override func mouseDown(with event: NSEvent) {
        // A held beat (the opponent's answer shown on the table) resumes on any click.
        if let resume = awaitingTap { awaitingTap = nil; resume(); return }

        let hit = nodes(at: event.location(in: self))

        if hit.contains(where: { $0.name == "ctrl_target" }) {
            rules.winningScore = nextWinningScore(rules.winningScore)
            game = BuraGame(rules: rules); selected = []; renderStaticUI(); refreshInputLayer(); return
        }
        if hit.contains(where: { $0.name == "ctrl_multilead" }) {
            rules.allowMultiCardLead.toggle()
            game = BuraGame(rules: rules); selected = []; renderStaticUI(); refreshInputLayer(); return
        }
        if hit.contains(where: { $0.name == "ctrl_scoring" }) {
            rules.scoring = rules.scoring == .full ? .clearOnly : .full
            game = BuraGame(rules: rules); selected = []; renderStaticUI(); refreshInputLayer(); return
        }
        if hit.contains(where: { $0.name == "ctrl_snos" }) {
            rules.faceDownSurrender.toggle()
            game = BuraGame(rules: rules); selected = []; renderStaticUI(); refreshInputLayer(); return
        }

        guard !busy else { return }
        if game.outcome(state) != nil { startGame(); return }
        guard isMyTurn else { return }

        if hit.contains(where: { $0.name == "btn_claimbura" }) { perform(.claimBura); return }
        if hit.contains(where: { $0.name == "btn_declinebura" }) { perform(.declineBura); return }
        if hit.contains(where: { $0.name == "btn_commit" }) { commitSelection(); return }
        if hit.contains(where: { $0.name == "btn_clear" }) { selected = []; refreshInputLayer(); return }
        if let card = cardID(at: hit) {
            handleCardClick(card, doubleClick: event.clickCount >= 2)
        } else if !selected.isEmpty {
            selected = []
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

    /// Single click pops a card into the pending set; double-click plays a single card outright.
    private func handleCardClick(_ card: CardID, doubleClick: Bool) {
        guard state.phase != .buraOffer else { return }                      // claim/decline only
        guard state.core[.hand(me)]?.contains(card) == true else { return }  // only your own hand
        if doubleClick {
            let move: BuraMove = state.phase == .leading ? .lead([card]) : .respond([card])
            if game.legalMoves(for: me, in: state).contains(move) { perform(move); return }
        }
        toggleSelection(card)
        refreshInputLayer()
    }

    /// Pop/unpop a card. Leads are capped at three same-suit cards; responses at the lead's count.
    private func toggleSelection(_ card: CardID) {
        let value = card.value
        if let i = selected.firstIndex(of: value) { selected.remove(at: i); return }

        switch state.phase {
        case .leading:
            if let firstValue = selected.first {
                let sameSuit = face(card).suit == face(CardID(firstValue)).suit
                selected = (sameSuit && selected.count < min(3, handCount(me))) ? selected + [value] : [value]
            } else {
                selected = [value]
            }
        case .responding:
            if selected.count < state.attack.count { selected.append(value) }
        case .buraOffer:
            break // no card selection during a bura offer
        }
    }

    private func handCount(_ seat: SeatID) -> Int { state.core[.hand(seat)]?.count ?? 0 }

    /// The move the popped set forms, if it's currently legal.
    private func selectionMove() -> BuraMove? {
        guard !selected.isEmpty else { return nil }
        let cards = selected.map { CardID($0) }.sorted()
        let move: BuraMove = state.phase == .leading ? .lead(cards) : .respond(cards)
        return game.legalMoves(for: me, in: state).contains(move) ? move : nil
    }

    private func commitSelection() {
        guard let move = selectionMove() else { return }
        perform(move)
    }

    // MARK: - Card placements (target layout)

    private func placements(for s: BuraState) -> [Int: CardPlacement] {
        var p: [Int: CardPlacement] = [:]
        let midY = size.height / 2

        // Deck on the left, with the trump card (deck bottom) turned up and rotated underneath.
        let deckPos = CGPoint(x: 120, y: midY)
        for (i, card) in (s.core[.deck]?.cards ?? []).enumerated() {
            if i == 0 {
                p[card.value] = CardPlacement(position: CGPoint(x: deckPos.x + 34, y: deckPos.y),
                                              zRotation: .pi / 2, zPosition: 0, size: tableCardSize, faceUp: true)
            } else {
                p[card.value] = CardPlacement(position: deckPos, zPosition: CGFloat(i), size: tableCardSize, faceUp: false)
            }
        }

        // The trick: lead cards in a row; each answer overlaps the card it beats (Durak-style), or
        // tucks *under* the led card on a surrender. A face-down drop shows as a back.
        placeTrick(s, centerY: midY, into: &p)

        // Won piles hugging the right edge, near each player.
        placeWon(s, seat: me, at: CGPoint(x: size.width - 80, y: 150), into: &p)
        placeWon(s, seat: opp, at: CGPoint(x: size.width - 80, y: size.height - 150), into: &p)

        // Hands: yours face-up at the bottom (popped cards lifted), the opponent's face-down on top.
        placeHand(s, seat: me, faceUp: true, rowY: 130, cardHeight: 120, baseZ: 3000, into: &p)
        placeHand(s, seat: opp, faceUp: false, rowY: size.height - 120, cardHeight: 84, baseZ: 4000, into: &p)
        return p
    }

    private func placeTrick(_ s: BuraState, centerY: CGFloat, into p: inout [Int: CardPlacement]) {
        let attack = s.attack
        guard !attack.isEmpty else { return }
        let baseZ: CGFloat = 2000
        let spacing: CGFloat = 118
        let startX = size.width / 2 - spacing * CGFloat(attack.count - 1) / 2

        var attackPos: [CGPoint] = []
        for (k, card) in attack.enumerated() {
            let pos = CGPoint(x: startX + spacing * CGFloat(k), y: centerY)
            attackPos.append(pos)
            p[card.value] = CardPlacement(position: pos, zPosition: baseZ + CGFloat(k) * 4 + 1,
                                          size: tableCardSize, faceUp: s.core.faceUp.contains(card))
        }
        guard !s.response.isEmpty else { return }

        // A full beat pairs each answer with the card it beats; a surrender has no pairing, so the
        // dropped cards tuck under the lead by index.
        let assignment = game.beatAssignment(s.response, attack, in: s)
        let isBeat = assignment != nil
        for (i, card) in s.response.enumerated() {
            let j = assignment?[i] ?? min(i, attack.count - 1)
            let anchor = attackPos[j]
            let dx: CGFloat = isBeat ? 24 : -12          // beat: over and to the right; surrender: tucked left
            let dy: CGFloat = isBeat ? -28 : 14
            let z = baseZ + CGFloat(j) * 4 + (isBeat ? 2 : -1) // beat sits above the lead; surrender below
            p[card.value] = CardPlacement(position: CGPoint(x: anchor.x + dx, y: anchor.y + dy),
                                          zPosition: z, size: tableCardSize, faceUp: s.core.faceUp.contains(card))
        }
    }

    private func placeWon(_ s: BuraState, seat: SeatID, at point: CGPoint, into p: inout [Int: CardPlacement]) {
        for (i, card) in (s.core[won(seat)]?.cards ?? []).enumerated() {
            p[card.value] = CardPlacement(position: CGPoint(x: point.x, y: point.y + CGFloat(i) * 0.4),
                                          zPosition: 500 + CGFloat(i), size: tableCardSize, faceUp: false)
        }
    }

    private func placeHand(_ s: BuraState, seat: SeatID, faceUp: Bool, rowY: CGFloat,
                           cardHeight: CGFloat, baseZ: CGFloat, into p: inout [Int: CardPlacement]) {
        let cards = s.core[.hand(seat)]?.cards ?? []
        guard !cards.isEmpty else { return }
        let cardWidth = cardHeight * 0.76
        let maxWidth = size.width * 0.6
        let step = cards.count > 1 ? min(cardWidth + 14, (maxWidth - cardWidth) / CGFloat(cards.count - 1)) : 0
        let startX = size.width / 2 - step * CGFloat(cards.count - 1) / 2
        for (i, card) in cards.enumerated() {
            p[card.value] = CardPlacement(position: CGPoint(x: startX + step * CGFloat(i), y: rowY),
                                          zPosition: baseZ + CGFloat(i),
                                          size: CGSize(width: cardWidth, height: cardHeight),
                                          faceUp: faceUp,
                                          selected: seat == me && selected.contains(card.value))
        }
    }

    // MARK: - Static UI

    private func renderStaticUI() {
        uiNode.removeAllChildren()
        controlsNode.removeAllChildren()

        // Scores + role tags.
        let myScore = state.core.scores[me, default: 0]
        let oppScore = state.core.scores[opp, default: 0]
        uiNode.addChild(textLabel("You  ·  \(myScore) pts\(roleTag(me))", x: size.width / 2, y: 64, size: 15))
        uiNode.addChild(textLabel("Opponent  ·  \(oppScore) pts\(roleTag(opp))",
                                  x: size.width / 2, y: size.height - 56, size: 15))
        uiNode.addChild(textLabel("Deck \(state.core[.deck]?.count ?? 0)   ·   Trump \(state.trump.symbol)",
                                  x: 138, y: size.height / 2 - 96, size: 13))

        drawControls()
        drawRulePills()

        statusLabel.position = CGPoint(x: size.width / 2, y: size.height / 2 + 150)
        statusLabel.text = statusText()
        hintLabel.position = CGPoint(x: size.width / 2, y: size.height / 2 + 124)
        hintLabel.text = hintText()
    }

    private func roleTag(_ seat: SeatID) -> String {
        guard game.outcome(state) == nil else { return "" }
        if seat == state.leader { return "  ·  lead" }
        return state.core.currentSeat == seat ? "  ·  to answer" : ""
    }

    private func drawControls() {
        guard isMyTurn, !busy else { return }
        let point = CGPoint(x: size.width - 130, y: size.height / 2)
        if state.phase == .buraOffer {
            controlsNode.addChild(button("Lead bura", name: "btn_claimbura", at: point))
            controlsNode.addChild(button("Pass", name: "btn_declinebura", at: CGPoint(x: point.x, y: point.y - 52)))
            return
        }
        if let move = selectionMove() {
            controlsNode.addChild(button(commitLabel(for: move), name: "btn_commit", at: point))
        }
        if !selected.isEmpty {
            controlsNode.addChild(button("Clear", name: "btn_clear", at: CGPoint(x: point.x, y: point.y - 52)))
        }
    }

    /// Lead label when leading; when answering, say whether the popped set beats the lead or gives it up.
    private func commitLabel(for move: BuraMove) -> String {
        if case let .respond(cards) = move {
            return game.beatsAll(cards, state.attack, in: state) ? "Beat" : "Give"
        }
        return "Lead"
    }

    private func drawRulePills() {
        let cx = size.width / 2
        let xs: [CGFloat] = [cx - 258, cx - 86, cx + 86, cx + 258]
        let winLabel = rules.winningScore.map { "Win at: \($0)" } ?? "Win at: end"
        controlsNode.addChild(rulePill(winLabel, name: "ctrl_target", at: CGPoint(x: xs[0], y: 26)))
        controlsNode.addChild(rulePill("Count: \(rules.scoring == .full ? "Full" : "Clear")",
                                       name: "ctrl_scoring", at: CGPoint(x: xs[1], y: 26)))
        controlsNode.addChild(rulePill("Snos: \(rules.faceDownSurrender ? "closed" : "open")",
                                       name: "ctrl_snos", at: CGPoint(x: xs[2], y: 26)))
        controlsNode.addChild(rulePill("Multi-lead: \(rules.allowMultiCardLead ? "On" : "Off")",
                                       name: "ctrl_multilead", at: CGPoint(x: xs[3], y: 26)))
    }

    /// Cycle the win threshold: play-to-end (nil) → 31 → 41 → play-to-end.
    private func nextWinningScore(_ current: Int?) -> Int? {
        switch current {
        case .none: return 31
        case .some(31): return 41
        default: return nil
        }
    }

    private func statusText() -> String {
        let trump = "Trump \(state.trump.symbol)"
        if let outcome = game.outcome(state) {
            let myScore = state.core.scores[me, default: 0], oppScore = state.core.scores[opp, default: 0]
            switch outcome {
            case .draw: return "Draw \(myScore)–\(oppScore)  —  click for a new game"
            case .winner(let seat):
                return "\(seat == me ? "You win" : "Opponent wins") \(myScore)–\(oppScore)  —  click for a new game"
            case .winners(let seats):
                return "\(seats.contains(me) ? "You win" : "Opponent wins") \(myScore)–\(oppScore)  —  click for a new game"
            }
        }
        if awaitingTap != nil { return "\(trump)   ·   click to continue" }
        if busy || state.core.currentSeat != me {
            return "\(trump)   ·   Opponent is playing…"
        }
        switch state.phase {
        case .leading: return "\(trump)   ·   your lead"
        case .responding: return "\(trump)   ·   you answer"
        case .buraOffer: return "\(trump)   ·   you hold bura — take the lead or pass"
        }
    }

    private func hintText() -> String {
        if awaitingTap != nil { return "Click anywhere to continue" }
        guard isMyTurn, !busy else { return "" }
        if !selected.isEmpty {
            return selectionMove() != nil
                ? "Double-click commits too  ·  click elsewhere to clear"
                : "Pick \(neededCount()) card\(neededCount() == 1 ? "" : "s")  ·  click elsewhere to clear"
        }
        switch state.phase {
        case .leading:
            return rules.allowMultiCardLead
                ? "Double-click to lead one, or click 1–3 same-suit cards then Lead"
                : "Click a card to lead, or double-click it"
        case .responding:
            let n = state.attack.count
            return n == 1 ? "Beat the lead or give a card — double-click, or pick then commit"
                          : "Pick \(n) cards to beat all, or give \(n) — then commit"
        case .buraOffer:
            return "Three trumps — take the lead, or pass to let the opponent lead"
        }
    }

    private func neededCount() -> Int {
        state.phase == .responding ? state.attack.count : selected.count
    }

    // MARK: - UI builders

    private func button(_ text: String, name: String, at point: CGPoint) -> SKNode {
        let pill = SKShapeNode(rectOf: CGSize(width: 150, height: 38), cornerRadius: 19)
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
}
