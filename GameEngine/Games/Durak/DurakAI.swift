//
//  DurakAI.swift
//  GameEngine
//
//  A small, deterministic opponent policy for Durak. Plays the cheapest legal card (trumps treated
//  as expensive), declines to throw in extra cards, and takes only when it can't beat an attack.
//  Picks from `legalMoves`, so it can never make an illegal move.
//

import Foundation

public struct DurakAI {
    public init() {}

    /// The move the AI would make for `seat`, or nil if it has no legal move.
    public func move(for seat: SeatID, in state: DurakState, game: DurakGame) -> DurakMove? {
        let moves = game.legalMoves(for: seat, in: state)
        guard !moves.isEmpty else { return nil }

        switch state.phase {
        case .defending:
            let beatingMoves = moves.compactMap { move -> (DurakMove, Int)? in
                if case let .defend(_, with) = move { return (move, value(with, in: state)) }
                return nil
            }
            return beatingMoves.min { $0.1 < $1.1 }?.0 ?? .take

        case .attacking:
            guard state.table.isEmpty else { return .pass } // don't pile on during throw-in
            let attacks = moves.compactMap { move -> (DurakMove, Int)? in
                if case let .attack(card) = move { return (move, value(card, in: state)) }
                return nil
            }
            return attacks.min { $0.1 < $1.1 }?.0 ?? moves.first
        }
    }

    /// Cheapness metric: low ranks are cheap; trumps are expensive (kept for later).
    private func value(_ card: CardID, in state: DurakState) -> Int {
        let face = state.registry.face(card)
        return face.rank.rawValue + (face.suit == state.trump ? 100 : 0)
    }
}
