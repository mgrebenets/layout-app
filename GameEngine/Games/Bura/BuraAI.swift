//
//  BuraAI.swift
//  GameEngine
//
//  A small, deterministic Bura opponent. Leads its cheapest single card (low points, low rank,
//  trumps hoarded); when answering, beats with the cheapest set that beats everything, otherwise
//  surrenders its lowest-value cards. Picks from `legalMoves`, so it can never play illegally.
//

import Foundation

public struct BuraAI {
    public init() {}

    public func move(for seat: SeatID, in state: BuraState, game: BuraGame) -> BuraMove? {
        let moves = game.legalMoves(for: seat, in: state)
        guard !moves.isEmpty else { return nil }

        switch state.phase {
        case .buraOffer:
            return .claimBura // bura is a guaranteed trick win — the leader can't hold three trumps too

        case .leading:
            // Holding bura, slam all three trumps (the opponent can't beat them); else lead cheap.
            if let bura = moves.first(where: {
                if case let .lead(cards) = $0 {
                    return cards.count == 3 && cards.allSatisfy { state.registry.face($0).suit == state.trump }
                }
                return false
            }) { return bura }
            let singles = moves.filter { if case let .lead(cards) = $0 { return cards.count == 1 } else { return false } }
            let pool = singles.isEmpty ? moves : singles
            return pool.min { cost(of: $0, in: state) < cost(of: $1, in: state) }

        case .responding:
            let beating = moves.filter {
                if case let .respond(cards) = $0 { return game.beatsAll(cards, state.attack, in: state) }
                return false
            }
            let pool = beating.isEmpty ? moves : beating // beat cheaply, or surrender cheaply
            return pool.min { cost(of: $0, in: state) < cost(of: $1, in: state) }
        }
    }

    /// Cheapness of the cards a move plays: point value dominates, then rank, with trumps made dear.
    private func cost(of move: BuraMove, in state: BuraState) -> Int {
        let cards: [CardID]
        switch move {
        case let .lead(c): cards = c
        case let .respond(c): cards = c
        case .claimBura, .declineBura: return 0 // never ranked — handled before cost is consulted
        }
        return cards.reduce(0) { acc, id in
            let face = state.registry.face(id)
            return acc + BuraRules.points(face.rank) * 10 + BuraGame.strength(face.rank) + (face.suit == state.trump ? 200 : 0)
        }
    }
}
