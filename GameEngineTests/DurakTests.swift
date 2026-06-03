//
//  DurakTests.swift
//  GameEngineTests
//
//  Durak engine coverage: beating rules, setup, the attack/defend/take flow, and an AI-vs-AI
//  playthrough that must terminate with an outcome while conserving all 36 cards.
//

import Testing
@testable import GameEngine

@Suite("Durak")
struct DurakTests {

    private let s0 = SeatID(0)
    private let s1 = SeatID(1)
    private func hand(_ seat: SeatID) -> ZoneID { ZoneID("hand", owner: seat) }
    private func total(_ state: DurakState) -> Int {
        state.core.zones.values.reduce(0) { $0 + $1.count }
    }

    private func fold(_ effects: [Effect<DurakEffect>], into state: inout DurakState, with game: DurakGame) {
        for effect in effects {
            switch effect {
            case let .core(coreEffect): state.core.apply(coreEffect)
            case let .game(gameEffect): game.apply(gameEffect, to: &state)
            }
        }
    }

    @Test("Beating rules: higher same-suit wins, trump beats non-trump")
    func beats() {
        let trump = Suit.spades
        #expect(DurakGame.beats(StandardFace(.eight, .hearts), StandardFace(.seven, .hearts), trump: trump))
        #expect(!DurakGame.beats(StandardFace(.seven, .hearts), StandardFace(.eight, .hearts), trump: trump))
        #expect(DurakGame.beats(StandardFace(.six, .spades), StandardFace(.ace, .hearts), trump: trump))   // trump beats ace
        #expect(!DurakGame.beats(StandardFace(.ace, .hearts), StandardFace(.six, .spades), trump: trump))  // non-trump can't beat trump
        #expect(DurakGame.beats(StandardFace(.king, .spades), StandardFace(.queen, .spades), trump: trump)) // higher trump
        #expect(!DurakGame.beats(StandardFace(.six, .hearts), StandardFace(.six, .clubs), trump: trump))    // off-suit, no beat
    }

    @Test("Setup deals 6 each, leaves a 24-card deck, and turns up the trump")
    func setup() {
        let state = DurakGame().setup(seatCount: 2, seed: 42)
        #expect(state.core[hand(s0)]?.count == 6)
        #expect(state.core[hand(s1)]?.count == 6)
        #expect(state.core[.deck]?.count == 24)
        #expect(state.defender != state.attacker)
        #expect(total(state) == 36)
        let trumpCard = state.core[.deck]!.cards.first! // bottom of the deck
        #expect(state.registry.face(trumpCard).suit == state.trump)
        #expect(state.core.faceUp.contains(trumpCard))
        #expect(state.phase == .attacking)
    }

    @Test("Attack then defend updates the table and ping-pongs the turn")
    func attackDefendFlow() {
        var driver = GameDriver(DurakGame(), seatCount: 2, seed: 7)
        let attacker = driver.state.attacker
        guard case let .attack(card)? = driver.legalMoves(for: attacker).first else {
            Issue.record("attacker had no opening attack"); return
        }
        driver.apply(.attack(card))
        #expect(driver.state.phase == .defending)
        #expect(driver.state.table.first?.attack == card)
        #expect(driver.state.core.currentSeat == driver.state.defender)

        let defenderMoves = driver.legalMoves(for: driver.state.defender)
        #expect(defenderMoves.contains(.take))
        if let defend = defenderMoves.first(where: { if case .defend = $0 { return true } else { return false } }) {
            driver.apply(defend)
            #expect(driver.state.phase == .attacking)
            #expect(driver.state.table.first?.defense != nil)
            #expect(driver.state.core.currentSeat == driver.state.attacker)
        }
    }

    @Test("Taking scoops the table into the defender's hand and keeps the roles")
    func takePicksUp() {
        var driver = GameDriver(DurakGame(rules: DurakRules(throwInOnTake: false)), seatCount: 2, seed: 11)
        let attacker = driver.state.attacker
        let defender = driver.state.defender
        let defenderHandBefore = driver.state.core[hand(defender)]?.count ?? 0
        guard case let .attack(card)? = driver.legalMoves(for: attacker).first else {
            Issue.record("no opening attack"); return
        }
        driver.apply(.attack(card))
        driver.apply(.take)
        #expect(driver.state.table.isEmpty)
        // Defender kept the attacking card (count grows by at least 1, minus any draw-ups balance out
        // because the deck still has cards so both refill to 6).
        #expect((driver.state.core[hand(defender)]?.count ?? 0) >= defenderHandBefore)
        #expect(driver.state.attacker == attacker)   // roles unchanged after a take
        #expect(total(driver.state) == 36)
    }

    @Test("Throw-in-on-take lets the attacker pile matching cards before the defender scoops")
    func throwInOnTake() {
        // seat 0 attacks with a 7; it holds another 7 to throw in. seat 1 will take. Empty deck so
        // no draw-ups muddy the counts.
        let faces = [
            StandardFace(.seven, .hearts),   // 0 — attacker opens with this
            StandardFace(.seven, .clubs),    // 1 — attacker's matching throw-in
            StandardFace(.king, .spades),    // 2 — attacker filler (won't match)
            StandardFace(.six, .diamonds),   // 3 — defender
            StandardFace(.eight, .diamonds), // 4 — defender
            StandardFace(.nine, .diamonds),  // 5 — defender
        ]
        let registry = CardRegistry(faces)
        var core = CoreState(seatCount: 2, rng: SeededRNG(seed: 0), currentSeat: s0)
        core.apply(.createZone(.deck, .hidden))
        core.apply(.createZone(.table, .public))
        core.apply(.createZone(.discard, .hidden))
        core.apply(.createZone(hand(s0), .ownerOnly))
        core.apply(.createZone(hand(s1), .ownerOnly))
        core.zones[hand(s0)]?.push(contentsOf: [CardID(0), CardID(1), CardID(2)])
        core.zones[hand(s1)]?.push(contentsOf: [CardID(3), CardID(4), CardID(5)])
        var state = DurakState(core: core, registry: registry, trump: .spades,
                               attacker: s0, defender: s1, table: [], phase: .attacking)
        let game = DurakGame(rules: DurakRules(throwInOnTake: true))

        fold(game.lower(.attack(CardID(0)), in: state), into: &state, with: game) // attack 7♥
        #expect(state.phase == .defending)

        fold(game.lower(.take, in: state), into: &state, with: game)               // defender declares take
        #expect(state.phase == .takingThrowIn)
        #expect(state.core.currentSeat == s0)

        let options = game.legalMoves(for: s0, in: state)
        #expect(options.contains(.attack(CardID(1))))  // matching 7♣ can be thrown in
        #expect(!options.contains(.attack(CardID(2))))  // the king doesn't match

        fold(game.lower(.attack(CardID(1)), in: state), into: &state, with: game)  // throw in 7♣
        fold(game.lower(.pass, in: state), into: &state, with: game)               // done → defender scoops
        #expect(state.table.isEmpty)
        #expect((state.core[hand(s1)]?.count ?? 0) == 5) // had 3, took both 7s
    }

    @Test("AI vs AI playthrough terminates with an outcome and conserves 36 cards")
    func aiPlaythrough() {
        let game = DurakGame()
        let ai = DurakAI()
        var driver = GameDriver(game, seatCount: 2, seed: 0xD0_0D)
        var moves = 0
        while driver.outcome == nil, moves < 100_000 {
            let seat = driver.state.core.currentSeat
            guard let move = ai.move(for: seat, in: driver.state, game: game) else { break }
            driver.apply(move)
            #expect(total(driver.state) == 36)
            moves += 1
        }
        #expect(driver.outcome != nil)
        #expect(total(driver.state) == 36)
    }
}
