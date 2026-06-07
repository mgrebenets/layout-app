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
        case toFoundation     // a card up to an ace pile
        case wasteToTableau   // a stock/waste card brought into play
        case unlockTableau    // a run moved off a face-down card, revealing it
        case drawToReveal     // drawing surfaces a card that can then be played
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
        for move in game.legalMoves(for: s0, in: state) {
            if move == .draw { canDraw = true; continue }
            if let kind = classify(move, state) { out.append(Suggestion(move: move, kind: kind)) }
        }
        if canDraw, drawSurfacesPlayableCard(state) { out.append(Suggestion(move: .draw, kind: .drawToReveal)) }
        return out
    }

    /// The first meaningful move, stopping as soon as one is found — the board moves (cheap) are checked
    /// before the draw simulation (only needed when nothing else helps).
    public func firstMeaningfulMove(in state: SolitaireState) -> Suggestion? {
        var canDraw = false
        for move in game.legalMoves(for: s0, in: state) {
            if move == .draw { canDraw = true; continue }
            if let kind = classify(move, state) { return Suggestion(move: move, kind: kind) }
        }
        if canDraw, drawSurfacesPlayableCard(state) { return Suggestion(move: .draw, kind: .drawToReveal) }
        return nil
    }

    /// True when the game is dead: not already won, and no meaningful move remains.
    public func isDeadlocked(_ state: SolitaireState) -> Bool {
        game.outcome(state) == nil && firstMeaningfulMove(in: state) == nil
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
        var s = state
        fold(game.lower(.draw, in: s), into: &s)
        while true {
            let batch = game.advance(s)
            if batch.isEmpty { break }
            fold(batch, into: &s)
        }
        return s
    }

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
