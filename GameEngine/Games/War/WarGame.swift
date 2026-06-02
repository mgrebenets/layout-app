//
//  WarGame.swift
//  GameEngine
//
//  War (https://en.wikipedia.org/wiki/War_(card_game)) — used to validate the engine loop
//  (plan §7, §8 step 4). No player decisions (moves are forced) and no game-specific state, so
//  its effect payload is uninhabited: everything is expressed with the universal CoreEffect
//  vocabulary. Winnings return to the **bottom** of the winner's stock (classic rule).
//
//  Rules are configurable (see WarRules) and can change on the fly: the number of face-down war
//  cards (1...3) and whether the winner's stock is reshuffled on capture.
//
//  `advance` performs **one logical step per call** (turn hand-off, war lay-down, or resolution),
//  so a UI can step through wars one beat at a time; the GameDriver simply runs it to a fixpoint.
//

import Foundation

/// War has no game-specific effects.
public enum WarEffect: GameEffect {}

public enum WarMove: Sendable, Equatable {
    /// Play the top card of your stock face-up. The only (forced) move.
    case play
}

public struct WarState: GameState {
    public var core: CoreState
    public let registry: CardRegistry<StandardFace>
}

public struct WarGame: Game {
    public let rules: WarRules

    public init(rules: WarRules = WarRules()) {
        self.rules = rules
    }

    private let s0 = SeatID(0)
    private let s1 = SeatID(1)

    private func stock(_ seat: SeatID) -> ZoneID { ZoneID("stock", owner: seat) }
    private func played(_ seat: SeatID) -> ZoneID { ZoneID("played", owner: seat) }

    public func setup(seatCount: Int, seed: UInt64) -> WarState {
        precondition(seatCount == 2, "War is a two-player game")
        let registry = CardRegistry(StandardDeck.standard52)
        var rng = SeededRNG(seed: seed)
        let shuffled = registry.shuffled(using: &rng)

        var core = CoreState(seatCount: 2, rng: rng, currentSeat: s0)
        core.apply(.createZone(stock(s0), .hidden))
        core.apply(.createZone(stock(s1), .hidden))
        core.apply(.createZone(played(s0), .public))
        core.apply(.createZone(played(s1), .public))

        let half = shuffled.count / 2
        core.zones[stock(s0)]?.push(contentsOf: Array(shuffled[..<half]))
        core.zones[stock(s1)]?.push(contentsOf: Array(shuffled[half...]))

        return WarState(core: core, registry: registry)
    }

    public func legalMoves(for seat: SeatID, in state: WarState) -> [WarMove] {
        guard seat == state.core.currentSeat else { return [] }
        guard let stockZone = state.core[stock(seat)], !stockZone.isEmpty else { return [] }
        return [.play]
    }

    public func lower(_ move: WarMove, in state: WarState) -> [Effect<WarEffect>] {
        let seat = state.core.currentSeat
        guard let top = state.core[stock(seat)]?.top else { return [] }
        return [
            .core(.move(top, from: stock(seat), to: played(seat))),
            .core(.setFaceUp(top, true)),
        ]
    }

    public func apply(_ effect: WarEffect, to state: inout WarState) {
        // No game-specific effects — WarEffect is uninhabited.
    }

    public func advance(_ state: WarState) -> [Effect<WarEffect>] {
        guard let p0 = state.core[played(s0)], let p1 = state.core[played(s1)] else { return [] }

        if p0.isEmpty && p1.isEmpty { return [] } // waiting for the round's first play

        if p0.count != p1.count {
            // Only one seat has played this beat — hand the turn to the other.
            let behind = p0.count < p1.count ? s0 : s1
            return state.core.currentSeat == behind ? [] : [.core(.setTurn(behind))]
        }

        // Equal counts ≥ 1: both have a face-up comparison card on top.
        guard let c0 = p0.top, let c1 = p1.top else { return [] }
        let r0 = state.registry.face(c0).rank
        let r1 = state.registry.face(c1).rank

        if r0 != r1 {
            return collect(p0: p0, p1: p1, winner: beats(r0, r1) ? s0 : s1)
        }
        return war(in: state)
    }

    /// Does rank `a` beat rank `b`? Normally the higher rank wins; with the `twoBeatsAce` rule a 2
    /// beats an ace (but loses to everything else). Single source of truth for the UI too.
    public func beats(_ a: Rank, _ b: Rank) -> Bool {
        if rules.twoBeatsAce {
            if a == .two && b == .ace { return true }
            if a == .ace && b == .two { return false }
        }
        return a.rawValue > b.rawValue
    }

    public func outcome(_ state: WarState) -> Outcome? {
        let total0 = (state.core[stock(s0)]?.count ?? 0) + (state.core[played(s0)]?.count ?? 0)
        let total1 = (state.core[stock(s1)]?.count ?? 0) + (state.core[played(s1)]?.count ?? 0)
        if total0 == 0 { return .winner(s1) }
        if total1 == 0 { return .winner(s0) }
        return nil
    }

    // MARK: - Resolution helpers

    /// Sweep every card on the table to the bottom of the winner's stock (classic rule), optionally
    /// reshuffling the winner's stock, then hand them the lead.
    private func collect(p0: Zone, p1: Zone, winner: SeatID) -> [Effect<WarEffect>] {
        var effects: [Effect<WarEffect>] = []
        for card in p0.cards {
            effects.append(.core(.moveToBottom(card, from: played(s0), to: stock(winner))))
            effects.append(.core(.setFaceUp(card, false)))
        }
        for card in p1.cards {
            effects.append(.core(.moveToBottom(card, from: played(s1), to: stock(winner))))
            effects.append(.core(.setFaceUp(card, false)))
        }
        if rules.shuffleWinnings {
            effects.append(.core(.shuffle(stock(winner))))
        }
        effects.append(.core(.setTurn(winner)))
        return effects
    }

    /// A tie: each player lays up to `warFaceDownCount` cards face-down, then one face-up. A player
    /// who can't muster a face-up card loses the war (the other takes the whole table).
    private func war(in state: WarState) -> [Effect<WarEffect>] {
        let stock0 = state.core[stock(s0)]?.cards ?? []
        let stock1 = state.core[stock(s1)]?.cards ?? []

        if stock0.isEmpty || stock1.isEmpty {
            let p0 = state.core[played(s0)]!
            let p1 = state.core[played(s1)]!
            let winner: SeatID = stock0.isEmpty ? (stock1.isEmpty ? s0 : s1) : s0
            return collect(p0: p0, p1: p1, winner: winner)
        }

        var effects: [Effect<WarEffect>] = []
        for (seat, stockCards) in [(s0, stock0), (s1, stock1)] {
            let faceDown = min(rules.warFaceDownCount, stockCards.count - 1)
            let taken = Array(stockCards.suffix(faceDown + 1)) // top (faceDown+1); last == stock top
            for card in taken.dropLast() {
                effects.append(.core(.move(card, from: stock(seat), to: played(seat))))
                effects.append(.core(.setFaceUp(card, false)))
            }
            let faceUp = taken.last!
            effects.append(.core(.move(faceUp, from: stock(seat), to: played(seat))))
            effects.append(.core(.setFaceUp(faceUp, true)))
        }
        return effects
    }
}
