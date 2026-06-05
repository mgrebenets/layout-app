//
//  SolitaireTests.swift
//  GameEngineTests
//
//  Validates Klondike — the engine's first single-player, non-trick game (plan §7). Covers the deal,
//  foundation build-up, tableau build-down (alternating colour, kings to empties), drawing three and
//  recycling, auto-revealing an exposed tableau card, the win condition, and a greedy auto-player that
//  terminates while conserving all 52 cards.
//

import Testing
@testable import GameEngine

@Suite("Solitaire")
struct SolitaireTests {

    private let me = SeatID(0)

    private func total(_ state: SolitaireState) -> Int {
        state.core.zones.values.reduce(0) { $0 + $1.count }
    }

    private func fold(_ effects: [Effect<SolitaireEffect>], into state: inout SolitaireState, with game: SolitaireGame) {
        for effect in effects {
            switch effect {
            case let .core(coreEffect): state.core.apply(coreEffect)
            case let .game(gameEffect): game.apply(gameEffect, to: &state)
            }
        }
    }

    /// Lower a move and run `advance` to a fixpoint — what the driver does.
    private func play(_ move: SolitaireMove, _ state: inout SolitaireState, _ game: SolitaireGame) {
        fold(game.lower(move, in: state), into: &state, with: game)
        var guardCount = 0
        while true {
            let batch = game.advance(state)
            if batch.isEmpty { break }
            fold(batch, into: &state, with: game)
            guardCount += 1
            if guardCount > 10_000 { break }
        }
    }

    /// Build a fixed Klondike state. Card indices refer to `faces`.
    private func state(faces: [StandardFace], tableaus: [[Int]] = [], foundations: [[Int]] = [],
                       stock: [Int] = [], waste: [Int] = [], faceUp: Set<Int> = []) -> SolitaireState {
        let registry = CardRegistry(faces)
        var core = CoreState(seatCount: 1, rng: SeededRNG(seed: 0), currentSeat: me)
        core.apply(.createZone(.deck, .hidden))
        core.apply(.createZone(ZoneID("waste"), .public))
        for i in 0..<4 { core.apply(.createZone(ZoneID("foundation", index: i), .public)) }
        for i in 0..<7 { core.apply(.createZone(ZoneID("tableau", index: i), .hidden)) }
        for (i, pile) in tableaus.enumerated() { core.zones[ZoneID("tableau", index: i)]?.push(contentsOf: pile.map { CardID($0) }) }
        for (i, pile) in foundations.enumerated() { core.zones[ZoneID("foundation", index: i)]?.push(contentsOf: pile.map { CardID($0) }) }
        core.zones[.deck]?.push(contentsOf: stock.map { CardID($0) })
        core.zones[ZoneID("waste")]?.push(contentsOf: waste.map { CardID($0) })
        for v in faceUp { core.faceUp.insert(CardID(v)) }
        return SolitaireState(core: core, registry: registry)
    }

    // MARK: - Setup

    @Test("The deal makes seven tableau piles 1…7, only their tops face-up, with a 24-card stock")
    func setupDeals() {
        let game = SolitaireGame()
        let s = game.setup(seatCount: 1, seed: 1)
        for i in 0..<7 { #expect(s.core[game.tableau(i)]?.count == i + 1) }
        #expect(s.core[.deck]?.count == 24)
        #expect(s.core[ZoneID("waste")]?.isEmpty == true)
        for i in 0..<4 { #expect(s.core[game.foundation(i)]?.isEmpty == true) }
        #expect(s.core.faceUp.count == 7) // exactly one face-up per tableau pile
        #expect(total(s) == 52)
    }

    // MARK: - Foundations

    @Test("Foundations build up by suit: an ace then the two")
    func foundationBuildsUp() {
        let faces = [StandardFace(.ace, .spades), StandardFace(.two, .spades)]
        var s = state(faces: faces, tableaus: [[0], [1]], faceUp: [0, 1])
        let game = SolitaireGame()

        #expect(game.legalMoves(for: me, in: s).contains(.move(CardID(0), to: game.foundation(0))))
        // The two can't go up yet — the ace isn't down.
        #expect(!game.legalMoves(for: me, in: s).contains(where: {
            if case let .move(c, dest) = $0 { return c == CardID(1) && dest.name == "foundation" }
            return false
        }))
        play(.move(CardID(0), to: game.foundation(0)), &s, game)
        play(.move(CardID(1), to: game.foundation(0)), &s, game)
        #expect(s.core[game.foundation(0)]?.count == 2)
    }

    // MARK: - Tableau

    @Test("Tableau builds down in alternating colour; same colour is rejected")
    func tableauBuildsDownAlternating() {
        // 7♥ on top of tableau 0; a black 6 may land on it, a red 6 may not.
        let faces = [StandardFace(.seven, .hearts), StandardFace(.six, .spades), StandardFace(.six, .hearts)]
        let s = state(faces: faces, tableaus: [[0], [1], [2]], faceUp: [0, 1, 2])
        let game = SolitaireGame()
        let legal = game.legalMoves(for: me, in: s)
        #expect(legal.contains(.move(CardID(1), to: game.tableau(0))))   // 6♠ → 7♥
        #expect(!legal.contains(.move(CardID(2), to: game.tableau(0))))  // 6♥ → 7♥ rejected
    }

    @Test("Only a king may move to an empty tableau pile")
    func kingToEmptyPile() {
        let faces = [StandardFace(.king, .spades), StandardFace(.queen, .spades)]
        let s = state(faces: faces, tableaus: [[0], [], [1]], faceUp: [0, 1])
        let game = SolitaireGame()
        let legal = game.legalMoves(for: me, in: s)
        #expect(legal.contains(.move(CardID(0), to: game.tableau(1))))   // K♠ → empty
        #expect(!legal.contains(.move(CardID(1), to: game.tableau(1))))  // Q♠ → empty rejected
    }

    @Test("Moving a tableau card carries the whole face-up run on top of it")
    func tableauRunMoves() {
        // tableau0: 8♠(face up) with 7♥, 6♠ built down on it; move 8♠ onto a red 9 in tableau1.
        let faces = [StandardFace(.eight, .spades), StandardFace(.seven, .hearts), StandardFace(.six, .spades),
                     StandardFace(.nine, .diamonds)]
        var s = state(faces: faces, tableaus: [[0, 1, 2], [3]], faceUp: [0, 1, 2, 3])
        let game = SolitaireGame()
        #expect(game.legalMoves(for: me, in: s).contains(.move(CardID(0), to: game.tableau(1))))
        play(.move(CardID(0), to: game.tableau(1)), &s, game)
        #expect(s.core[game.tableau(0)]?.isEmpty == true)
        #expect(s.core[game.tableau(1)]?.cards == [CardID(3), CardID(0), CardID(1), CardID(2)]) // 9♦ 8♠ 7♥ 6♠
    }

    @Test("Moving the face-up top reveals the face-down card beneath it")
    func exposedCardFlipsUp() {
        // tableau0: a face-down 5♦ under a face-up A♠. Move the ace off → the 5♦ turns up.
        let faces = [StandardFace(.ace, .spades), StandardFace(.five, .diamonds)]
        var s = state(faces: faces, tableaus: [[1, 0]], faceUp: [0]) // index 1 (5♦) is face-down, under 0 (A♠)
        let game = SolitaireGame()
        play(.move(CardID(0), to: game.foundation(0)), &s, game)
        #expect(s.core[game.tableau(0)]?.cards == [CardID(1)])
        #expect(s.core.faceUp.contains(CardID(1)) == true) // the 5♦ was revealed
    }

    // MARK: - Stock / waste

    @Test("Drawing turns three to the waste; recycling refills the stock once the waste is spent")
    func drawThreeAndRecycle() {
        let faces = StandardDeck.standard52
        var s = state(faces: faces, stock: [0, 1, 2, 3, 4]) // five cards in the stock
        let game = SolitaireGame() // draw 3, unlimited redeals

        play(.draw, &s, game)
        #expect(s.core[ZoneID("waste")]?.count == 3)
        #expect(s.core[ZoneID("waste")]?.top == CardID(2)) // last of the three flipped is on top
        #expect(s.core[.deck]?.count == 2)

        play(.draw, &s, game)                              // only two left
        #expect(s.core[.deck]?.isEmpty == true)
        #expect(s.core[ZoneID("waste")]?.count == 5)

        play(.draw, &s, game)                              // stock empty → recycle
        #expect(s.core[.deck]?.count == 5)
        #expect(s.core[ZoneID("waste")]?.isEmpty == true)
        #expect(s.redealsUsed == 1)
    }

    @Test("With no redeals left, an empty stock offers no draw")
    func redealLimitStopsDraw() {
        let faces = StandardDeck.standard52
        let s = state(faces: faces, waste: [0, 1, 2]) // empty stock, cards in the waste
        let game = SolitaireGame(rules: SolitaireRules(drawCount: 3, redealLimit: 0))
        #expect(!game.legalMoves(for: me, in: s).contains(.draw))
    }

    // MARK: - Winning & playthrough

    @Test("Filling all four foundations wins")
    func fullFoundationsWin() {
        let faces = StandardDeck.standard52
        let foundations = (0..<4).map { Array(($0 * 13)..<($0 * 13 + 13)) }
        let s = state(faces: faces, foundations: foundations)
        #expect(SolitaireGame().outcome(s) == .winner(me))
    }

    @Test("A greedy auto-player terminates and conserves all 52 cards")
    func greedyPlaythrough() {
        let game = SolitaireGame(rules: SolitaireRules(drawCount: 3, redealLimit: 0))
        for seed: UInt64 in [1, 7, 42, 0xACE, 0xBED] {
            var s = game.setup(seatCount: 1, seed: seed)
            var moves = 0
            while game.outcome(s) == nil, moves < 2000 {
                let legal = game.legalMoves(for: me, in: s)
                // Prefer sending a card to a foundation; otherwise draw; otherwise stop.
                let toFoundation = legal.first { if case let .move(_, dest) = $0 { return dest.name == "foundation" }; return false }
                guard let move = toFoundation ?? legal.first(where: { $0 == .draw }) else { break }
                play(move, &s, game)
                moves += 1
                #expect(total(s) == 52)
            }
            #expect(total(s) == 52)
            #expect(moves < 2000) // terminates well within the cap
        }
    }
}
