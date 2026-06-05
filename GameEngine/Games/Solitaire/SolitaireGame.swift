//
//  SolitaireGame.swift
//  GameEngine
//
//  Klondike solitaire (plan §8 step 7) — the engine's first single-player game, and the first that
//  isn't trick/comparison based. It validates the zone model on a different shape: a stock + waste, four
//  foundations (build up A→K by suit), and seven tableau piles (build down K→A in alternating colour,
//  with face-down cards revealed as they're exposed). Moves are `move(CardID, to:)` — the engine finds
//  the source zone and, for a tableau→tableau move, carries the whole face-up run on top of the card.
//
//  Only game-specific state is the redeal counter (folded by `SolitaireEffect`); everything else is the
//  universal CoreState. `advance` does the one automatic step — flip a newly-exposed tableau top face-up.
//

import Foundation

public enum SolitaireEffect: GameEffect {
    case usedRedeal   // the waste was recycled into the stock
}

public enum SolitaireMove: Sendable, Equatable {
    /// Flip `drawCount` cards from the stock to the waste, or recycle the waste when the stock is empty.
    case draw
    /// Move a card to a foundation or tableau. From a tableau, the whole face-up run above it comes too.
    case move(CardID, to: ZoneID)
}

public struct SolitaireState: GameState {
    public var core: CoreState
    public let registry: CardRegistry<StandardFace>
    public var redealsUsed: Int = 0
}

public struct SolitaireGame: Game {
    public let rules: SolitaireRules

    public init(rules: SolitaireRules = SolitaireRules()) {
        self.rules = rules
    }

    private let s0 = SeatID(0)
    private let tableauCount = 7
    private let foundationCount = 4
    private let waste = ZoneID("waste")

    public func tableau(_ i: Int) -> ZoneID { ZoneID("tableau", index: i) }
    public func foundation(_ i: Int) -> ZoneID { ZoneID("foundation", index: i) }
    private var tableaus: [ZoneID] { (0..<tableauCount).map(tableau) }
    private var foundations: [ZoneID] { (0..<foundationCount).map(foundation) }

    /// Klondike rank value with the **ace low** (A=1 … K=13) — foundations build up, tableaus build down.
    private func value(_ rank: Rank) -> Int { rank == .ace ? 1 : rank.rawValue }

    // MARK: - Setup

    public func setup(seatCount: Int, seed: UInt64) -> SolitaireState {
        precondition(seatCount == 1, "Klondike is single-player")
        let registry = CardRegistry(StandardDeck.standard52)
        var rng = SeededRNG(seed: seed)
        let shuffled = registry.shuffled(using: &rng)

        var core = CoreState(seatCount: 1, rng: rng, currentSeat: s0)
        core.apply(.createZone(.deck, .hidden)) // the stock
        core.apply(.createZone(waste, .public))
        for i in 0..<foundationCount { core.apply(.createZone(foundation(i), .public)) }
        for i in 0..<tableauCount { core.apply(.createZone(tableau(i), .hidden)) } // faceUp set reveals tops

        // Deal: pile i gets i+1 cards, only its top face-up; the remaining 24 form the stock.
        var idx = 0
        for i in 0..<tableauCount {
            for j in 0...i {
                let card = shuffled[idx]; idx += 1
                core.zones[tableau(i)]?.push(card)
                if j == i { core.faceUp.insert(card) }
            }
        }
        while idx < shuffled.count { core.zones[.deck]?.push(shuffled[idx]); idx += 1 }

        return SolitaireState(core: core, registry: registry)
    }

    // MARK: - Legal moves

    public func legalMoves(for seat: SeatID, in state: SolitaireState) -> [SolitaireMove] {
        guard seat == s0 else { return [] }
        var moves: [SolitaireMove] = []
        if canDraw(state) { moves.append(.draw) }

        // The waste's top card (a single card).
        if let top = state.core[waste]?.top {
            appendDestinations(for: top, source: waste, canGoToFoundation: true, into: &moves, state)
        }
        // Every face-up tableau card — its run moves with it; only the pile's top can hit a foundation.
        for tz in tableaus {
            let cards = state.core[tz]?.cards ?? []
            for (i, card) in cards.enumerated() where state.core.faceUp.contains(card) {
                appendDestinations(for: card, source: tz, canGoToFoundation: i == cards.count - 1, into: &moves, state)
            }
        }
        // A foundation's top card may come back down onto a tableau.
        for fz in foundations {
            if let top = state.core[fz]?.top {
                for tz in tableaus where accepts(top, onto: tz, state) { moves.append(.move(top, to: tz)) }
            }
        }
        return moves
    }

    private func appendDestinations(for card: CardID, source: ZoneID, canGoToFoundation: Bool,
                                    into moves: inout [SolitaireMove], _ state: SolitaireState) {
        if canGoToFoundation, let f = foundationTarget(card, state) { moves.append(.move(card, to: f)) }
        for tz in tableaus where tz != source && accepts(card, onto: tz, state) { moves.append(.move(card, to: tz)) }
    }

    /// Does `tableau` accept `card` as the head of a placement? Empty piles take only a King; otherwise
    /// the card must be one lower than the top and the opposite colour.
    private func accepts(_ card: CardID, onto tableau: ZoneID, _ state: SolitaireState) -> Bool {
        let cardFace = state.registry.face(card)
        guard let zone = state.core[tableau] else { return false }
        guard let top = zone.top else { return cardFace.rank == .king }
        let topFace = state.registry.face(top)
        return value(cardFace.rank) == value(topFace.rank) - 1 && cardFace.suit.color != topFace.suit.color
    }

    /// The foundation `card` may go to (matching suit one higher, or any empty foundation for an ace).
    private func foundationTarget(_ card: CardID, _ state: SolitaireState) -> ZoneID? {
        let cardFace = state.registry.face(card)
        for fz in foundations {
            if let top = state.core[fz]?.top {
                let topFace = state.registry.face(top)
                if topFace.suit == cardFace.suit && value(cardFace.rank) == value(topFace.rank) + 1 { return fz }
            }
        }
        return cardFace.rank == .ace ? foundations.first { state.core[$0]?.isEmpty ?? false } : nil
    }

    private func canDraw(_ state: SolitaireState) -> Bool {
        if (state.core[.deck]?.count ?? 0) > 0 { return true }
        let recycleAllowed = rules.redealLimit.map { state.redealsUsed < $0 } ?? true
        return (state.core[waste]?.count ?? 0) > 0 && recycleAllowed
    }

    // MARK: - Lowering moves to effects

    public func lower(_ move: SolitaireMove, in state: SolitaireState) -> [Effect<SolitaireEffect>] {
        switch move {
        case .draw:
            return lowerDraw(state)

        case let .move(card, dest):
            guard let source = zone(containing: card, state) else { return [] }
            // A tableau→tableau move carries the whole face-up run sitting on top of `card`.
            if source.name == "tableau", dest.name == "tableau" {
                let cards = state.core[source]?.cards ?? []
                guard let i = cards.firstIndex(of: card) else { return [] }
                return cards[i...].map { .core(.move($0, from: source, to: dest)) }
            }
            return [.core(.move(card, from: source, to: dest))]
        }
    }

    private func lowerDraw(_ state: SolitaireState) -> [Effect<SolitaireEffect>] {
        let stock = state.core[.deck]?.cards ?? []
        if !stock.isEmpty {
            let n = min(rules.drawCount, stock.count)
            var effects: [Effect<SolitaireEffect>] = []
            var idx = stock.count - 1
            for _ in 0..<n { // flip the top n one at a time; the last flipped ends up on top, playable
                let card = stock[idx]; idx -= 1
                effects.append(.core(.move(card, from: .deck, to: waste)))
                effects.append(.core(.setFaceUp(card, true)))
            }
            return effects
        }
        // Recycle: flip the waste back over onto the stock (preserving the draw order), face down.
        let wasteCards = state.core[waste]?.cards ?? []
        guard canDraw(state), !wasteCards.isEmpty else { return [] }
        var effects: [Effect<SolitaireEffect>] = []
        for card in wasteCards.reversed() {
            effects.append(.core(.move(card, from: waste, to: .deck)))
            effects.append(.core(.setFaceUp(card, false)))
        }
        effects.append(.game(.usedRedeal))
        return effects
    }

    public func apply(_ effect: SolitaireEffect, to state: inout SolitaireState) {
        switch effect {
        case .usedRedeal: state.redealsUsed += 1
        }
    }

    // MARK: - Advance (reveal exposed tableau cards) & outcome

    public func advance(_ state: SolitaireState) -> [Effect<SolitaireEffect>] {
        var effects: [Effect<SolitaireEffect>] = []
        for tz in tableaus {
            if let top = state.core[tz]?.top, !state.core.faceUp.contains(top) {
                effects.append(.core(.setFaceUp(top, true)))
            }
        }
        return effects
    }

    public func outcome(_ state: SolitaireState) -> Outcome? {
        let onFoundations = foundations.reduce(0) { $0 + (state.core[$1]?.count ?? 0) }
        return onFoundations == 52 ? .winner(s0) : nil
    }

    // MARK: - Helpers

    private func zone(containing card: CardID, _ state: SolitaireState) -> ZoneID? {
        for (id, zone) in state.core.zones where zone.contains(card) { return id }
        return nil
    }
}
