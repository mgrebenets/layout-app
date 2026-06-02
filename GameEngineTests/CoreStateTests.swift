//
//  CoreStateTests.swift
//  GameEngineTests
//
//  Step 2 (engine core) coverage: the universal effect fold. Validates that CoreState
//  is a pure, deterministic reduction of CoreEffects (the event-sourcing spine).
//

import Testing
@testable import GameEngine

@Suite("CoreState fold")
struct CoreStateTests {

    private func freshState(seats: Int = 2) -> CoreState {
        CoreState(seatCount: seats, rng: SeededRNG(seed: 1))
    }

    @Test("Creating a zone makes it queryable and empty")
    func createZone() {
        let state = freshState().applying([.createZone(.deck, .hidden)])
        #expect(state[.deck]?.isEmpty == true)
        #expect(state[.deck]?.visibility == .hidden)
    }

    @Test("Move transfers a card between zones and lands it on top")
    func move() {
        var s = freshState()
        s.apply(.createZone(.deck, .hidden))
        s.apply(.createZone(.hand(SeatID(0)), .ownerOnly))
        s.zones[.deck]?.push(contentsOf: [CardID(1), CardID(2)])
        s.apply(.move(CardID(2), from: .deck, to: .hand(SeatID(0))))
        #expect(s[.deck]?.cards == [CardID(1)])
        #expect(s[.hand(SeatID(0))]?.top == CardID(2))
    }

    @Test("Move-to-bottom places a card under the pile")
    func moveToBottom() {
        var s = freshState()
        s.apply(.createZone(.deck, .hidden))
        s.apply(.createZone(.discard, .public))
        s.zones[.deck]?.push(contentsOf: [CardID(1), CardID(2), CardID(3)]) // top = 3
        s.apply(.moveToBottom(CardID(3), from: .deck, to: .discard))
        s.apply(.moveToBottom(CardID(1), from: .deck, to: .discard))
        #expect(s[.discard]?.cards == [CardID(1), CardID(3)]) // 1 inserted last → bottom-most
        #expect(s[.discard]?.top == CardID(3))
        #expect(s[.deck]?.cards == [CardID(2)])
    }

    @Test("setFaceUp toggles per-card visibility")
    func faceUp() {
        var s = freshState()
        s.apply(.setFaceUp(CardID(5), true))
        #expect(s.faceUp.contains(CardID(5)))
        s.apply(.setFaceUp(CardID(5), false))
        #expect(!s.faceUp.contains(CardID(5)))
    }

    @Test("Turn and score effects accumulate")
    func turnAndScore() {
        let state = freshState(seats: 3).applying([
            .setTurn(SeatID(2)),
            .addScore(SeatID(2), 10),
            .addScore(SeatID(2), 5),
            .addScore(SeatID(0), 3),
        ])
        #expect(state.currentSeat == SeatID(2))
        #expect(state.scores[SeatID(2)] == 15)
        #expect(state.scores[SeatID(0)] == 3)
    }

    @Test("Phase stack pushes and pops")
    func phaseStack() {
        let state = freshState().applying([
            .pushPhase("deal"),
            .pushPhase("play"),
            .popPhase,
        ])
        #expect(state.phases == ["deal"])
    }

    @Test("Folding the same effects from the same start is deterministic")
    func deterministicFold() {
        let effects: [CoreEffect] = [
            .createZone(.deck, .hidden),
            .setTurn(SeatID(1)),
            .addScore(SeatID(1), 7),
            .pushPhase("play"),
        ]
        let a = freshState().applying(effects)
        let b = freshState().applying(effects)
        #expect(a == b)
    }

    @Test("seatsInTurnOrder wraps from the current seat")
    func turnOrderWraps() {
        var s = freshState(seats: 4)
        s.apply(.setTurn(SeatID(2)))
        #expect(s.seatsInTurnOrder == [SeatID(2), SeatID(3), SeatID(0), SeatID(1)])
    }
}
