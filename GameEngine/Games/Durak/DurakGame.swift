//
//  DurakGame.swift
//  GameEngine
//
//  Durak (https://en.wikipedia.org/wiki/Durak) — "podkidnoy" (throw-in) variant for 2–6 players.
//  The first multi-role game: a single defender, a principal attacker, and (with 3+ players)
//  co-attackers who may all throw in. Roles, trump, the table of attack/defence pairs, the set of
//  attackers who've passed, and eliminated players live in DurakState and are mutated by DurakEffect;
//  card movement uses the universal CoreEffect vocabulary.
//
//  `advance` drives the throw-in cycle: it offers the throw-in to the next eligible attacker (per
//  ThrowInPriority), auto-passes anyone who can't throw, and ends the bout when everyone has passed
//  (bita) or the defender finishes taking. So a UI/driver just folds `lower` then runs `advance` to
//  a fixpoint. Attacks are single-card; the principal keeps priority, so it can pile several cards on
//  before co-attackers are offered.
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
    case attacking      // opening attack, or offering throw-ins to attackers
    case defending      // defender must beat the open attack or take
    case takingThrowIn  // defender has committed to taking; attackers may pile on, then it's scooped
}

public enum DurakEffect: GameEffect {
    case setTrump(Suit)
    case setRoles(principal: SeatID, defender: SeatID)
    case beginAttack(CardID)
    case setDefense(attack: CardID, with: CardID)
    case clearTable
    case setPhase(DurakPhase)
    case setPassed(Set<SeatID>)   // attackers who've declined since the last card was added
    case markOut(SeatID)          // a player who emptied their hand with the deck gone
    case setFirstBout(Bool)       // whether the opening-bout (5-card) cap still applies
}

public enum DurakMove: Sendable, Equatable {
    case attack(CardID)
    case defend(attack: CardID, with: CardID)
    case take
    case pass   // attacker declines to (continue to) throw in
}

public struct DurakState: GameState {
    public var core: CoreState
    public let registry: CardRegistry<StandardFace>
    public var trump: Suit
    public var principalAttacker: SeatID
    public var defender: SeatID
    public var table: [TablePair]
    public var phase: DurakPhase
    public var passed: Set<SeatID>
    public var out: Set<SeatID>
    public var firstBout: Bool
}

public struct DurakGame: Game {
    public let rules: DurakRules

    public init(rules: DurakRules = DurakRules()) {
        self.rules = rules
    }

    private func hand(_ seat: SeatID) -> ZoneID { ZoneID("hand", owner: seat) }
    private func handCount(_ seat: SeatID, _ state: DurakState) -> Int { state.core[hand(seat)]?.count ?? 0 }
    private func tableCards(_ state: DurakState) -> [CardID] {
        state.table.flatMap { [$0.attack] + ($0.defense.map { [$0] } ?? []) }
    }

    /// Does `defender` beat `attacker` under `trump`? Same suit → higher rank; else only a trump beats.
    public static func beats(_ defender: StandardFace, _ attacker: StandardFace, trump: Suit) -> Bool {
        if defender.suit == attacker.suit { return defender.rank.rawValue > attacker.rank.rawValue }
        return defender.suit == trump
    }

    // MARK: - Setup

    public func setup(seatCount: Int, seed: UInt64) -> DurakState {
        setup(seatCount: seatCount, seed: seed, openingAttacker: nil)
    }

    /// Deal a fresh round. `openingAttacker` fixes who attacks first (used between rounds of a match);
    /// when nil the lowest trump leads, or — if no trump was dealt — a random seat.
    public func setup(seatCount: Int, seed: UInt64, openingAttacker: SeatID?) -> DurakState {
        precondition((2...6).contains(seatCount), "Durak supports 2–6 players")
        let registry = CardRegistry(StandardDeck.make(ranks: Rank.from(rules.lowestRank)))
        var rng = SeededRNG(seed: seed)
        let shuffled = registry.shuffled(using: &rng) // index 0 == bottom (trump), last == top
        let trumpCard = shuffled.first!
        let trump = registry.face(trumpCard).suit
        let (hands, remaining) = Dealing.roundRobin(shuffled, seats: seatCount, perHand: rules.handSize)

        let principal: SeatID
        if let opening = openingAttacker, (0..<seatCount).contains(opening.index) {
            principal = opening
        } else if let low = lowestTrumpHolder(hands: hands, trump: trump, registry: registry) {
            principal = low
        } else {
            principal = SeatID(Int(rng.next() % UInt64(seatCount))) // no trump dealt → random
        }
        let defender = SeatID((principal.index + 1) % seatCount)

        var core = CoreState(seatCount: seatCount, rng: rng, currentSeat: principal)
        core.apply(.createZone(.deck, .hidden))
        core.apply(.createZone(.table, .public))
        core.apply(.createZone(.discard, .hidden))
        for seat in 0..<seatCount { core.apply(.createZone(hand(SeatID(seat)), .ownerOnly)) }
        for seat in 0..<seatCount { core.zones[hand(SeatID(seat))]?.push(contentsOf: hands[seat]) }
        core.zones[.deck]?.push(contentsOf: remaining) // remaining.first == trumpCard (bottom)
        core.faceUp.insert(trumpCard)

        return DurakState(core: core, registry: registry, trump: trump,
                          principalAttacker: principal, defender: defender,
                          table: [], phase: .attacking, passed: [], out: [], firstBout: true)
    }

    private func lowestTrumpHolder(hands: [[CardID]], trump: Suit,
                                   registry: CardRegistry<StandardFace>) -> SeatID? {
        var best: (seat: SeatID, rank: Int)?
        for (i, hand) in hands.enumerated() {
            for card in hand where registry.face(card).suit == trump {
                let rank = registry.face(card).rank.rawValue
                if best == nil || rank < best!.rank { best = (SeatID(i), rank) }
            }
        }
        return best?.seat
    }

    // MARK: - Attacker eligibility / throw-in offers

    /// Eligible attackers in offer order: clockwise from the principal, excluding the defender,
    /// eliminated players, and anyone with no cards.
    private func eligibleAttackers(_ state: DurakState) -> [SeatID] {
        let n = state.core.seatCount
        var result: [SeatID] = []
        for k in 0..<n {
            let seat = SeatID((state.principalAttacker.index + k) % n)
            if seat != state.defender, !state.out.contains(seat), handCount(seat, state) > 0 {
                result.append(seat)
            }
        }
        return result
    }

    /// Most attack cards allowed this bout: the defender's room (hand + cards already used to defend),
    /// capped at the hand size.
    private func attackLimit(_ state: DurakState) -> Int {
        let defended = state.table.filter { $0.defense != nil }.count
        let cap = (rules.firstAttackMaxFive && state.firstBout) ? min(5, rules.handSize) : rules.handSize
        return min(cap, handCount(state.defender, state) + defended)
    }

    private func legalThrowIns(_ seat: SeatID, _ state: DurakState) -> [DurakMove] {
        guard rules.allowThrowIn, state.table.count < attackLimit(state) else { return [] }
        let ranks = Set(tableCards(state).map { state.registry.face($0).rank })
        let cards = state.core[hand(seat)]?.cards ?? []
        return cards.filter { ranks.contains(state.registry.face($0).rank) }.map { .attack($0) }
    }

    /// The next attacker to offer a throw-in to, per priority; nil when every eligible attacker passed.
    private func nextOffer(_ state: DurakState) -> SeatID? {
        let available = eligibleAttackers(state).filter { !state.passed.contains($0) }
        guard !available.isEmpty else { return nil }
        switch rules.throwInPriority {
        case .principalFirst:
            return available.first // eligibleAttackers is ordered from the principal
        case .roundRobin:
            let n = state.core.seatCount
            let current = state.core.currentSeat.index
            return available.min {
                let da = ($0.index - current + n) % n, db = ($1.index - current + n) % n
                return (da == 0 ? n : da) < (db == 0 ? n : db)
            }
        }
    }

    private func anyAttackerCanThrow(_ state: DurakState) -> Bool {
        eligibleAttackers(state).contains { !legalThrowIns($0, state).isEmpty }
    }

    // MARK: - Legal moves

    public func legalMoves(for seat: SeatID, in state: DurakState) -> [DurakMove] {
        switch state.phase {
        case .attacking:
            guard seat == state.core.currentSeat else { return [] }
            if state.table.isEmpty {
                return (state.core[hand(seat)]?.cards ?? []).map { .attack($0) } // opening: any card
            }
            return [.pass] + legalThrowIns(seat, state)

        case .defending:
            guard seat == state.defender else { return [] }
            var moves: [DurakMove] = [.take]
            let cards = state.core[hand(seat)]?.cards ?? []
            for pair in state.table where pair.defense == nil {
                let attackFace = state.registry.face(pair.attack)
                for card in cards where Self.beats(state.registry.face(card), attackFace, trump: state.trump) {
                    moves.append(.defend(attack: pair.attack, with: card))
                }
            }
            return moves

        case .takingThrowIn:
            guard seat == state.core.currentSeat else { return [] }
            return [.pass] + legalThrowIns(seat, state)
        }
    }

    // MARK: - Lowering moves to effects

    public func lower(_ move: DurakMove, in state: DurakState) -> [Effect<DurakEffect>] {
        switch move {
        case let .attack(card):
            let actor = state.core.currentSeat
            var effects: [Effect<DurakEffect>] = [
                .core(.move(card, from: hand(actor), to: .table)),
                .core(.setFaceUp(card, true)),
                .game(.beginAttack(card)),
                .game(.setPassed([])), // a new card re-opens the throw-in cycle
            ]
            if state.phase == .takingThrowIn {
                effects.append(.core(.setTurn(actor))) // defender is taking; keep offering
            } else {
                effects.append(.game(.setPhase(.defending)))
                effects.append(.core(.setTurn(state.defender)))
            }
            return effects

        case let .defend(attack, with):
            return [
                .core(.move(with, from: hand(state.defender), to: .table)),
                .core(.setFaceUp(with, true)),
                .game(.setDefense(attack: attack, with: with)),
                .game(.setPhase(.attacking)),
                .game(.setPassed([])),
                .core(.setTurn(state.defender)), // advance offers the first attacker from here
            ]

        case .take:
            if rules.throwInOnTake, anyAttackerCanThrow(state) {
                return [.game(.setPhase(.takingThrowIn)), .game(.setPassed([])), .core(.setTurn(state.defender))]
            }
            return scoopToDefender(state) + [.game(.clearTable)] + endBout(state, defenderTook: true)

        case .pass:
            return [.game(.setPassed(state.passed.union([state.core.currentSeat])))]
        }
    }

    private func scoopToDefender(_ state: DurakState) -> [Effect<DurakEffect>] {
        tableCards(state).flatMap {
            [Effect<DurakEffect>.core(.move($0, from: .table, to: hand(state.defender))),
             .core(.setFaceUp($0, false))]
        }
    }

    private func discardTable(_ state: DurakState) -> [Effect<DurakEffect>] {
        tableCards(state).flatMap {
            [Effect<DurakEffect>.core(.move($0, from: .table, to: .discard)),
             .core(.setFaceUp($0, false))]
        }
    }

    // MARK: - Advance (throw-in cycle automation)

    public func advance(_ state: DurakState) -> [Effect<DurakEffect>] {
        switch state.phase {
        case .defending:
            return []
        case .attacking:
            if state.table.isEmpty { return [] } // opening — wait for the principal to attack
            return offerStep(state, taking: false)
        case .takingThrowIn:
            return offerStep(state, taking: true)
        }
    }

    private func offerStep(_ state: DurakState, taking: Bool) -> [Effect<DurakEffect>] {
        let current = state.core.currentSeat
        // If the current seat is the pending offeree, resolve it (auto-pass if it can't throw).
        if eligibleAttackers(state).contains(current), !state.passed.contains(current) {
            if legalThrowIns(current, state).isEmpty {
                return [.game(.setPassed(state.passed.union([current])))]
            }
            return [] // wait for this seat's decision (throw or pass)
        }
        // Otherwise move the offer to the next eligible attacker, or end the bout.
        guard let next = nextOffer(state) else {
            let clear = taking ? scoopToDefender(state) : discardTable(state)
            return clear + [.game(.clearTable)] + endBout(state, defenderTook: taking)
        }
        return [.core(.setTurn(next))]
    }

    /// Refill hands (principal first, defender last), eliminate emptied players, and rotate roles.
    private func endBout(_ state: DurakState, defenderTook: Bool) -> [Effect<DurakEffect>] {
        let n = state.core.seatCount
        var effects: [Effect<DurakEffect>] = []

        // Draw order: principal, then clockwise others (not the defender), defender last.
        var order: [SeatID] = []
        for k in 0..<n {
            let seat = SeatID((state.principalAttacker.index + k) % n)
            if !state.out.contains(seat), seat != state.defender { order.append(seat) }
        }
        if !state.out.contains(state.defender) { order.append(state.defender) }

        let deckCards = state.core[.deck]?.cards ?? [] // index 0 == bottom (trump), last == top
        var idx = deckCards.count - 1
        var postCount: [SeatID: Int] = [:]
        for seat in order {
            var have = handCount(seat, state)
            if defenderTook, seat == state.defender { have += tableCards(state).count }
            var drawn = 0
            while drawn < max(0, rules.handSize - have), idx >= 0 {
                let card = deckCards[idx]; idx -= 1; drawn += 1
                effects.append(.core(.move(card, from: .deck, to: hand(seat))))
                effects.append(.core(.setFaceUp(card, false)))
            }
            postCount[seat] = have + drawn
        }

        // Players who end with no cards (deck exhausted) are out.
        var survivors = Set<SeatID>()
        for seat in order {
            if postCount[seat] == 0 { effects.append(.game(.markOut(seat))) } else { survivors.insert(seat) }
        }

        func nextSurvivor(after seat: SeatID) -> SeatID? {
            for k in 1...n {
                let s = SeatID((seat.index + k) % n)
                if survivors.contains(s) { return s }
            }
            return nil
        }

        // Rotate roles. Defended → defender leads next; took → defender is skipped.
        let newPrincipal: SeatID
        if defenderTook {
            newPrincipal = nextSurvivor(after: state.defender) ?? state.principalAttacker
        } else {
            newPrincipal = survivors.contains(state.defender) ? state.defender
                         : (nextSurvivor(after: state.defender) ?? state.principalAttacker)
        }
        let newDefender = nextSurvivor(after: newPrincipal) ?? newPrincipal

        effects.append(.game(.setRoles(principal: newPrincipal, defender: newDefender)))
        effects.append(.game(.setPhase(.attacking)))
        effects.append(.game(.setPassed([])))
        if state.firstBout { effects.append(.game(.setFirstBout(false))) } // the opening bout is over
        effects.append(.core(.setTurn(newPrincipal)))
        return effects
    }

    public func apply(_ effect: DurakEffect, to state: inout DurakState) {
        switch effect {
        case let .setTrump(suit): state.trump = suit
        case let .setRoles(principal, defender):
            state.principalAttacker = principal
            state.defender = defender
        case let .beginAttack(card): state.table.append(TablePair(attack: card))
        case let .setDefense(attack, with):
            if let i = state.table.firstIndex(where: { $0.attack == attack }) { state.table[i].defense = with }
        case .clearTable: state.table.removeAll()
        case let .setPhase(phase): state.phase = phase
        case let .setPassed(seats): state.passed = seats
        case let .markOut(seat): state.out.insert(seat)
        case let .setFirstBout(value): state.firstBout = value
        }
    }

    public func outcome(_ state: DurakState) -> Outcome? {
        let deckEmpty = (state.core[.deck]?.count ?? 0) == 0
        guard deckEmpty, state.table.isEmpty, state.phase == .attacking else { return nil }
        let seats = (0..<state.core.seatCount).map { SeatID($0) }
        let withCards = seats.filter { handCount($0, state) > 0 }
        guard withCards.count <= 1 else { return nil }
        let safe = seats.filter { handCount($0, state) == 0 }
        return safe.isEmpty ? .draw : .winners(safe) // the lone remaining player is the durak
    }
}
