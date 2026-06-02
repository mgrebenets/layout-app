//
//  GameDriver.swift
//  GameEngine
//
//  The universal driver loop (plan §8 step 3). Holds the current state and turns a chosen
//  move into the canonical effect stream: lower → fold → advance-to-fixpoint → fold.
//  Generic over the game; the concrete core types stay non-generic.
//

import Foundation

public struct GameDriver<G: Game> {
    public let game: G
    public private(set) var state: G.State

    public init(_ game: G, seatCount: Int, seed: UInt64) {
        self.game = game
        self.state = game.setup(seatCount: seatCount, seed: seed)
    }

    public var currentSeat: SeatID { state.core.currentSeat }
    public var outcome: Outcome? { game.outcome(state) }

    public func legalMoves(for seat: SeatID) -> [G.Move] {
        game.legalMoves(for: seat, in: state)
    }

    /// Apply a move: lower it to effects, fold them, then run `advance` to a fixpoint
    /// (folding each batch). Returns the full effect stream produced — the renderer's
    /// animation script and the log entry for this move.
    @discardableResult
    public mutating func apply(_ move: G.Move) -> [Effect<G.EffectPayload>] {
        var produced = game.lower(move, in: state)
        applyEffects(produced)

        var iterations = 0
        while true {
            let transitions = game.advance(state)
            if transitions.isEmpty { break }
            applyEffects(transitions)
            produced.append(contentsOf: transitions)
            iterations += 1
            precondition(iterations < 100_000, "advance did not converge — non-idempotent flow?")
        }
        return produced
    }

    private mutating func applyEffects(_ effects: [Effect<G.EffectPayload>]) {
        for effect in effects {
            switch effect {
            case let .core(coreEffect):
                state.core.apply(coreEffect)
            case let .game(gameEffect):
                game.apply(gameEffect, to: &state)
            }
        }
    }
}
