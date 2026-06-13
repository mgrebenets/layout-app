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
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

final class DurakScene: PointerInputScene {

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
    private var seed: UInt64 = 0   // the current round's deal seed — shown in the settings sheet
    /// Set by the SwiftUI host — the in-scene chrome buttons (back / gear) invoke these.
    var onBack: (() -> Void)?
    var onOpenSettings: (() -> Void)?

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

    // MARK: - External configuration (driven by the SwiftUI settings sheet)

    var currentPlayerCount: Int { match.playerCount }
    var currentRules: DurakRules { match.rules }
    var currentLossLimit: Int { match.lossLimit }
    var currentTeaching: Bool { match.teachingDurak }
    var currentSeed: UInt64 { seed }

    /// Apply new match settings and start a fresh match.
    func applyConfig(playerCount: Int, rules: DurakRules, lossLimit: Int, teaching: Bool) {
        match = DurakMatch(playerCount: playerCount, rules: rules, lossLimit: lossLimit, teachingDurak: teaching)
        startRound()
    }

    /// Deal a specific seed with the current settings.
    func dealSeed(_ value: UInt64) { startRound(seed: value) }

    private func startRound(seed newSeed: UInt64? = nil) {
        seed = newSeed ?? UInt64.random(in: 1...999_999_999)
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
            self.renderStaticUI()   // refresh the action badge now that the deal is done (busy = false)
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

    override func pointerDown(at point: CGPoint, tapCount: Int) {
        let hit = nodes(at: point)
        // Chrome (always available): back to the menu, or open the settings sheet.
        if hit.contains(where: { $0.name == "btn_back" }) { onBack?(); return }
        if hit.contains(where: { $0.name == "btn_settings" }) { onOpenSettings?(); return }
        guard !busy else { return }
        if game.outcome(state) != nil {
            if match.isOver { startMatch() } else { startRound() }
            return
        }
        guard state.core.currentSeat == me else { return }
        if hit.contains(where: { $0.name == "btn_action" }), let move = actionState().move { humanMove(move); return }

        // A hand card: double-tap plays it directly; otherwise begin a drag.
        if let card = cardID(at: hit), state.core[hand(me)]?.contains(card) == true {
            if tapCount >= 2 { playCard(card) } else { beginDrag(card, at: point) }
        }
    }

    override func pointerMoved(to point: CGPoint) {
        guard let card = dragCard, let node = cardTable.node(card.value) else { return }
        if hypot(point.x - dragStart.x, point.y - dragStart.y) > 6 { dragMoved = true }
        node.position = CGPoint(x: point.x + dragOffset.x, y: point.y + dragOffset.y)
    }

    override func pointerUp(at point: CGPoint) {
        guard let card = dragCard else { return }
        let moved = dragMoved
        clearDragHighlights()
        dragCard = nil
        // A drag plays the card on drop; a bare click (no drag) does nothing for a single card.
        if moved { resolveDrop(card, at: point) } else { snapBack() }
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
        if point.y > handY + handCardSize.height / 2 + 8 { // dragged up out of the hand → a play
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

    private var isPortrait: Bool { size.height > size.width * 1.1 }

    /// True only on iPhone, where landscape is vertically cramped. iPad and macOS have room to stack UI, so
    /// the action badge goes above the hand (not in a side corner) and the hand keeps its full width.
    private var isCompactPhone: Bool {
        #if os(iOS)
        return UIDevice.current.userInterfaceIdiom == .phone
        #else
        return false
        #endif
    }
    /// Reserve the bottom-right corner for the action badge (shrinking the hand) only on iPhone landscape.
    private var reservesBadgeCorner: Bool { !isPortrait && isCompactPhone }

    /// Horizontal play area, inset by the side safe-areas (the Dynamic Island sits on a side in landscape).
    private var safeWidth: CGFloat { max(1, size.width - leftSafeInset - rightSafeInset) }
    private var safeCenterX: CGFloat { leftSafeInset + safeWidth / 2 }

    /// Table cards: as large as fits a fraction of the width, capped by height.
    private var cardSize: CGSize {
        isPortrait
            ? CardMetrics.fit(maxWidth: safeWidth * 0.16, maxHeight: size.height * 0.13)
            : CardMetrics.fit(maxWidth: safeWidth * 0.082, maxHeight: size.height * 0.165)
    }
    /// Your own hand is drawn larger than the table cards so it fills the bottom and is easy to grab.
    private var handCardSize: CGSize {
        isPortrait
            ? CardMetrics.fit(maxWidth: safeWidth * 0.24, maxHeight: size.height * 0.34)
            : CardMetrics.fit(maxWidth: safeWidth * 0.15, maxHeight: size.height * 0.7)
    }
    /// Opponents' (face-down) cards are smaller so several fans fit around the top.
    private var opponentCardSize: CGSize { CGSize(width: cardSize.width * 0.62, height: cardSize.height * 0.62) }
    /// Your hand sits at the bottom: portrait flush, full-height. Landscape (short): bigger cards pushed down
    /// so ~62% peeks above the bottom — grab the visible top and drag up; the bottom runs off-screen.
    private var handY: CGFloat {
        isPortrait
            ? handCardSize.height / 2
            : handCardSize.height * 0.62 - handCardSize.height / 2
    }
    /// The hand fans across this width, centred at this x. iPhone landscape leaves the bottom-right corner for
    /// the action badge; otherwise the hand spans the full width, centred.
    private var handMaxWidth: CGFloat { reservesBadgeCorner ? safeWidth - 84 : safeWidth }
    private var handCenterX: CGFloat { reservesBadgeCorner ? leftSafeInset + handMaxWidth / 2 : safeCenterX }
    private var tableCenter: CGPoint { CGPoint(x: safeCenterX, y: size.height * 0.52) }
    /// Stock (trump beside it) and discard hug the safe-area edges so they clear the Dynamic Island: pushed
    /// in on whichever side the island is on, at the edge on the free side.
    private var deckPos: CGPoint { CGPoint(x: leftSafeInset + cardSize.width / 2 + 8, y: size.height * 0.5) }
    private var discardPos: CGPoint { CGPoint(x: size.width - rightSafeInset - cardSize.width / 2 - 8, y: size.height * 0.5) }

    /// Seat positions for the 1–3 opponents (centre + horizontal fan width), within the safe width.
    private func opponentLayout(_ count: Int) -> [(center: CGPoint, fanWidth: CGFloat)] {
        let x0 = leftSafeInset, w = safeWidth
        if isPortrait {
            let h = size.height
            switch count {
            case 1:  return [(CGPoint(x: x0 + w * 0.50, y: h * 0.86), w * 0.34)]
            case 2:  return [(CGPoint(x: x0 + w * 0.30, y: h * 0.85), w * 0.26),
                             (CGPoint(x: x0 + w * 0.70, y: h * 0.85), w * 0.26)]
            default: return [(CGPoint(x: x0 + w * 0.18, y: h * 0.82), w * 0.22),
                             (CGPoint(x: x0 + w * 0.50, y: h * 0.88), w * 0.28),
                             (CGPoint(x: x0 + w * 0.82, y: h * 0.82), w * 0.22)]
            }
        } else {
            // Landscape: a single row just below the top bar, spread across the safe width.
            let y = topBarY - opponentCardSize.height / 2 - 28
            let fan = min(w * 0.22, 210)
            switch count {
            case 1:  return [(CGPoint(x: x0 + w * 0.50, y: y), fan)]
            case 2:  return [(CGPoint(x: x0 + w * 0.32, y: y), fan),
                             (CGPoint(x: x0 + w * 0.68, y: y), fan)]
            default: return [(CGPoint(x: x0 + w * 0.22, y: y), fan),
                             (CGPoint(x: x0 + w * 0.50, y: y), fan),
                             (CGPoint(x: x0 + w * 0.78, y: y), fan)]
            }
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
        placeHand(s, seat: me, faceUp: true, center: CGPoint(x: handCenterX, y: handY),
                  cardSize: handCardSize, maxWidth: handMaxWidth, baseZ: 3000, into: &p)
        let opponents = (1..<s.core.seatCount).map { SeatID($0) }
        let layout = opponentLayout(opponents.count)
        for (i, seat) in opponents.enumerated() {
            placeHand(s, seat: seat, faceUp: false, center: layout[i].center,
                      cardSize: opponentCardSize, maxWidth: layout[i].fanWidth, baseZ: 4000 + CGFloat(i) * 200, into: &p)
        }
        return p
    }

    /// Fan a seat's cards across `maxWidth`, centred on `center`, overlapping as needed when the hand grows.
    /// A flat row — all cards on the same line.
    private func placeHand(_ s: DurakState, seat: SeatID, faceUp: Bool, center: CGPoint, cardSize: CGSize,
                           maxWidth: CGFloat, baseZ: CGFloat, into p: inout [Int: CardPlacement]) {
        var cards = s.core[hand(seat)]?.cards ?? []
        guard !cards.isEmpty else { return }
        // Sort the player's own (face-up) hand by rank — suit as a stable tiebreaker — so it reads tidily.
        // Opponents stay in dealt order (face-down, so it doesn't matter).
        if faceUp {
            cards.sort { a, b in
                let fa = s.registry.face(a), fb = s.registry.face(b)
                return fa.rank != fb.rank ? fa.rank < fb.rank : fa.suit < fb.suit
            }
        }
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

        drawChrome()
        drawTopBar()

        let opponents = (1..<match.playerCount).map { SeatID($0) }
        let layout = opponentLayout(opponents.count)
        for (i, seat) in opponents.enumerated() {
            let center = layout[i].center
            let isTurn = state.core.currentSeat == seat && game.outcome(state) == nil
            let count = state.core[hand(seat)]?.count ?? 0
            // shield = defending · 🏳️ = gave up/taking · ⚔️ = acting attacker · hourglass = waiting.
            let symbol: String?
            let emoji: String?
            if seat == state.defender {
                if state.phase == .takingThrowIn { symbol = nil; emoji = "🏳️" }   // gave up — white flag
                else { symbol = "shield"; emoji = nil }                            // defending (outline; filled reads heavy on green)
            } else if isTurn {
                symbol = nil; emoji = "⚔️"
            } else {
                symbol = "hourglass"; emoji = nil
            }
            let badge = playerBadge(symbol: symbol, emoji: emoji, count: count, highlighted: isTurn)
            badge.position = CGPoint(x: center.x, y: center.y - opponentCardSize.height / 2 - 18)
            uiNode.addChild(badge)
        }

        drawActionBadge()

        // A centered message only when the round/match is over (tap anywhere for the next deal).
        statusLabel.position = CGPoint(x: size.width / 2, y: size.height * 0.45)
        statusLabel.text = terminalText()
        hintLabel.text = ""
    }

    /// A match bar pinned along the top: each player's loss tally (with the loss limit), the trump, the deck
    /// count, and the deal seed. Fills the otherwise-empty top strip with the at-a-glance match state.
    private func drawTopBar() {
        let barHeight: CGFloat = isPortrait ? 28 : 34
        let cy = topBarY
        let stripWidth = safeWidth - 120 // leave the corners (within the safe area) for the back / gear buttons
        let strip = SKShapeNode(rectOf: CGSize(width: stripWidth, height: barHeight), cornerRadius: barHeight / 2)
        strip.fillColor = SKColor(white: 1.0, alpha: 0.08)
        strip.strokeColor = SKColor(white: 1.0, alpha: 0.18)
        strip.position = CGPoint(x: safeCenterX, y: cy)
        uiNode.addChild(strip)

        let scores = (0..<match.playerCount).map { s -> String in
            let seat = SeatID(s)
            return "\(seat == me ? "You" : "P\(s)") ✖\(match.losses(for: seat))"
        }.joined(separator: "  ")
        let limit = match.lossLimit > 0 ? " (to \(match.lossLimit))" : ""
        let deckCount = state.core[.deck]?.count ?? 0
        let sep = isPortrait ? "  ·  " : "      ·      "
        let label = centeredLabel(
            "\(scores)\(limit)\(sep)Trump \(state.trump.symbol)\(sep)Deck \(deckCount)",
            size: isPortrait ? 12 : 14)
        // Shrink to fit the strip if the text is wider than the bar (long scoreboard on a narrow phone).
        let maxWidth = stripWidth - 16
        if label.frame.width > maxWidth { label.fontSize *= maxWidth / label.frame.width }
        label.position = CGPoint(x: safeCenterX, y: cy)
        uiNode.addChild(label)
    }

    /// The single top row, below the status bar: the scoreboard pill centred (within the safe width), flanked
    /// by the back/gear buttons in the corners (inset from the side safe-areas / Dynamic Island).
    private var topBarY: CGFloat { size.height - topSafeInset - 22 }
    private func drawChrome() {
        let back = chromeButton("xmark", name: "btn_back")
        back.position = CGPoint(x: leftSafeInset + 30, y: topBarY)
        uiNode.addChild(back)
        let gear = chromeButton("gearshape", name: "btn_settings")
        gear.position = CGPoint(x: size.width - rightSafeInset - 30, y: topBarY)
        uiNode.addChild(gear)
    }

    private func chromeButton(_ symbol: String, name: String) -> SKNode {
        let circle = SKShapeNode(circleOfRadius: 19)
        circle.fillColor = SKColor(white: 0, alpha: 0.30)
        circle.strokeColor = SKColor(white: 1, alpha: 0.25)
        circle.lineWidth = 1
        circle.name = name
        if let texture = Self.symbolTexture(symbol, pointSize: 16) {
            let icon = SKSpriteNode(texture: texture)
            icon.color = .white
            icon.colorBlendFactor = 1   // tint the (template) symbol white
            icon.name = name
            circle.addChild(icon)
        }
        return circle
    }

    /// Render an SF Symbol to a texture (cross-platform); tinted white at draw time via colorBlendFactor.
    static func symbolTexture(_ name: String, pointSize: CGFloat) -> SKTexture? {
        #if canImport(UIKit)
        let config = UIImage.SymbolConfiguration(pointSize: pointSize, weight: .semibold)
        guard let image = UIImage(systemName: name, withConfiguration: config) else { return nil }
        return SKTexture(image: image)
        #elseif canImport(AppKit)
        let config = NSImage.SymbolConfiguration(pointSize: pointSize, weight: .semibold)
        guard let image = NSImage(systemSymbolName: name, accessibilityDescription: nil)?
            .withSymbolConfiguration(config) else { return nil }
        return SKTexture(image: image)
        #else
        return nil
        #endif
    }

    /// The single action/status badge — replaces the old Take button and the status line. Shows the current
    /// state as one SF Symbol, tappable when there's an action (arrow.down = take · checkmark / forward = pass).
    private func drawActionBadge() {
        let (symbol, emoji, move) = actionState()
        guard symbol != nil || emoji != nil else { return }
        let badge = actionBadgeNode(symbol: symbol, emoji: emoji, name: move != nil ? "btn_action" : "status")
        // iPhone landscape: a reliable bottom-right corner (vertically cramped). Otherwise (portrait, iPad,
        // macOS): centred above the right end of the full-width hand.
        badge.position = reservesBadgeCorner
            ? CGPoint(x: size.width - rightSafeInset - 44, y: bottomSafeInset + 44)
            : CGPoint(x: size.width - rightSafeInset - 46, y: handY + handCardSize.height / 2 + 46)
        controlsNode.addChild(badge)
    }

    /// Current state as (SF Symbol or emoji, tappable move): hourglass = waiting · 🏳️ = give up/take ·
    /// checkmark = done taking · forward.end = pass/bita · arrow.up = your turn to attack (drag up).
    private func actionState() -> (symbol: String?, emoji: String?, move: DurakMove?) {
        guard game.outcome(state) == nil else { return (nil, nil, nil) }
        if busy || state.core.currentSeat != me { return ("hourglass", nil, nil) }
        let legal = game.legalMoves(for: me, in: state)
        if legal.contains(.take) { return (nil, "🏳️", .take) }   // give up — white flag
        if legal.contains(.pass) { return (state.phase == .takingThrowIn ? "checkmark" : "forward.end.fill", nil, .pass) }
        return ("arrow.up", nil, nil)
    }

    /// A small word-free player badge: a leading glyph (SF Symbol or emoji) + card count, in a capsule;
    /// highlighted on the player's turn.
    private func playerBadge(symbol: String?, emoji: String?, count: Int, highlighted: Bool) -> SKNode {
        let tint: SKColor = highlighted ? .black : .white
        let capsule = SKShapeNode(rectOf: CGSize(width: 54, height: 26), cornerRadius: 13)
        capsule.fillColor = highlighted ? SKColor.systemYellow.withAlphaComponent(0.9) : SKColor(white: 0, alpha: 0.28)
        capsule.strokeColor = highlighted ? .systemYellow : SKColor(white: 1, alpha: 0.25)
        capsule.lineWidth = 1
        if let symbol, let texture = Self.symbolTexture(symbol, pointSize: 14) {
            let icon = SKSpriteNode(texture: texture)
            icon.color = tint
            icon.colorBlendFactor = 1
            icon.position = CGPoint(x: -11, y: 0)
            icon.zPosition = 1
            capsule.addChild(icon)
        } else if let emoji {
            let glyph = SKLabelNode(text: emoji)
            glyph.fontSize = 15
            glyph.verticalAlignmentMode = .center
            glyph.horizontalAlignmentMode = .center
            glyph.position = CGPoint(x: -11, y: 0)
            glyph.zPosition = 1
            capsule.addChild(glyph)
        }
        let countLabel = SKLabelNode(text: "\(count)")
        countLabel.fontName = "AvenirNext-DemiBold"
        countLabel.fontSize = 15
        countLabel.fontColor = tint
        countLabel.verticalAlignmentMode = .center
        countLabel.horizontalAlignmentMode = .center
        countLabel.position = CGPoint(x: 12, y: 0)
        countLabel.zPosition = 1
        capsule.addChild(countLabel)
        return capsule
    }

    private func actionBadgeNode(symbol: String?, emoji: String?, name: String) -> SKNode {
        let tappable = name == "btn_action"
        let circle = SKShapeNode(circleOfRadius: 30)
        circle.fillColor = tappable ? SKColor(white: 1.0, alpha: 0.16) : SKColor(white: 0, alpha: 0.28)
        circle.strokeColor = tappable ? SKColor(white: 1.0, alpha: 0.55) : SKColor(white: 1.0, alpha: 0.2)
        circle.lineWidth = tappable ? 2 : 1
        circle.name = name
        if let symbol, let texture = Self.symbolTexture(symbol, pointSize: 24) {
            let icon = SKSpriteNode(texture: texture)
            icon.color = .white
            icon.colorBlendFactor = 1
            icon.name = name
            icon.zPosition = 1
            circle.addChild(icon)
        } else if let emoji {
            let label = SKLabelNode(text: emoji)
            label.fontSize = 28
            label.verticalAlignmentMode = .center
            label.horizontalAlignmentMode = .center
            label.name = name
            label.zPosition = 1
            circle.addChild(label)
        }
        return circle
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

    private func terminalText() -> String {
        guard game.outcome(state) != nil else { return "" }
        if match.isOver, let loser = match.loser {
            let who = loser == me ? "You" : "Player \(loser.index)"
            return "\(who) lost the match  —  tap for a new match"
        }
        if let durak = match.lastDurak {
            let who = durak == me ? "You are" : "Player \(durak.index) is"
            return "\(who) the durak  —  tap for the next round"
        }
        return "Round drawn  —  tap for the next round"
    }
}
