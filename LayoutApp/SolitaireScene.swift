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

final class SolitaireScene: PointerInputScene {

    private var rules = SolitaireRules()
    private var game = SolitaireGame()
    private var state: SolitaireState!
    private var busy = false
    private var lastPlacements: [Int: CardPlacement] = [:]
    private let me = SeatID(0)
    private var seed: UInt64 = 0   // the current deal's seed — shown and re-enterable so layouts are reproducible
    /// The SwiftUI host sets this to present its own (cross-platform) seed-entry UI. Keeps platform chrome
    /// out of the scene — see `SolitaireHostView`.
    var onRequestSeedEntry: (() -> Void)?

    // Drag state.
    private var dragCards: [Int] = []                 // card values being dragged (head first)
    private var dragOffsets: [Int: CGPoint] = [:]     // each dragged node's offset from the cursor
    private var dragStart: CGPoint = .zero
    private var dragMoved = false

    private let faceUpFanRatio: CGFloat = 0.28        // fan offsets are a fraction of card height
    private let faceDownFanRatio: CGFloat = 0.13

    private let boardNode = SKNode()      // pile placeholders, behind the cards
    private let cardTable = CardTableNode()
    private let uiNode = SKNode()
    private let controlsNode = SKNode()
    private let statusLabel = SKLabelNode()
    private let messageLabel = SKLabelNode()

    // Win celebrations. On a real win one fires at random; each is also previewable with a key
    // (c = cascade, f = fireworks, g = fan/glow). The cascade is the Microsoft-style waterfall of bouncing
    // cards driven by `update`; fireworks and fan/glow are SKAction-based. Overlay nodes live in cascadeNode.
    private enum Celebration: CaseIterable { case cascade, fireworks, fanGlow, speedy }
    private let cascadeNode = SKNode()
    private let uiZ: CGFloat = 1_000_000  // controls/labels sit above the celebration so they stay readable
    private var celebrating = false
    private var celebrationIsDemo = false // a key-press preview restores the board when it ends; a win doesn't
    private var celebrationKind: Celebration?
    private var cascadeRunning = false    // the cascade physics loop is active (only the cascade uses update)
    private var lastUpdate: TimeInterval = 0
    private var launchAccumulator: TimeInterval = 0
    private var launchQueue: [(texture: SKTexture, start: CGPoint, size: CGSize)] = []
    private var bouncers: [Bouncer] = []
    private var trailSprites: [SKSpriteNode] = []
    private var stampCount = 0

    private struct Bouncer {
        let sprite: SKSpriteNode
        var velocity: CGVector
        var lastStamp: CGPoint
    }

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
        cascadeNode.zPosition = 60 // above the cards, below the controls — the win cascade lives here
        addChild(cascadeNode)
        for node in [uiNode, controlsNode] { node.zPosition = uiZ; addChild(node) }
        configure(statusLabel, size: 15, font: "AvenirNext-DemiBold"); statusLabel.zPosition = uiZ
        configure(messageLabel, size: 26, font: "AvenirNext-Bold"); messageLabel.zPosition = uiZ
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
        // Re-flow on any resize — including the SpriteView's initial resize from the scene's start size
        // to the real window, which lands mid-deal-animation. Skip mid-drag and during the win cascade.
        guard state != nil, dragCards.isEmpty, !celebrating else { return }
        applyState(duration: 0)
    }

    // MARK: - Geometry

    private var margin: CGFloat { 28 }
    private var columnSpacing: CGFloat { (size.width - margin * 2) / 7 }
    private func columnX(_ c: Int) -> CGFloat { margin + columnSpacing * (CGFloat(c) + 0.5) }

    /// Cards scale with the board: width is a fixed fraction of a tableau column (so they grow with the
    /// window), capped by height so a wide-short window can't overflow vertically. 1024×768 ≈ 78×108.
    private var cardSize: CGSize {
        CardMetrics.fit(maxWidth: columnSpacing * 0.564, maxHeight: size.height * 0.155)
    }
    private var faceUpFan: CGFloat { cardSize.height * faceUpFanRatio }
    private var faceDownFan: CGFloat { cardSize.height * faceDownFanRatio }

    private var topRowY: CGFloat { size.height - margin - cardSize.height / 2 }
    private var tableauTopY: CGFloat { topRowY - cardSize.height * 1.22 }
    private var stockPos: CGPoint { CGPoint(x: columnX(0), y: topRowY) }
    private var wastePos: CGPoint { CGPoint(x: columnX(1), y: topRowY) }
    private func foundationPos(_ i: Int) -> CGPoint { CGPoint(x: columnX(3 + i), y: topRowY) }

    private func rect(around center: CGPoint, pad: CGFloat = 0) -> CGRect {
        CGRect(x: center.x - cardSize.width / 2 - pad, y: center.y - cardSize.height / 2 - pad,
               width: cardSize.width + pad * 2, height: cardSize.height + pad * 2)
    }

    // MARK: - Game flow

    private func startGame(seed: UInt64? = nil) {
        stopCelebration()
        self.seed = seed ?? UInt64.random(in: 1...999_999_999) // friendly, shareable game numbers
        game = SolitaireGame(rules: rules)
        state = game.setup(seatCount: 1, seed: self.seed)
        cardTable.reset()
        busy = true
        applyState(duration: 0.3) { [weak self] in self?.busy = false }
    }

    /// The current deal's seed, for the SwiftUI host to display / pre-fill.
    var currentSeed: UInt64 { seed }

    /// Deal a specific seed — called by the host once the player enters one.
    func dealGame(seed: UInt64) { startGame(seed: seed) }

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
        let won = game.outcome(state) != nil
        applyState(duration: 0.2) { [weak self] in
            self?.busy = false
            if won { self?.startWinCelebration() }
        }
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

    override func pointerDown(at point: CGPoint, tapCount: Int) {
        guard !busy else { return }
        let hit = nodes(at: point)

        if hit.contains(where: { $0.name == "ctrl_draw" }) {
            rules.drawCount = rules.drawCount == 1 ? 3 : 1; startGame(); return
        }
        if hit.contains(where: { $0.name == "ctrl_redeals" }) {
            rules.redealLimit = nextRedealLimit(rules.redealLimit); startGame(); return
        }
        if hit.contains(where: { $0.name == "ctrl_seed" }) { onRequestSeedEntry?(); return }
        if hit.contains(where: { $0.name == "btn_newgame" }) { startGame(); return }
        if hit.contains(where: { $0.name == "btn_finish" }) { runAutoFinish(); return }

        if game.outcome(state) != nil { startGame(); return } // click anywhere to start a new deal

        if rect(around: stockPos, pad: 12).contains(point) {
            if game.legalMoves(for: me, in: state).contains(.draw) { perform(.draw) }
            return
        }
        guard let card = cardID(at: hit), let source = zoneContaining(card), isDraggable(card, in: source) else { return }
        beginDrag(card, from: source, at: point)
    }

    override func pointerMoved(to point: CGPoint) {
        guard !dragCards.isEmpty else { return }
        if hypot(point.x - dragStart.x, point.y - dragStart.y) > 6 { dragMoved = true }
        for value in dragCards {
            if let node = cardTable.node(value), let offset = dragOffsets[value] {
                node.position = CGPoint(x: point.x + offset.x, y: point.y + offset.y)
            }
        }
    }

    override func pointerUp(at point: CGPoint) {
        guard !dragCards.isEmpty else { return }
        let head = CardID(dragCards[0])
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
            let dx = -CGFloat(min(fromTop, 2)) * cardSize.width * 0.22
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
        let analysis = SolitaireAnalysis(game: game)
        // No meaningful move left (and not a win) → the deal is dead; nudge the player to start over.
        let deadlocked = !won && analysis.isDeadlocked(state)
        // The board is solved-but-tedious → offer to auto-play it home.
        let canFinish = !won && !deadlocked && analysis.autoFinishPlan(state) != nil
        messageLabel.position = CGPoint(x: size.width / 2, y: size.height * 0.42)
        messageLabel.text = won ? "You win!  —  click for a new game"
            : deadlocked ? "No moves left  —  start a new game" : ""

        let y: CGFloat = 26
        let cx = size.width / 2
        let redeals = rules.redealLimit.map(String.init) ?? "∞"
        let pills = [("Draw: \(rules.drawCount)", "ctrl_draw"),
                     ("Redeals: \(redeals)", "ctrl_redeals"),
                     ("Seed: \(seed)", "ctrl_seed"),
                     ("New game", "btn_newgame")]
        let spacing: CGFloat = 165
        let startX = cx - spacing * CGFloat(pills.count - 1) / 2
        for (i, pill) in pills.enumerated() {
            let emphasized = pill.1 == "btn_newgame" && (won || deadlocked)
            controlsNode.addChild(rulePill(pill.0, name: pill.1,
                                           at: CGPoint(x: startX + spacing * CGFloat(i), y: y), emphasized: emphasized))
        }
        if canFinish {
            controlsNode.addChild(rulePill("Finish", name: "btn_finish", at: CGPoint(x: cx, y: y + 40), emphasized: true))
        }
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

    private func rulePill(_ text: String, name: String, at point: CGPoint, emphasized: Bool = false) -> SKNode {
        let pill = SKShapeNode(rectOf: CGSize(width: 150, height: 30), cornerRadius: 15)
        pill.fillColor = emphasized ? SKColor.systemOrange.withAlphaComponent(0.9) : SKColor(white: 1.0, alpha: 0.12)
        pill.strokeColor = emphasized ? .systemYellow : SKColor(white: 1.0, alpha: 0.4)
        pill.lineWidth = emphasized ? 2.5 : 1
        pill.name = name
        let label = SKLabelNode(text: text)
        label.fontName = "AvenirNext-DemiBold"; label.fontSize = 12; label.fontColor = .white
        label.verticalAlignmentMode = .center; label.horizontalAlignmentMode = .center
        pill.addChild(label)
        pill.position = point
        if emphasized { // a gentle pulse draws the eye to the only useful action left
            pill.run(.repeatForever(.sequence([.scale(to: 1.08, duration: 0.6), .scale(to: 1.0, duration: 0.6)])))
        }
        return pill
    }

    private func configure(_ label: SKLabelNode, size: CGFloat, font: String) {
        label.fontName = font
        label.fontSize = size
        label.fontColor = .white
        label.verticalAlignmentMode = .center
        label.horizontalAlignmentMode = .center
    }

    // MARK: - Win celebrations

    private let launchInterval: TimeInterval = 0.13

    /// SpriteKit's per-frame tick. Only the cascade celebration uses it: launch queued cards on a timer, then
    /// integrate each airborne card under gravity, bounce it off the bottom edge, and stamp a trail — the
    /// classic Windows Solitaire waterfall. Idle otherwise (it only tracks `lastUpdate` for the next `dt`).
    override func update(_ currentTime: TimeInterval) {
        let dt = min(max(currentTime - lastUpdate, 0), 1.0 / 30.0) // clamp so a stutter can't fling cards
        lastUpdate = currentTime
        guard cascadeRunning else { return }

        launchAccumulator += dt
        while launchAccumulator >= launchInterval, !launchQueue.isEmpty {
            launchAccumulator -= launchInterval
            launchNextCard()
        }

        let gravity: CGFloat = 1500, restitution: CGFloat = 0.85
        let floor = cardSize.height / 2
        let step = cardSize.width * 0.18 // stamp a trail copy every fraction of a card travelled
        for i in bouncers.indices {
            var b = bouncers[i]
            b.velocity.dy -= gravity * dt
            var p = b.sprite.position
            p.x += b.velocity.dx * dt
            p.y += b.velocity.dy * dt
            if p.y <= floor, b.velocity.dy < 0 { // bounce off the bottom edge, losing a little energy
                p.y = floor
                b.velocity.dy = -b.velocity.dy * restitution
            }
            b.sprite.position = p
            if hypot(p.x - b.lastStamp.x, p.y - b.lastStamp.y) >= step {
                stampTrail(b.sprite.texture, at: p, size: b.sprite.size)
                b.lastStamp = p
            }
            bouncers[i] = b
        }
        bouncers.removeAll { b in // a card that has drifted off the side is done flying
            let gone = b.sprite.position.x < -cardSize.width * 2 || b.sprite.position.x > size.width + cardSize.width * 2
            if gone { b.sprite.removeFromParent() }
            return gone
        }
        if launchQueue.isEmpty, bouncers.isEmpty { cascadeRunning = false; finishCelebration() }
    }

    /// Fire a random celebration for a real win.
    private func startWinCelebration() {
        startCelebration(Celebration.allCases.randomElement() ?? .cascade, demo: false)
    }

    private func startCelebration(_ kind: Celebration, demo: Bool) {
        guard !celebrating, view != nil, state != nil else { return }
        celebrating = true
        celebrationIsDemo = demo
        celebrationKind = kind
        switch kind {
        case .cascade:   startCascade(demo: demo)
        case .fireworks: startFireworks()
        case .fanGlow:   startFanGlow(demo: demo)
        case .speedy:    startSpeedy(demo: demo)
        }
    }

    // MARK: Cascade

    /// Snapshot cards to textures and queue them to launch. A real win launches the foundation cards top-first
    /// (kings, then queens, …); a preview launches every card from wherever it currently sits.
    private func startCascade(demo: Bool) {
        guard let view else { celebrating = false; return }
        var queue: [(texture: SKTexture, start: CGPoint, size: CGSize)] = []
        if demo {
            for (_, zone) in state.core.zones {
                for card in zone.cards {
                    guard let node = cardTable.node(card.value), let texture = view.texture(from: node) else { continue }
                    queue.append((texture, node.position, cardSize))
                }
            }
            queue.shuffle()
        } else {
            let piles = (0..<4).map { state.core[foundation($0)]?.cards ?? [] }
            let maxDepth = piles.map(\.count).max() ?? 0
            for depth in 0..<maxDepth {
                for f in 0..<4 {
                    let pile = piles[f]; let idx = pile.count - 1 - depth
                    guard idx >= 0, let node = cardTable.node(pile[idx].value),
                          let texture = view.texture(from: node) else { continue }
                    queue.append((texture, foundationPos(f), cardSize))
                }
            }
        }
        guard !queue.isEmpty else { celebrating = false; return }
        launchQueue = queue
        launchAccumulator = launchInterval // launch the first card on the next frame
        cardTable.isHidden = true          // the cascade sprites take over from here
        cascadeRunning = true
    }

    private func launchNextCard() {
        let item = launchQueue.removeFirst()
        let sprite = SKSpriteNode(texture: item.texture, size: item.size)
        sprite.position = item.start
        sprite.zPosition = 100_000 // the live card rides above its own trail
        cascadeNode.addChild(sprite)
        let direction: CGFloat = Bool.random() ? 1 : -1
        let velocity = CGVector(dx: direction * CGFloat.random(in: 120...300),
                                dy: CGFloat.random(in: 0...160)) // a small upward pop; the fall does the rest
        bouncers.append(Bouncer(sprite: sprite, velocity: velocity, lastStamp: item.start))
    }

    /// Drop a non-moving copy of a flying card — these accumulate into the rainbow waterfall.
    private func stampTrail(_ texture: SKTexture?, at point: CGPoint, size: CGSize) {
        guard let texture else { return }
        let stamp = SKSpriteNode(texture: texture, size: size)
        stamp.position = point
        stampCount += 1
        stamp.zPosition = CGFloat(stampCount % 90_000) // newest on top, kept below the live cards
        cascadeNode.addChild(stamp)
        trailSprites.append(stamp)
        if trailSprites.count > 6000 { trailSprites.removeFirst().removeFromParent() } // safety cap
    }

    // MARK: Fireworks

    /// A dozen radial particle bursts over a few seconds, then finish. The board stays put underneath.
    private func startFireworks() {
        var actions: [SKAction] = []
        for _ in 0..<12 {
            actions.append(.run { [weak self] in self?.spawnFireworkBurst() })
            actions.append(.wait(forDuration: 0.32))
        }
        actions.append(.wait(forDuration: 1.0))
        actions.append(.run { [weak self] in self?.finishCelebration() })
        cascadeNode.run(.sequence(actions), withKey: "celebration")
    }

    private func spawnFireworkBurst() {
        let center = CGPoint(x: CGFloat.random(in: size.width * 0.15...size.width * 0.85),
                             y: CGFloat.random(in: size.height * 0.45...size.height * 0.85))
        let baseHue = CGFloat.random(in: 0...1)
        let particles = 30
        let radius = max(3, cardSize.width * 0.045)
        for k in 0..<particles {
            let angle = CGFloat(k) / CGFloat(particles) * .pi * 2 + CGFloat.random(in: -0.08...0.08)
            let speed = CGFloat.random(in: 70...150)
            let dot = SKShapeNode(circleOfRadius: radius)
            let hue = (baseHue + CGFloat.random(in: -0.05...0.05) + 1).truncatingRemainder(dividingBy: 1)
            dot.fillColor = SKColor(hue: hue, saturation: 0.85, brightness: 1.0, alpha: 1.0)
            dot.strokeColor = .clear
            dot.position = center
            dot.zPosition = 50_000
            cascadeNode.addChild(dot)
            let drift = CGVector(dx: cos(angle) * speed, dy: sin(angle) * speed - 40) // -40: a little gravity sag
            let fly = SKAction.move(by: drift, duration: 1.1); fly.timingMode = .easeOut
            let fade = SKAction.sequence([.wait(forDuration: 0.55), .fadeOut(withDuration: 0.55)])
            dot.run(.sequence([.group([fly, fade]), .removeFromParent()]))
        }
    }

    // MARK: Fan / glow

    /// Cards fly out from their piles into a big pulsing sunburst, each rotated to point outward and glinting
    /// with a gold scale-pulse. Sprite copies, so the live board is untouched; a preview settles back.
    private func startFanGlow(demo: Bool) {
        let cards = celebrationSprites(demo: demo)
        guard !cards.isEmpty else { celebrating = false; return }
        cardTable.isHidden = true
        let center = CGPoint(x: size.width / 2, y: size.height * 0.52)
        let radius = min(size.width, size.height) * 0.34
        let n = cards.count
        for (i, card) in cards.enumerated() {
            let sprite = SKSpriteNode(texture: card.texture, size: cardSize)
            sprite.position = card.start
            sprite.zPosition = 40_000 + CGFloat(i)
            cascadeNode.addChild(sprite)
            let angle = CGFloat(i) / CGFloat(n) * .pi * 2
            let target = CGPoint(x: center.x + cos(angle) * radius, y: center.y + sin(angle) * radius)
            let out = SKAction.move(to: target, duration: 0.55); out.timingMode = .easeOut
            let spin = SKAction.rotate(toAngle: angle + .pi / 2, duration: 0.55, shortestUnitArc: true)
            let glow = SKAction.repeatForever(.sequence([.scale(to: 1.14, duration: 0.45), .scale(to: 1.0, duration: 0.45)]))
            sprite.run(.sequence([.wait(forDuration: Double(i) * 0.015), .group([out, spin]), glow]))
        }
        cascadeNode.run(.sequence([.wait(forDuration: 2.8), .run { [weak self] in self?.finishCelebration() }]),
                        withKey: "celebration")
    }

    // MARK: Speedy

    /// Cards go wild: every card zips to a string of random spots all over the screen while spinning around
    /// its centre, pulsing big-then-small, and shimmering through bright colours. Pure fun. (Requested by a
    /// 7-year-old.) A real win keeps the party going until New game; a preview settles back after a few seconds.
    private func startSpeedy(demo: Bool) {
        let cards = celebrationSprites(demo: demo)
        guard !cards.isEmpty else { celebrating = false; return }
        cardTable.isHidden = true
        let palette: [SKColor] = [.systemPink, .systemYellow, .systemTeal, .systemGreen, .systemOrange, .systemPurple, .systemRed]
        for (i, card) in cards.enumerated() {
            let sprite = SKSpriteNode(texture: card.texture, size: cardSize)
            sprite.position = card.start
            sprite.zPosition = 40_000 + CGFloat(i)
            cascadeNode.addChild(sprite)

            // Zip around the screen through a fresh string of random spots, forever.
            let hops = (0..<18).map { _ -> SKAction in
                let hop = SKAction.move(to: randomScreenPoint(), duration: TimeInterval.random(in: 0.25...0.5))
                hop.timingMode = .easeInEaseOut
                return hop
            }
            sprite.run(.repeatForever(.sequence(hops)))
            // Spin around its own centre…
            let spin: CGFloat = (Bool.random() ? 1 : -1) * .pi * 2
            sprite.run(.repeatForever(.rotate(byAngle: spin, duration: TimeInterval.random(in: 0.6...1.2))))
            // …pulse big-then-small…
            sprite.run(.repeatForever(.sequence([.scale(to: 1.35, duration: 0.3), .scale(to: 0.75, duration: 0.3)])))
            // …and shimmer through colours.
            let glow = palette.shuffled().map { SKAction.colorize(with: $0, colorBlendFactor: 0.55, duration: 0.35) }
            sprite.run(.repeatForever(.sequence(glow)))
        }
        cascadeNode.run(.sequence([.wait(forDuration: 4.0), .run { [weak self] in self?.finishCelebration() }]),
                        withKey: "celebration")
    }

    /// Snapshot cards to (texture, start position) for the action-based celebrations. A preview grabs every
    /// card where it sits; a real win grabs the foundation stacks.
    private func celebrationSprites(demo: Bool) -> [(texture: SKTexture, start: CGPoint)] {
        guard let view else { return [] }
        var out: [(texture: SKTexture, start: CGPoint)] = []
        if demo {
            for (_, zone) in state.core.zones {
                for card in zone.cards {
                    guard let node = cardTable.node(card.value), let t = view.texture(from: node) else { continue }
                    out.append((t, node.position))
                }
            }
        } else {
            for f in 0..<4 {
                for card in state.core[foundation(f)]?.cards ?? [] {
                    guard let node = cardTable.node(card.value), let t = view.texture(from: node) else { continue }
                    out.append((t, foundationPos(f)))
                }
            }
        }
        return out
    }

    /// A random point fully on-screen (card-sized padding so cards stay visible). Clamped so it's safe even
    /// in a tiny window.
    private func randomScreenPoint() -> CGPoint {
        CGPoint(x: CGFloat.random(in: cardSize.width...max(cardSize.width + 1, size.width - cardSize.width)),
                y: CGFloat.random(in: cardSize.height...max(cardSize.height + 1, size.height - cardSize.height)))
    }

    // MARK: Lifecycle of a celebration

    /// Called when a celebration's motion is over. A preview restores the board; a real win stays on screen
    /// (locked) until the player starts a new game.
    private func finishCelebration() {
        cascadeRunning = false
        guard celebrationIsDemo else { return }
        stopCelebration()
        applyState(duration: 0)
    }

    private func stopCelebration() {
        celebrating = false
        celebrationIsDemo = false
        celebrationKind = nil
        cascadeRunning = false
        launchQueue = []
        bouncers = []
        trailSprites = []
        launchAccumulator = 0
        stampCount = 0
        cascadeNode.removeAllActions()
        cascadeNode.removeAllChildren()
        cardTable.isHidden = false
    }

    // MARK: - Auto-finish

    /// Play the greedy auto-finish plan, animating each move, then celebrate the win.
    private func runAutoFinish() {
        guard let plan = SolitaireAnalysis(game: game).autoFinishPlan(state), !plan.isEmpty else { return }
        busy = true
        playPlan(plan, index: 0)
    }

    private func playPlan(_ plan: [SolitaireMove], index: Int) {
        guard index < plan.count else {
            busy = false
            if game.outcome(state) != nil { startWinCelebration() }
            return
        }
        foldInto(&state, game.lower(plan[index], in: state))
        var guardCount = 0
        while true {
            let batch = game.advance(state)
            if batch.isEmpty { break }
            foldInto(&state, batch)
            guardCount += 1
            if guardCount > 10_000 { break }
        }
        applyState(duration: 0.12) { [weak self] in self?.playPlan(plan, index: index + 1) }
    }

    // MARK: - Preview keys

    /// c = cascade, f = fireworks, g = fan/glow, s = speedy. Each runs a non-destructive preview from the
    /// cards' current positions and restores the board afterwards.
    #if os(macOS)
    override func keyDown(with event: NSEvent) {
        switch event.charactersIgnoringModifiers?.lowercased() {
        case "c": startCelebration(.cascade, demo: true)
        case "f": startCelebration(.fireworks, demo: true)
        case "g": startCelebration(.fanGlow, demo: true)
        case "s": startCelebration(.speedy, demo: true)
        default:  super.keyDown(with: event)
        }
    }
    #endif
}
