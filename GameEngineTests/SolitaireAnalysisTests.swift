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

    @Test("A board whose only move pulls a card off a foundation (opening nothing) is deadlocked")
    func foundationPullbackIsDeadlocked() {
        // foundation0: A♠,2♠ — the 2♠ can come down onto the tableau's 3♥, but nothing follows, so it's
        // not progress.
        let faces = [StandardFace(.ace, .spades), StandardFace(.two, .spades), StandardFace(.three, .hearts)]
        let game = SolitaireGame(rules: SolitaireRules(drawCount: 3, redealLimit: 0))
        let s = state(faces: faces, tableaus: [[2]], foundations: [[0, 1]], faceUp: [2])
        let analysis = SolitaireAnalysis(game: game)

        #expect(game.legalMoves(for: me, in: s).contains(.move(CardID(1), to: game.tableau(0))))
        #expect(analysis.isDeadlocked(s))
    }

    @Test("A pull-back that opens a fresh move is meaningful (3♠ down onto 4♥, then 2♦ from the waste)")
    func enablingPullbackIsAlive() {
        // Spades foundation holds A♠,2♠,3♠; a lone 4♥ sits in a tableau; the waste top is 2♦. 2♦ is stuck
        // now, but pulling 3♠ down onto the 4♥ lets the 2♦ land on it. (The reported false-positive deadlock.)
        let faces = [StandardFace(.ace, .spades), StandardFace(.two, .spades), StandardFace(.three, .spades),
                     StandardFace(.four, .hearts), StandardFace(.two, .diamonds)]
        let game = SolitaireGame(rules: SolitaireRules(drawCount: 3, redealLimit: 0))
        let s = state(faces: faces, tableaus: [[3]], foundations: [[0, 1, 2]], waste: [4], faceUp: [3, 4])
        let analysis = SolitaireAnalysis(game: game)

        // No direct move helps; the life of the board hangs on the pull-back line.
        #expect(!analysis.isDeadlocked(s))
        #expect(analysis.firstMeaningfulMove(in: s)?.kind == .foundationPullback)
        #expect(analysis.firstMeaningfulMove(in: s)?.move == .move(CardID(2), to: game.tableau(0)))
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

    @Test("A relocation that exposes a foundation card is meaningful (4♦ onto 5♠, then 5♣ up)")
    func relocationThatUnlocksFoundationIsAlive() {
        // Clubs foundation is at 4♣. A tableau holds 5♣ buried under a 4♦-3♠ run; another holds a lone 5♠.
        // Moving the 4♦ (carrying the 3♠) onto the 5♠ frees the 5♣, which then goes up to the clubs pile —
        // a cross-stack move that's only meaningful because of what it unlocks. (The reported false positive.)
        let faces = [StandardFace(.ace, .clubs), StandardFace(.two, .clubs), StandardFace(.three, .clubs),
                     StandardFace(.four, .clubs), StandardFace(.five, .clubs),
                     StandardFace(.four, .diamonds), StandardFace(.three, .spades), StandardFace(.five, .spades)]
        let game = SolitaireGame(rules: SolitaireRules(drawCount: 3, redealLimit: 0))
        let s = state(faces: faces, tableaus: [[4, 5, 6], [7]], foundations: [[0, 1, 2, 3]], faceUp: [4, 5, 6, 7])
        let analysis = SolitaireAnalysis(game: game)

        #expect(!analysis.isDeadlocked(s))
        #expect(analysis.firstMeaningfulMove(in: s)?.kind == .relocateToEnable)
        #expect(analysis.firstMeaningfulMove(in: s)?.move == .move(CardID(5), to: game.tableau(1))) // 4♦ → 5♠
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

    // MARK: - Auto-finish planner

    private func fold(_ effects: [Effect<SolitaireEffect>], into state: inout SolitaireState, with game: SolitaireGame) {
        for effect in effects {
            switch effect {
            case let .core(c): state.core.apply(c)
            case let .game(g): game.apply(g, to: &state)
            }
        }
    }

    private func apply(_ plan: [SolitaireMove], to state: SolitaireState, with game: SolitaireGame) -> SolitaireState {
        var s = state
        for move in plan {
            fold(game.lower(move, in: s), into: &s, with: game)
            while true { let batch = game.advance(s); if batch.isEmpty { break }; fold(batch, into: &s, with: game) }
        }
        return s
    }

    /// A suit-major deck ordered ace-low (index `suit*13 + 0…12` = A,2,…,10,J,Q,K) so foundation/king
    /// indices are unambiguous — `Rank.allCases` is ascending by rawValue, which puts the ace *last*.
    private func aceLowDeck() -> [StandardFace] {
        let ranks: [Rank] = [.ace, .two, .three, .four, .five, .six, .seven, .eight, .nine, .ten, .jack, .queen, .king]
        let suits: [Suit] = [.spades, .hearts, .diamonds, .clubs]
        return suits.flatMap { suit in ranks.map { StandardFace($0, suit) } }
    }

    @Test("Auto-finish plans a winning sequence from an ordered, fully-exposed board")
    func autoFinishCompletesOrderedBoard() {
        // Foundations hold A…Q of every suit; the four kings sit alone, face-up, in tableaus. Sending each
        // king up finishes the game.
        let faces = aceLowDeck()
        let foundations = (0..<4).map { Array(($0 * 13)..<($0 * 13 + 12)) } // A…Q (12 each)
        let kings = (0..<4).map { $0 * 13 + 12 }
        let game = SolitaireGame()
        let s = state(faces: faces, tableaus: kings.map { [$0] }, foundations: foundations, faceUp: Set(kings))
        let analysis = SolitaireAnalysis(game: game)

        let plan = analysis.autoFinishPlan(s)
        #expect(plan != nil)
        #expect(plan?.count == 4)
        #expect(game.outcome(apply(plan ?? [], to: s, with: game)) == .winner(me))
    }

    @Test("Auto-finish refuses a board with a buried, unreachable card")
    func autoFinishRefusesBlockedBoard() {
        // Spades foundation is at 10, but the J♠ is face-down beneath a stuck 5♥ (hearts foundation empty),
        // and there's nothing to draw — greedy can't finish.
        let faces = aceLowDeck()
        let game = SolitaireGame(rules: SolitaireRules(drawCount: 3, redealLimit: 0))
        let jackSpades = 10, fiveHearts = 13 + 4
        let s = state(faces: faces, tableaus: [[jackSpades, fiveHearts]],
                      foundations: [Array(0..<10)], faceUp: [fiveHearts])
        let analysis = SolitaireAnalysis(game: game)

        #expect(analysis.autoFinishPlan(s) == nil)
    }
}
