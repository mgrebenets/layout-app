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
        var driver = GameDriver(DurakGame(), seatCount: 2, seed: 11)
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
