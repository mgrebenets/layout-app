//
//  WarTests.swift
//  GameEngineTests
//
//  End-to-end validation of the engine loop via War (plan §7). Exercises setup, the
//  forced-move lowering, advance-driven battle resolution, and the win condition.
//

import Testing
@testable import GameEngine

@Suite("War")
struct WarTests {

    private let s0 = SeatID(0)
    private let s1 = SeatID(1)
    private func stock(_ seat: SeatID) -> ZoneID { ZoneID("stock", owner: seat) }
    private func played(_ seat: SeatID) -> ZoneID { ZoneID("played", owner: seat) }

    private func totalCards(_ state: WarState) -> Int {
        state.core.zones.values.reduce(0) { $0 + $1.count }
    }

    /// Fold War's effects (all `.core`) into a state.
    private func fold(_ effects: [Effect<WarEffect>], into state: inout WarState) {
        for case let .core(coreEffect) in effects {
            state.core.apply(coreEffect)
        }
    }

    @Test("Setup deals the deck evenly into two face-down stocks")
    func setupDealsEvenly() {
        let state = WarGame().setup(seatCount: 2, seed: 1)
        #expect(state.registry.count == 52)
        #expect(state.core[stock(s0)]?.count == 26)
        #expect(state.core[stock(s1)]?.count == 26)
        #expect(state.core[played(s0)]?.isEmpty == true)
        #expect(state.core.currentSeat == s0)
        #expect(totalCards(state) == 52)
    }

    @Test("A decisive battle awards the whole pile to the higher card")
    func decisiveBattle() {
        // CardID(0) = K♠ for seat 0, CardID(1) = 2♥ for seat 1.
        let registry = CardRegistry([StandardFace(.king, .spades), StandardFace(.two, .hearts)])
        var core = CoreState(seatCount: 2, rng: SeededRNG(seed: 0), currentSeat: s1)
        core.apply(.createZone(stock(s0), .hidden))
        core.apply(.createZone(stock(s1), .hidden))
        core.apply(.createZone(played(s0), .public))
        core.apply(.createZone(played(s1), .public))
        core.zones[played(s0)]?.push(CardID(0)) // K♠
        core.zones[played(s1)]?.push(CardID(1)) // 2♥
        var state = WarState(core: core, registry: registry)

        let effects = WarGame().advance(state)
        for case let .core(coreEffect) in effects { state.core.apply(coreEffect) }

        #expect(state.core[stock(s0)]?.count == 2)       // seat 0 (king) took both
        #expect(state.core[played(s0)]?.isEmpty == true)
        #expect(state.core[played(s1)]?.isEmpty == true)
        #expect(state.core.currentSeat == s0)            // winner leads next
    }

    @Test("A tie triggers a war: each player lays face-down cards then one face-up")
    func warLaysCards() {
        // Tied tops (both kings); each stock has 3 more cards.
        let faces = [
            StandardFace(.king, .spades),   // 0 — seat0 comparison (tie)
            StandardFace(.king, .hearts),   // 1 — seat1 comparison (tie)
            StandardFace(.two, .clubs),     // 2 — seat0 stock
            StandardFace(.three, .clubs),   // 3 — seat0 stock
            StandardFace(.four, .clubs),    // 4 — seat0 stock (top)
            StandardFace(.five, .diamonds), // 5 — seat1 stock
            StandardFace(.six, .diamonds),  // 6 — seat1 stock
            StandardFace(.seven, .diamonds) // 7 — seat1 stock (top)
        ]
        let registry = CardRegistry(faces)
        var core = CoreState(seatCount: 2, rng: SeededRNG(seed: 0), currentSeat: s0)
        core.apply(.createZone(stock(s0), .hidden))
        core.apply(.createZone(stock(s1), .hidden))
        core.apply(.createZone(played(s0), .public))
        core.apply(.createZone(played(s1), .public))
        core.zones[stock(s0)]?.push(contentsOf: [CardID(2), CardID(3), CardID(4)])
        core.zones[stock(s1)]?.push(contentsOf: [CardID(5), CardID(6), CardID(7)])
        core.zones[played(s0)]?.push(CardID(0)); core.apply(.setFaceUp(CardID(0), true))
        core.zones[played(s1)]?.push(CardID(1)); core.apply(.setFaceUp(CardID(1), true))
        var state = WarState(core: core, registry: registry)

        let game = WarGame(rules: WarRules(warFaceDownCount: 2))
        fold(game.advance(state), into: &state) // war: 2 face-down + 1 face-up each

        #expect(state.core[played(s0)]?.count == 4) // original 1 + (2 down + 1 up)
        #expect(state.core[played(s1)]?.count == 4)
        // The new comparison cards are face-up, the buried war cards are not.
        let top0 = state.core[played(s0)]!.top!
        #expect(state.core.faceUp.contains(top0))
        #expect(!state.core.faceUp.contains(CardID(2))) // a face-down war card
        #expect(totalCards(state) == 8)
    }

    @Test("Shuffled winnings is deterministic for a fixed seed")
    func shuffledWinningsDeterministic() {
        func playout(seed: UInt64) -> [Int] {
            var driver = GameDriver(WarGame(rules: WarRules(shuffleWinnings: true)), seatCount: 2, seed: seed)
            var moves = 0
            while driver.outcome == nil, moves < 5_000 {
                guard let move = driver.legalMoves(for: driver.currentSeat).first else { break }
                driver.apply(move); moves += 1
            }
            // Fingerprint the final stock contents.
            return (driver.state.core[stock(s0)]?.cards ?? []).map(\.value)
        }
        #expect(playout(seed: 123) == playout(seed: 123))
    }

    @Test("The two-beats-ace variation flips the 2 vs ace result")
    func twoBeatsAce() {
        func winner(twoBeatsAce: Bool) -> Outcome? {
            let registry = CardRegistry([StandardFace(.two, .clubs), StandardFace(.ace, .spades)])
            var core = CoreState(seatCount: 2, rng: SeededRNG(seed: 0), currentSeat: s1)
            core.apply(.createZone(stock(s0), .hidden))
            core.apply(.createZone(stock(s1), .hidden))
            core.apply(.createZone(played(s0), .public))
            core.apply(.createZone(played(s1), .public))
            core.zones[played(s0)]?.push(CardID(0)) // 2♣ (seat 0)
            core.zones[played(s1)]?.push(CardID(1)) // A♠ (seat 1)
            var state = WarState(core: core, registry: registry)
            let game = WarGame(rules: WarRules(twoBeatsAce: twoBeatsAce))
            fold(game.advance(state), into: &state)
            return game.outcome(state)
        }
        #expect(winner(twoBeatsAce: true) == .winner(s0))   // the 2 beats the ace
        #expect(winner(twoBeatsAce: false) == .winner(s1))  // standard: ace wins
    }

    @Test("A seeded playthrough conserves all 52 cards and makes progress")
    func playthroughConservesCards() {
        var driver = GameDriver(WarGame(), seatCount: 2, seed: 0xC0FFEE)
        var moves = 0
        while driver.outcome == nil {
            guard let move = driver.legalMoves(for: driver.currentSeat).first else { break }
            driver.apply(move)
            let total = driver.state.core.zones.values.reduce(0) { $0 + $1.count }
            #expect(total == 52)
            moves += 1
            if moves >= 200_000 { break }
        }
        #expect(moves >= 2) // the turn loop actually advanced
        let finalTotal = driver.state.core.zones.values.reduce(0) { $0 + $1.count }
        #expect(finalTotal == 52)
    }

    @Test("Win is declared when a player runs out of cards")
    func winCondition() {
        let registry = CardRegistry([StandardFace(.ace, .spades), StandardFace(.three, .clubs)])
        var core = CoreState(seatCount: 2, rng: SeededRNG(seed: 0), currentSeat: s0)
        core.apply(.createZone(stock(s0), .hidden))
        core.apply(.createZone(stock(s1), .hidden))
        core.apply(.createZone(played(s0), .public))
        core.apply(.createZone(played(s1), .public))
        // Seat 1 has nothing at all → seat 0 wins.
        core.zones[stock(s0)]?.push(contentsOf: [CardID(0), CardID(1)])
        let state = WarState(core: core, registry: registry)
        #expect(WarGame().outcome(state) == .winner(s0))
    }
}
