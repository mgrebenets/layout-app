//
//  SolitaireAnalysisTests.swift
//  GameEngineTests
//
//  Exercises `SolitaireAnalysis` — the deadlock detector. Confirms which moves count as progress (to a
//  foundation, a stock/waste card into the tableau, a run that reveals a covered card, a draw that surfaces
//  a playable card) and which don't (sideways tableau shuffles, foundation pull-backs). The draw-cycle
//  tests also pin down that the simulation terminates under unlimited redeals when nothing is playable.
//

import Testing
@testable import GameEngine

@Suite("Solitaire deadlock detection")
struct SolitaireAnalysisTests {

    private let me = SeatID(0)

    /// Build a fixed Klondike state. Card indices refer to `faces`. (Mirrors the builder in SolitaireTests.)
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

    // MARK: - Meaningful moves keep the game alive

    @Test("A card that can go to a foundation is a meaningful move")
    func foundationMoveIsAlive() {
        let game = SolitaireGame()
        let s = state(faces: [StandardFace(.ace, .spades)], tableaus: [[0]], faceUp: [0])
        let analysis = SolitaireAnalysis(game: game)

        #expect(!analysis.isDeadlocked(s))
        #expect(analysis.firstMeaningfulMove(in: s)?.kind == .toFoundation)
        #expect(analysis.firstMeaningfulMove(in: s)?.move == .move(CardID(0), to: game.foundation(0)))
    }

    @Test("Moving a run that uncovers a face-down card is meaningful")
    func unlockMoveIsAlive() {
        // tableau0: face-down 2♣ under a face-up 6♠; tableau1: 7♥. 6♠→7♥ reveals the 2♣.
        let faces = [StandardFace(.two, .clubs), StandardFace(.six, .spades), StandardFace(.seven, .hearts)]
        let game = SolitaireGame(rules: SolitaireRules(drawCount: 3, redealLimit: 0))
        let s = state(faces: faces, tableaus: [[0, 1], [2]], faceUp: [1, 2])
        let analysis = SolitaireAnalysis(game: game)

        #expect(!analysis.isDeadlocked(s))
        let kinds = analysis.meaningfulMoves(in: s).map(\.kind)
        #expect(kinds.contains(.unlockTableau))
    }

    @Test("Bringing a waste card into the tableau is meaningful")
    func wasteToTableauIsAlive() {
        // 6♠ waiting on the waste can land on the tableau's 7♥; no stock, no redeals left.
        let faces = [StandardFace(.six, .spades), StandardFace(.seven, .hearts)]
        let game = SolitaireGame(rules: SolitaireRules(drawCount: 3, redealLimit: 0))
        let s = state(faces: faces, tableaus: [[1]], waste: [0], faceUp: [0, 1])
        let analysis = SolitaireAnalysis(game: game)

        #expect(!analysis.isDeadlocked(s))
        #expect(analysis.firstMeaningfulMove(in: s)?.kind == .wasteToTableau)
    }

    @Test("A draw that surfaces a playable card is meaningful (turn one)")
    func drawSurfacingAPlayCardIsAlive() {
        // foundation has A♠; the lone stock card is the 2♠ — drawing it makes a foundation play. A lone
        // king on the board can only shuffle sideways onto an empty column (ignored), so the draw is the
        // only thing that saves the game.
        let faces = [StandardFace(.ace, .spades), StandardFace(.two, .spades), StandardFace(.king, .spades)]
        let game = SolitaireGame(rules: SolitaireRules(drawCount: 1))
        let s = state(faces: faces, tableaus: [[2]], foundations: [[0]], stock: [1], faceUp: [2])
        let analysis = SolitaireAnalysis(game: game)

        #expect(!analysis.isDeadlocked(s))
        #expect(analysis.firstMeaningfulMove(in: s)?.kind == .drawToReveal)
    }

    @Test("A draw that surfaces a playable card is meaningful (turn three)")
    func drawThreeSurfacingAPlayCardIsAlive() {
        // Stock [2♠, 9♦, 9♣]: a turn-three draw lands the 2♠ (deepest of the three) on top, playable on A♠.
        let faces = [StandardFace(.ace, .spades), StandardFace(.two, .spades),
                     StandardFace(.nine, .diamonds), StandardFace(.nine, .clubs)]
        let game = SolitaireGame(rules: SolitaireRules(drawCount: 3))
        let s = state(faces: faces, foundations: [[0]], stock: [1, 2, 3])
        let analysis = SolitaireAnalysis(game: game)

        #expect(!analysis.isDeadlocked(s))
        #expect(analysis.firstMeaningfulMove(in: s)?.kind == .drawToReveal)
    }

    // MARK: - No-progress moves mean the game is dead

    @Test("A board whose only move slides a run sideways is deadlocked")
    func sidewaysShuffleIsDeadlocked() {
        // 7♥ can move onto 8♠, but it sits alone (nothing revealed) — a pure sideways shuffle.
        let faces = [StandardFace(.seven, .hearts), StandardFace(.eight, .spades)]
        let game = SolitaireGame(rules: SolitaireRules(drawCount: 3, redealLimit: 0))
        let s = state(faces: faces, tableaus: [[0], [1]], faceUp: [0, 1])
        let analysis = SolitaireAnalysis(game: game)

        // The sideways move is legal, but not meaningful.
        #expect(game.legalMoves(for: me, in: s).contains(.move(CardID(0), to: game.tableau(1))))
        #expect(analysis.meaningfulMoves(in: s).isEmpty)
        #expect(analysis.isDeadlocked(s))
    }

    @Test("A board whose only move pulls a card off a foundation is deadlocked")
    func foundationPullbackIsDeadlocked() {
        // foundation0: A♠,2♠ — the 2♠ can come down onto the tableau's 3♥, but that's not progress.
        let faces = [StandardFace(.ace, .spades), StandardFace(.two, .spades), StandardFace(.three, .hearts)]
        let game = SolitaireGame(rules: SolitaireRules(drawCount: 3, redealLimit: 0))
        let s = state(faces: faces, tableaus: [[2]], foundations: [[0, 1]], faceUp: [2])
        let analysis = SolitaireAnalysis(game: game)

        #expect(game.legalMoves(for: me, in: s).contains(.move(CardID(1), to: game.tableau(0))))
        #expect(analysis.isDeadlocked(s))
    }

    @Test("Drawing through cards none of which are playable is deadlocked (and terminates)")
    func unplayableDrawCycleIsDeadlocked() {
        // Unlimited redeals, stock of three unplayable cards, a lone 7♥ that can't move. The detector must
        // walk the draw/recycle cycle, find nothing, and stop rather than loop forever.
        let faces = [StandardFace(.seven, .hearts), StandardFace(.two, .spades),
                     StandardFace(.three, .diamonds), StandardFace(.four, .clubs)]
        let game = SolitaireGame(rules: SolitaireRules(drawCount: 3)) // unlimited redeals
        let s = state(faces: faces, tableaus: [[0]], stock: [1, 2, 3], faceUp: [0])
        let analysis = SolitaireAnalysis(game: game)

        #expect(analysis.isDeadlocked(s))
    }

    // MARK: - Won game

    @Test("A won game is not reported as deadlocked")
    func wonGameIsNotDeadlocked() {
        let faces = StandardDeck.standard52
        let foundations = (0..<4).map { Array(($0 * 13)..<($0 * 13 + 13)) }
        let game = SolitaireGame()
        let s = state(faces: faces, foundations: foundations)
        let analysis = SolitaireAnalysis(game: game)

        #expect(game.outcome(s) == .winner(me))
        #expect(!analysis.isDeadlocked(s))
    }
}
