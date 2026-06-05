//
//  BuraGame.swift
//  GameEngine
//
//  Bura (Бура) — a 2-player trump trick-taking game on a 36-card deck (plan §8 step 7; the engine's
//  first point-scoring game). The leader plays 1–3 same-suit cards; the responder must beat *every*
//  one (higher same-suit, or a trump over a non-trump, a higher trump over a trump) or surrenders the
//  same number of cards. Whoever wins the trick takes all the cards into their (hidden) won pile, the
//  captured points are added to their score, and they lead next. Both refill to three after each trick
//  (winner first, the face-up trump at the deck's bottom drawn last). First to `winningScore` (31) wins.
//
//  Like War/Durak, `lower` places the played cards and `advance` does the automatic flow one beat at a
//  time — resolve the completed trick (sweep to the winner + score), then refill — so a UI can animate
//  each step and the GameDriver just runs `advance` to a fixpoint.
//

import Foundation

public enum BuraPhase: Sendable, Equatable {
    case leading     // the leader plays 1–3 same-suit cards
    case responding  // the responder must beat all of them, or surrender
    case buraOffer   // the non-leader holds bura and may claim the lead out of turn
}

public enum BuraEffect: GameEffect {
    case setTrump(Suit)
    case setLeader(SeatID)
    case setAttack([CardID])    // the cards led this trick
    case setResponse([CardID])  // the cards played in answer (beat set or surrendered set)
    case setPhase(BuraPhase)
    case setBuraResolved(Bool)  // whether this trick's bura-claim offer has been settled
}

public enum BuraMove: Sendable, Equatable {
    /// Lead 1–3 cards. Multi-card leads must all share a suit.
    case lead([CardID])
    /// Answer the lead with the same number of cards (fewer only if the hand is short). The engine
    /// decides whether it beats every led card (responder takes) or is a surrender (leader takes).
    case respond([CardID])
    /// Claim the lead out of turn by holding bura (three trumps).
    case claimBura
    /// Decline to claim bura; the natural leader keeps the lead.
    case declineBura
}

public struct BuraState: GameState {
    public var core: CoreState
    public let registry: CardRegistry<StandardFace>
    public var trump: Suit
    public var leader: SeatID
    public var attack: [CardID]
    public var response: [CardID]
    public var phase: BuraPhase
    public var buraResolved: Bool = false   // this trick's bura-claim offer is settled
}

public struct BuraGame: Game {
    public let rules: BuraRules

    public init(rules: BuraRules = BuraRules()) {
        self.rules = rules
    }

    private let s0 = SeatID(0)
    private let s1 = SeatID(1)
    private func other(_ seat: SeatID) -> SeatID { seat == s0 ? s1 : s0 }
    private func won(_ seat: SeatID) -> ZoneID { ZoneID("won", owner: seat) }
    private func handCount(_ seat: SeatID, _ state: BuraState) -> Int { state.core[.hand(seat)]?.count ?? 0 }

    /// Bura rank strength, low → high: 6 7 8 9 J Q K **10 A**. The Ten sits just below the Ace and
    /// *above* the King — the defining ordering of the Ace-Ten family. Points are scored separately
    /// (see `BuraRules.points`); this is only about who beats whom.
    public static let rankOrder: [Rank] = [.six, .seven, .eight, .nine, .jack, .queen, .king, .ten, .ace]
    private static let rankStrength: [Rank: Int] =
        Dictionary(uniqueKeysWithValues: rankOrder.enumerated().map { ($1, $0) })
    public static func strength(_ rank: Rank) -> Int { rankStrength[rank] ?? 0 }

    /// Does `defender` beat `attacker` under `trump`? Same suit → higher Bura strength; else only a
    /// trump beats. Shared by legal-move generation, trick resolution, and the AI.
    public static func beats(_ defender: StandardFace, _ attacker: StandardFace, trump: Suit) -> Bool {
        if defender.suit == attacker.suit { return strength(defender.rank) > strength(attacker.rank) }
        return defender.suit == trump
    }

    /// Can `response` beat every card in `attack` (a perfect one-to-one matching)? Equal counts only.
    public func beatsAll(_ response: [CardID], _ attack: [CardID], in state: BuraState) -> Bool {
        beatAssignment(response, attack, in: state) != nil
    }

    /// A perfect matching that beats every attack card: `result[i]` is the index of the attack card
    /// that `response[i]` beats. `nil` when no full beat exists (a surrender). The renderer uses this
    /// to overlap each beating card on the card it beats.
    public func beatAssignment(_ response: [CardID], _ attack: [CardID], in state: BuraState) -> [Int]? {
        guard response.count == attack.count else { return nil }
        var assignment = Array(repeating: -1, count: response.count)
        var usedAttack = Array(repeating: false, count: attack.count)
        func match(_ i: Int) -> Bool {
            if i == response.count { return true }
            let responseFace = state.registry.face(response[i])
            for j in attack.indices where !usedAttack[j] {
                if Self.beats(responseFace, state.registry.face(attack[j]), trump: state.trump) {
                    usedAttack[j] = true; assignment[i] = j
                    if match(i + 1) { return true }
                    usedAttack[j] = false; assignment[i] = -1
                }
            }
            return false
        }
        return match(0) ? assignment : nil
    }

    // MARK: - Combos (lead-first priority from the dealt hand)

    /// A lead-first combo: three cards of one suit — trumps ("бура") or non-trumps ("молодка"/"письмо")
    /// — or three aces one of which is the trump ace. The holder takes the opening lead. None of these
    /// is an automatic win: three low trumps led can still be beaten by three higher trumps.
    public static func isLeadCombo(_ faces: [StandardFace], trump: Suit) -> Bool {
        let bySuit = Dictionary(grouping: faces, by: { $0.suit })
        if bySuit.contains(where: { $0.value.count >= 3 }) { return true } // three of any one suit
        let aces = faces.filter { $0.rank == .ace }
        return aces.count >= 3 && aces.contains { $0.suit == trump }
    }

    /// Does `seat` hold bura — three (or more) trumps? The mid-game lead-claim is offered on this.
    private func holdsBura(_ seat: SeatID, _ state: BuraState) -> Bool {
        (state.core[.hand(seat)]?.cards ?? []).filter { state.registry.face($0).suit == state.trump }.count >= 3
    }

    /// The non-leader who may claim the lead with bura this trick (nil if none). Priority is
    /// attacker-first, then clockwise: the leader holding bura keeps it, so the claim is only offered
    /// to the other seat when the leader has no bura. Once settled (`buraResolved`) it isn't re-offered.
    private func buraClaimant(_ state: BuraState) -> SeatID? {
        guard rules.comboLeadsFirst, !state.buraResolved, !holdsBura(state.leader, state) else { return nil }
        let challenger = other(state.leader)
        return holdsBura(challenger, state) ? challenger : nil
    }

    // MARK: - Setup

    public func setup(seatCount: Int, seed: UInt64) -> BuraState {
        precondition(seatCount == 2, "Bura v1 is a two-player game")
        let registry = CardRegistry(StandardDeck.stripped36)
        var rng = SeededRNG(seed: seed)
        let shuffled = registry.shuffled(using: &rng) // index 0 == bottom (trump), last == top
        let trumpCard = shuffled.first!
        let trump = registry.face(trumpCard).suit
        let (hands, remaining) = Dealing.roundRobin(shuffled, seats: 2, perHand: rules.handSize)

        var core = CoreState(seatCount: 2, rng: rng, currentSeat: s0)
        core.apply(.createZone(.deck, .hidden))
        core.apply(.createZone(.trick, .public))
        core.apply(.createZone(won(s0), .hidden))
        core.apply(.createZone(won(s1), .hidden))
        core.apply(.createZone(.hand(s0), .ownerOnly))
        core.apply(.createZone(.hand(s1), .ownerOnly))
        core.zones[.hand(s0)]?.push(contentsOf: hands[0])
        core.zones[.hand(s1)]?.push(contentsOf: hands[1])
        core.zones[.deck]?.push(contentsOf: remaining) // remaining.first == trumpCard (bottom)
        core.faceUp.insert(trumpCard)

        // A lead-first combo (молодка / three aces) takes the opening lead; otherwise seat 0 leads.
        var leader = s0
        if rules.comboLeadsFirst {
            if Self.isLeadCombo(hands[0].map { registry.face($0) }, trump: trump) { leader = s0 }
            else if Self.isLeadCombo(hands[1].map { registry.face($0) }, trump: trump) { leader = s1 }
        }
        core.currentSeat = leader

        return BuraState(core: core, registry: registry, trump: trump,
                         leader: leader, attack: [], response: [], phase: .leading)
    }

    // MARK: - Legal moves

    public func legalMoves(for seat: SeatID, in state: BuraState) -> [BuraMove] {
        switch state.phase {
        case .leading:
            guard seat == state.leader, seat == state.core.currentSeat else { return [] }
            return leadOptions(seat, state)
        case .responding:
            guard seat == other(state.leader), seat == state.core.currentSeat else { return [] }
            return respondOptions(seat, state)
        case .buraOffer:
            guard seat == state.core.currentSeat else { return [] }
            return [.claimBura, .declineBura]
        }
    }

    /// Every legal lead: each single card, plus (when enabled) every same-suit pair/triple, up to the
    /// smaller of three and the hand size.
    private func leadOptions(_ seat: SeatID, _ state: BuraState) -> [BuraMove] {
        let cards = state.core[.hand(seat)]?.cards ?? []
        var options: [BuraMove] = cards.map { .lead([$0]) }
        guard rules.allowMultiCardLead else { return options }

        let maxLead = min(3, cards.count)
        guard maxLead >= 2 else { return options }
        let bySuit = Dictionary(grouping: cards) { state.registry.face($0).suit }
        for suited in bySuit.values {
            for size in 2...maxLead where suited.count >= size {
                for combo in combinations(suited, size) {
                    options.append(.lead(combo.sorted()))
                }
            }
        }
        return options
    }

    /// Every legal answer: pick the same number of cards the lead used (or the whole hand if shorter).
    /// Both beating sets and surrenders are offered — `advance` resolves which it is.
    private func respondOptions(_ seat: SeatID, _ state: BuraState) -> [BuraMove] {
        let cards = state.core[.hand(seat)]?.cards ?? []
        let n = min(state.attack.count, cards.count)
        guard n > 0 else { return [] }
        return combinations(cards, n).map { .respond($0.sorted()) }
    }

    // MARK: - Lowering moves to effects

    public func lower(_ move: BuraMove, in state: BuraState) -> [Effect<BuraEffect>] {
        switch move {
        case let .lead(cards):
            var effects: [Effect<BuraEffect>] = []
            for card in cards {
                effects.append(.core(.move(card, from: .hand(state.leader), to: .trick)))
                effects.append(.core(.setFaceUp(card, true)))
            }
            effects.append(.game(.setAttack(cards)))
            effects.append(.game(.setPhase(.responding)))
            effects.append(.core(.setTurn(other(state.leader))))
            return effects

        case let .respond(cards):
            // The responder wins by beating every led card; otherwise it's a surrender. Surrendered
            // cards may go face down (rules.faceDownSurrender) so the points conceded stay hidden.
            let responder = other(state.leader)
            let faceUp = beatsAll(cards, state.attack, in: state) || !rules.faceDownSurrender
            var effects: [Effect<BuraEffect>] = []
            for card in cards {
                effects.append(.core(.move(card, from: .hand(responder), to: .trick)))
                effects.append(.core(.setFaceUp(card, faceUp)))
            }
            effects.append(.game(.setResponse(cards))) // advance resolves the completed trick
            return effects

        case .claimBura:
            let claimant = state.core.currentSeat
            return [.game(.setLeader(claimant)), .game(.setBuraResolved(true)),
                    .game(.setPhase(.leading)), .core(.setTurn(claimant))]

        case .declineBura:
            return [.game(.setBuraResolved(true)), .game(.setPhase(.leading)),
                    .core(.setTurn(state.leader))] // the natural leader keeps the lead
        }
    }

    public func apply(_ effect: BuraEffect, to state: inout BuraState) {
        switch effect {
        case let .setTrump(suit): state.trump = suit
        case let .setLeader(seat): state.leader = seat
        case let .setAttack(cards): state.attack = cards
        case let .setResponse(cards): state.response = cards
        case let .setPhase(phase): state.phase = phase
        case let .setBuraResolved(value): state.buraResolved = value
        }
    }

    // MARK: - Advance (resolve trick, then refill)

    public func advance(_ state: BuraState) -> [Effect<BuraEffect>] {
        if outcome(state) != nil { return [] } // game decided — stop (don't refill past the win)
        if !state.response.isEmpty { return resolveTrick(state) }
        if state.phase == .leading, state.attack.isEmpty {
            let refill = refillStep(state)
            if !refill.isEmpty { return refill }
            // Once both are topped up, a non-leader holding bura is offered the lead before play.
            if let claimant = buraClaimant(state) {
                return [.game(.setPhase(.buraOffer)), .core(.setTurn(claimant))]
            }
        }
        return [] // .buraOffer waits here for the claim/decline
    }

    /// Sweep the completed trick to its winner's won pile, score the captured points, and hand them
    /// the lead. The responder wins iff their cards beat every led card; otherwise the leader wins.
    private func resolveTrick(_ state: BuraState) -> [Effect<BuraEffect>] {
        let responder = other(state.leader)
        let winner = beatsAll(state.response, state.attack, in: state) ? responder : state.leader
        let trickCards = state.attack + state.response
        let points = trickCards.reduce(0) { $0 + rules.points(state.registry.face($1).rank) }

        var effects: [Effect<BuraEffect>] = []
        for card in trickCards {
            effects.append(.core(.move(card, from: .trick, to: won(winner))))
            effects.append(.core(.setFaceUp(card, false)))
        }
        if points > 0 { effects.append(.core(.addScore(winner, points))) }
        effects.append(.game(.setLeader(winner)))
        effects.append(.game(.setAttack([])))
        effects.append(.game(.setResponse([])))
        effects.append(.game(.setPhase(.leading)))
        effects.append(.game(.setBuraResolved(false))) // a fresh trick may re-offer a bura claim
        effects.append(.core(.setTurn(winner)))
        return effects
    }

    /// Refill toward the hand size by drawing **one card at a time, alternating** — winner first, then
    /// the other — so the hands stay equal as the deck runs out (only the very last card, the trump,
    /// can leave a one-card gap). Draws from the top of the deck; the face-up trump at the bottom is
    /// last. No-op once the deck is dry.
    private func refillStep(_ state: BuraState) -> [Effect<BuraEffect>] {
        let deckCards = state.core[.deck]?.cards ?? [] // index 0 == bottom (trump), last == top
        guard !deckCards.isEmpty else { return [] }

        let order = [state.leader, other(state.leader)]
        var have: [SeatID: Int] = [order[0]: handCount(order[0], state), order[1]: handCount(order[1], state)]
        var effects: [Effect<BuraEffect>] = []
        var idx = deckCards.count - 1
        var drew = true
        while idx >= 0, drew {
            drew = false
            for seat in order {
                guard idx >= 0, have[seat, default: 0] < rules.handSize else { continue }
                let card = deckCards[idx]; idx -= 1
                have[seat, default: 0] += 1
                effects.append(.core(.move(card, from: .deck, to: .hand(seat))))
                effects.append(.core(.setFaceUp(card, false)))
                drew = true
            }
        }
        return effects
    }

    public func outcome(_ state: BuraState) -> Outcome? {
        let score0 = state.core.scores[s0, default: 0]
        let score1 = state.core.scores[s1, default: 0]
        if let target = rules.winningScore {
            if score0 >= target { return .winner(s0) }
            if score1 >= target { return .winner(s1) }
        }

        // No threshold reached — the deal ends once no further trick can be played: the deck is dry
        // and, at a trick boundary, a hand is empty. Leftover cards aren't scored; the higher captured
        // score wins (a tie is a draw).
        let deckEmpty = (state.core[.deck]?.count ?? 0) == 0
        let betweenTricks = state.phase == .leading && state.attack.isEmpty && state.response.isEmpty
        let aHandEmpty = handCount(s0, state) == 0 || handCount(s1, state) == 0
        guard deckEmpty, betweenTricks, aHandEmpty else { return nil }
        if score0 == score1 { return .draw }
        return .winner(score0 > score1 ? s0 : s1)
    }

    // MARK: - Combinatorics

    /// All `k`-card combinations of `items`, preserving input order within each combination.
    private func combinations<T>(_ items: [T], _ k: Int) -> [[T]] {
        guard k > 0 else { return [[]] }
        guard k <= items.count else { return [] }
        if k == items.count { return [items] }
        var result: [[T]] = []
        func choose(_ start: Int, _ chosen: [T]) {
            if chosen.count == k { result.append(chosen); return }
            let need = k - chosen.count
            var i = start
            while i <= items.count - need {
                choose(i + 1, chosen + [items[i]])
                i += 1
            }
        }
        choose(0, [])
        return result
    }
}
