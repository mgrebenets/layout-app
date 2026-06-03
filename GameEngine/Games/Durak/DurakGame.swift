//
//  DurakGame.swift
//  GameEngine
//
//  Durak (https://en.wikipedia.org/wiki/Durak) — two-player "podkidnoy" (throw-in) variant. The
//  first game with real player decisions and with game-specific state/effects (plan §3 family 3,
//  §4.6 dynamic roles, §10 typed per-game effects): attacker/defender roles, trump, and the table
//  of attack/defence pairs all live in DurakState and are mutated by DurakEffect, while the actual
//  card movement uses the universal CoreEffect vocabulary.
//
//  Flow per bout: attacker plays a card → defender beats it or takes → if beaten, attacker may
//  throw another matching-rank card or pass ("Bita"). On pass the table is discarded and roles
//  swap; on take the defender scoops the table and stays defender. Both refill to handSize from the
//  deck (attacker first) between bouts. Deck empty + a player out → that player wins; the last one
//  holding cards is the durak.
//

import Foundation

public struct TablePair: Sendable, Equatable {
    public var attack: CardID
    public var defense: CardID?
    public init(attack: CardID, defense: CardID? = nil) {
        self.attack = attack
        self.defense = defense
    }
}

public enum DurakPhase: Sendable, Equatable {
    case attacking   // waiting for the attacker (play a card, or pass once everything is beaten)
    case defending   // waiting for the defender (beat an attack, or take)
}

public enum DurakEffect: GameEffect {
    case setTrump(Suit)
    case setRoles(attacker: SeatID, defender: SeatID)
    case beginAttack(CardID)
    case setDefense(attack: CardID, with: CardID)
    case clearTable
    case setPhase(DurakPhase)
}

public enum DurakMove: Sendable, Equatable {
    case attack(CardID)
    case defend(attack: CardID, with: CardID)
    case take
    case pass   // attacker ends the bout ("Bita")
}

public struct DurakState: GameState {
    public var core: CoreState
    public let registry: CardRegistry<StandardFace>
    public var trump: Suit
    public var attacker: SeatID
    public var defender: SeatID
    public var table: [TablePair]
    public var phase: DurakPhase
}

public struct DurakGame: Game {
    public let rules: DurakRules

    public init(rules: DurakRules = DurakRules()) {
        self.rules = rules
    }

    private let s0 = SeatID(0)
    private let s1 = SeatID(1)
    private func hand(_ seat: SeatID) -> ZoneID { ZoneID("hand", owner: seat) }

    /// Does `defender` beat `attacker` under `trump`? Same suit → higher rank wins; otherwise only a
    /// trump beats a non-trump.
    public static func beats(_ defender: StandardFace, _ attacker: StandardFace, trump: Suit) -> Bool {
        if defender.suit == attacker.suit { return defender.rank.rawValue > attacker.rank.rawValue }
        return defender.suit == trump
    }

    private func tableCards(_ state: DurakState) -> [CardID] {
        state.table.flatMap { [$0.attack] + ($0.defense.map { [$0] } ?? []) }
    }

    // MARK: - Setup

    public func setup(seatCount: Int, seed: UInt64) -> DurakState {
        precondition(seatCount == 2, "this Durak implementation is two-player")
        let registry = CardRegistry(StandardDeck.make(ranks: Rank.from(rules.lowestRank)))
        var rng = SeededRNG(seed: seed)
        let shuffled = registry.shuffled(using: &rng) // index 0 == bottom (trump), last == top
        let trumpCard = shuffled.first!
        let trump = registry.face(trumpCard).suit

        var core = CoreState(seatCount: 2, rng: rng, currentSeat: s0)
        core.apply(.createZone(.deck, .hidden))
        core.apply(.createZone(.table, .public))
        core.apply(.createZone(.discard, .hidden))
        core.apply(.createZone(hand(s0), .ownerOnly))
        core.apply(.createZone(hand(s1), .ownerOnly))

        let (hands, remaining) = Dealing.roundRobin(shuffled, seats: 2, perHand: rules.handSize)
        core.zones[hand(s0)]?.push(contentsOf: hands[0])
        core.zones[hand(s1)]?.push(contentsOf: hands[1])
        core.zones[.deck]?.push(contentsOf: remaining) // remaining.first == trumpCard (bottom)
        core.faceUp.insert(trumpCard)                  // trump card shown beneath the deck

        let attacker = lowestTrumpHolder(hands: hands, trump: trump, registry: registry) ?? s0
        let defender = (attacker == s0) ? s1 : s0
        core.currentSeat = attacker

        return DurakState(core: core, registry: registry, trump: trump,
                          attacker: attacker, defender: defender, table: [], phase: .attacking)
    }

    private func lowestTrumpHolder(hands: [[CardID]], trump: Suit,
                                   registry: CardRegistry<StandardFace>) -> SeatID? {
        var best: (seat: SeatID, rank: Int)?
        for (i, hand) in hands.enumerated() {
            for card in hand {
                let face = registry.face(card)
                guard face.suit == trump else { continue }
                if best == nil || face.rank.rawValue < best!.rank {
                    best = (SeatID(i), face.rank.rawValue)
                }
            }
        }
        return best?.seat
    }

    // MARK: - Legal moves

    public func legalMoves(for seat: SeatID, in state: DurakState) -> [DurakMove] {
        let handCards = state.core[hand(seat)]?.cards ?? []
        switch state.phase {
        case .attacking:
            guard seat == state.attacker else { return [] }
            if state.table.isEmpty {
                return handCards.map { .attack($0) } // opening attack: any card
            }
            guard state.table.allSatisfy({ $0.defense != nil }) else { return [] }
            var moves: [DurakMove] = [.pass]
            if rules.allowThrowIn {
                let defenderHand = state.core[hand(state.defender)]?.count ?? 0
                if state.table.count < rules.handSize, defenderHand > 0 {
                    let ranks = Set(tableCards(state).map { state.registry.face($0).rank })
                    moves += handCards.filter { ranks.contains(state.registry.face($0).rank) }.map { .attack($0) }
                }
            }
            return moves

        case .defending:
            guard seat == state.defender else { return [] }
            var moves: [DurakMove] = [.take]
            for pair in state.table where pair.defense == nil {
                let attackFace = state.registry.face(pair.attack)
                for card in handCards where Self.beats(state.registry.face(card), attackFace, trump: state.trump) {
                    moves.append(.defend(attack: pair.attack, with: card))
                }
            }
            return moves
        }
    }

    // MARK: - Lowering moves to effects

    public func lower(_ move: DurakMove, in state: DurakState) -> [Effect<DurakEffect>] {
        switch move {
        case let .attack(card):
            return [
                .core(.move(card, from: hand(state.attacker), to: .table)),
                .core(.setFaceUp(card, true)),
                .game(.beginAttack(card)),
                .game(.setPhase(.defending)),
                .core(.setTurn(state.defender)),
            ]

        case let .defend(attack, with):
            return [
                .core(.move(with, from: hand(state.defender), to: .table)),
                .core(.setFaceUp(with, true)),
                .game(.setDefense(attack: attack, with: with)),
                .game(.setPhase(.attacking)),
                .core(.setTurn(state.attacker)),
            ]

        case .take:
            var effects: [Effect<DurakEffect>] = []
            for card in tableCards(state) {
                effects.append(.core(.move(card, from: .table, to: hand(state.defender))))
                effects.append(.core(.setFaceUp(card, false)))
            }
            effects.append(.game(.clearTable))
            effects += endBout(state, defenderTook: true)
            return effects

        case .pass:
            var effects: [Effect<DurakEffect>] = []
            for card in tableCards(state) {
                effects.append(.core(.move(card, from: .table, to: .discard)))
                effects.append(.core(.setFaceUp(card, false)))
            }
            effects.append(.game(.clearTable))
            effects += endBout(state, defenderTook: false)
            return effects
        }
    }

    /// Refill hands (attacker first) and set up the next bout's roles.
    private func endBout(_ state: DurakState, defenderTook: Bool) -> [Effect<DurakEffect>] {
        var effects: [Effect<DurakEffect>] = []
        let deckCards = state.core[.deck]?.cards ?? [] // index 0 == bottom (trump), last == top
        var idx = deckCards.count - 1

        let attackerHand = state.core[hand(state.attacker)]?.count ?? 0
        var defenderHand = state.core[hand(state.defender)]?.count ?? 0
        if defenderTook { defenderHand += tableCards(state).count }

        func draw(_ seat: SeatID, have: Int) {
            var drawn = 0
            while drawn < max(0, rules.handSize - have) && idx >= 0 {
                let card = deckCards[idx]
                idx -= 1
                drawn += 1
                effects.append(.core(.move(card, from: .deck, to: hand(seat))))
                effects.append(.core(.setFaceUp(card, false)))
            }
        }
        draw(state.attacker, have: attackerHand)
        draw(state.defender, have: defenderHand)

        let newAttacker = defenderTook ? state.attacker : state.defender
        let newDefender = defenderTook ? state.defender : state.attacker
        effects.append(.game(.setRoles(attacker: newAttacker, defender: newDefender)))
        effects.append(.game(.setPhase(.attacking)))
        effects.append(.core(.setTurn(newAttacker)))
        return effects
    }

    public func apply(_ effect: DurakEffect, to state: inout DurakState) {
        switch effect {
        case let .setTrump(suit):
            state.trump = suit
        case let .setRoles(attacker, defender):
            state.attacker = attacker
            state.defender = defender
        case let .beginAttack(card):
            state.table.append(TablePair(attack: card))
        case let .setDefense(attack, with):
            if let i = state.table.firstIndex(where: { $0.attack == attack }) {
                state.table[i].defense = with
            }
        case .clearTable:
            state.table.removeAll()
        case let .setPhase(phase):
            state.phase = phase
        }
    }

    public func advance(_ state: DurakState) -> [Effect<DurakEffect>] {
        [] // all transitions are encoded in `lower`; nothing automatic to do
    }

    public func outcome(_ state: DurakState) -> Outcome? {
        let deckEmpty = (state.core[.deck]?.count ?? 0) == 0
        guard deckEmpty, state.table.isEmpty, state.phase == .attacking else { return nil }
        let h0 = state.core[hand(s0)]?.count ?? 0
        let h1 = state.core[hand(s1)]?.count ?? 0
        if h0 == 0 && h1 == 0 { return .draw }
        if h0 == 0 { return .winner(s0) } // s0 emptied → s0 wins, s1 is the durak
        if h1 == 0 { return .winner(s1) }
        return nil
    }
}
