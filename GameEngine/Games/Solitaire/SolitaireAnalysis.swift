//
//  SolitaireAnalysis.swift
//  GameEngine
//
//  A standalone "is the game still alive?" analyzer for Klondike. The engine's `legalMoves` lists every
//  *legal* move, but many of those make no progress — sliding a face-up run sideways between columns, or
//  pulling a card back down off a foundation, can loop forever. This type filters legal moves down to the
//  ones that actually advance the game and, when the only candidate is a draw, simulates the stock/waste
//  cycle to decide whether drawing ever surfaces a playable card.
//
//  A move is "meaningful" when it does one of the things that can lead to a win:
//    • sends a card to a foundation               (the ace piles — always progress);
//    • brings a stock/waste card into the tableau  (frees the waste, puts a buried card in play);
//    • moves a run so a face-down tableau card is revealed (unlocks a covered card);
//    • is a draw that eventually exposes a card playable onto the current board.
//  Pure sideways tableau shuffles and foundation pull-backs are deliberately ignored, so a board whose only
//  remaining moves are those reports as deadlocked.
//
//  The analyzer is pure and side-effect free: it works on copies of the value-type `SolitaireState`, so a
//  scene can ask `isDeadlocked` after every move, and a future hints feature can use `meaningfulMoves`.
//

import Foundation

public struct SolitaireAnalysis {

    /// Why a move counts as progress — kept so hints can later explain or rank suggestions.
    public enum MoveKind: Sendable, Equatable {
        case toFoundation       // a card up to an ace pile
        case wasteToTableau     // a stock/waste card brought into play
        case unlockTableau      // a run moved off a face-down card, revealing it
        case drawToReveal       // drawing surfaces a card that can then be played
        case foundationPullback // a card pulled back down from a foundation that opens a fresh move
        case relocateToEnable   // a tableau→tableau relocation that opens a fresh move (e.g. exposes a foundation card)
    }

    public struct Suggestion: Sendable, Equatable {
        public let move: SolitaireMove
        public let kind: MoveKind
    }

    private let game: SolitaireGame
    private let s0 = SeatID(0)
    private let waste = ZoneID("waste")

    public init(game: SolitaireGame) {
        self.game = game
    }

    // MARK: - Public API

    /// Every meaningful move available now (deduplicated only loosely — fine for hint ranking later). A
    /// draw appears at most once, as a single `.drawToReveal`, when the cycle surfaces a playable card.
    public func meaningfulMoves(in state: SolitaireState) -> [Suggestion] {
        var out: [Suggestion] = []
        var canDraw = false
        var indirect: [SolitaireMove] = []
        for move in game.legalMoves(for: s0, in: state) {
            if move == .draw { canDraw = true; continue }
            if let kind = classify(move, state) { out.append(Suggestion(move: move, kind: kind)); continue }
            indirect.append(move) // not directly meaningful — a pull-back or relocation; check it opens something
        }
        if canDraw, drawSurfacesPlayableCard(state) { out.append(Suggestion(move: .draw, kind: .drawToReveal)) }
        for move in indirect {
            if let kind = indirectKind(move, state) { out.append(Suggestion(move: move, kind: kind)) }
        }
        return out
    }

    /// The first meaningful move, stopping as soon as one is found — the board moves (cheap) are checked
    /// first, then the draw simulation, and only as a last resort the indirect moves (which look one ahead).
    public func firstMeaningfulMove(in state: SolitaireState) -> Suggestion? {
        var canDraw = false
        var indirect: [SolitaireMove] = []
        for move in game.legalMoves(for: s0, in: state) {
            if move == .draw { canDraw = true; continue }
            if let kind = classify(move, state) { return Suggestion(move: move, kind: kind) }
            indirect.append(move)
        }
        if canDraw, drawSurfacesPlayableCard(state) { return Suggestion(move: .draw, kind: .drawToReveal) }
        for move in indirect {
            if let kind = indirectKind(move, state) { return Suggestion(move: move, kind: kind) }
        }
        return nil
    }

    /// True when the game is dead: not already won, and no meaningful move remains.
    public func isDeadlocked(_ state: SolitaireState) -> Bool {
        game.outcome(state) == nil && firstMeaningfulMove(in: state) == nil
    }

    /// A sequence of moves that greedily clears the board to a win, or `nil` if greedy play can't finish
    /// from here. Used both to decide whether to *offer* an auto-finish and to *drive* it: at each step send
    /// the lowest-rank card that can go to a foundation; when none can, draw to cycle the stock; give up if a
    /// full stock cycle surfaces nothing. Foundation moves only ever lift accessible cards, so this both
    /// terminates and — for a board with no face-down cards forming ordered runs — completes.
    public func autoFinishPlan(_ state: SolitaireState) -> [SolitaireMove]? {
        var sim = state
        var plan: [SolitaireMove] = []
        var drawsSinceProgress = 0
        while game.outcome(sim) == nil {
            if let move = lowestFoundationMove(sim) {
                plan.append(move); sim = applyMove(move, sim); drawsSinceProgress = 0
            } else if game.legalMoves(for: s0, in: sim).contains(.draw), drawsSinceProgress < 64 {
                plan.append(.draw); sim = applyMove(.draw, sim); drawsSinceProgress += 1
            } else {
                return nil // stuck — greedy can't finish from here
            }
        }
        return plan
    }

    // MARK: - Classifying a single (non-draw) move

    /// The kind of progress a move makes, or `nil` if it's a no-progress move (sideways tableau shuffle,
    /// foundation pull-back) we should ignore for deadlock purposes.
    private func classify(_ move: SolitaireMove, _ state: SolitaireState) -> MoveKind? {
        guard case let .move(card, dest) = move else { return nil }
        if dest.name == "foundation" { return .toFoundation }
        guard dest.name == "tableau", let source = zone(containing: card, state) else { return nil }
        switch source.name {
        case "waste":   return .wasteToTableau
        case "tableau": return revealsHiddenCard(card, in: source, state) ? .unlockTableau : nil
        default:        return nil   // foundation → tableau pull-back never counts as progress
        }
    }

    /// A tableau→tableau move reveals a covered card only when `card` is the bottom-most face-up card of
    /// its pile (so its whole run lifts off) and a face-down card sits directly beneath it.
    private func revealsHiddenCard(_ card: CardID, in source: ZoneID, _ state: SolitaireState) -> Bool {
        let cards = state.core[source]?.cards ?? []
        guard let i = cards.firstIndex(of: card), i > 0 else { return false }
        return !state.core.faceUp.contains(cards[i - 1])
    }

    // MARK: - Indirect moves (one-ply lookahead)

    /// A move that isn't *directly* meaningful — a foundation→tableau pull-back, or a tableau→tableau
    /// relocation that doesn't itself flip a face-down card — but that **opens** a directly-meaningful move.
    /// Catches lines like "4♦ (carrying 3♠) onto the 5♠, then 5♣ up to the foundation" and the pull-back
    /// "3♠ down onto 4♥, then 2♦ from the waste onto it". Returns the kind, or nil if it opens nothing new.
    ///
    /// Loop-safe: the *enabler* must itself be directly meaningful (so it can't chain relocation→relocation
    /// forever), and undoing the candidate (`card` straight back to `source`) is ignored — that's the only
    /// reverse, which rules out the trivial shuffle-and-shuffle-back and pull-down/put-back loops.
    private func indirectKind(_ move: SolitaireMove, _ state: SolitaireState) -> MoveKind? {
        guard case let .move(card, dest) = move, dest.name == "tableau",
              let source = zone(containing: card, state),
              source.name == "foundation" || source.name == "tableau" else { return nil }
        let next = applyMove(move, state)
        for m in game.legalMoves(for: s0, in: next) {
            if m == .move(card, to: source) { continue }       // ignore simply undoing the candidate
            if classify(m, next) != nil {                      // a genuinely new, directly-meaningful move opened
                return source.name == "foundation" ? .foundationPullback : .relocateToEnable
            }
        }
        return nil
    }

    // MARK: - Draw simulation

    /// Replay draws (and recycles) on a copy of the state to see whether any card brought to the top of the
    /// waste can be played onto the current board. Drawing never changes the tableaus/foundations, so a top
    /// is "playable" exactly when the live `legalMoves` offers it a foundation or tableau destination.
    ///
    /// Recycling restores the deck to its original order, so every full pass exposes the same set of tops —
    /// one pass past the first recycle is enough to have seen them all. The redeal limit is honoured for
    /// free: once drawing is no longer legal, there is nothing left to surface.
    private func drawSurfacesPlayableCard(_ state: SolitaireState) -> Bool {
        var sim = state
        let recycleCeiling = sim.redealsUsed + 1
        var steps = 0
        while steps < 256 {
            steps += 1
            guard game.legalMoves(for: s0, in: sim).contains(.draw) else { return false }
            sim = applyDraw(sim)
            if let top = sim.core[waste]?.top, isPlayable(top, in: sim) { return true }
            if sim.redealsUsed > recycleCeiling { return false } // seen a full canonical pass — give up
        }
        return false
    }

    /// Does the live rule set let `card` (the freshly drawn waste top) go to a foundation or tableau?
    private func isPlayable(_ card: CardID, in sim: SolitaireState) -> Bool {
        for move in game.legalMoves(for: s0, in: sim) {
            if case let .move(c, dest) = move, c == card, dest.name == "foundation" || dest.name == "tableau" {
                return true
            }
        }
        return false
    }

    /// Lower a draw and run `advance` to a fixpoint — exactly what the driver does, on a copy.
    private func applyDraw(_ state: SolitaireState) -> SolitaireState {
        applyMove(.draw, state)
    }

    /// Apply any move (lower + advance to a fixpoint) on a copy — the driver's step, side-effect free.
    private func applyMove(_ move: SolitaireMove, _ state: SolitaireState) -> SolitaireState {
        var s = state
        fold(game.lower(move, in: s), into: &s)
        while true {
            let batch = game.advance(s)
            if batch.isEmpty { break }
            fold(batch, into: &s)
        }
        return s
    }

    /// The foundation move that plays the lowest-rank card — peeling tableau tops in build-up order so a
    /// card needed later gets exposed in time. `nil` when nothing can go up right now.
    private func lowestFoundationMove(_ state: SolitaireState) -> SolitaireMove? {
        var best: (move: SolitaireMove, rank: Int)?
        for move in game.legalMoves(for: s0, in: state) {
            guard case let .move(card, dest) = move, dest.name == "foundation" else { continue }
            let rank = rankValue(state.registry.face(card).rank)
            if best == nil || rank < best!.rank { best = (move, rank) }
        }
        return best?.move
    }

    /// Klondike rank value with the ace low (A=1 … K=13), matching `SolitaireGame`.
    private func rankValue(_ rank: Rank) -> Int { rank == .ace ? 1 : rank.rawValue }

    private func fold(_ effects: [Effect<SolitaireEffect>], into state: inout SolitaireState) {
        for effect in effects {
            switch effect {
            case let .core(coreEffect): state.core.apply(coreEffect)
            case let .game(gameEffect): game.apply(gameEffect, to: &state)
            }
        }
    }

    private func zone(containing card: CardID, _ state: SolitaireState) -> ZoneID? {
        for (id, zone) in state.core.zones where zone.contains(card) { return id }
        return nil
    }
}
