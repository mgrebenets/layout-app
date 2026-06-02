//
//  Game.swift
//  GameEngine
//
//  The per-game logic seam (plan §5.1). Everything game-specific lives behind this:
//  setup, legal-move generation, lowering moves to effects, folding game effects, flow
//  transitions, and win detection. The engine owns the universal fold and the driver loop.
//

import Foundation

public protocol Game: Sendable {
    associatedtype State: GameState
    associatedtype Move: Sendable & Equatable
    associatedtype EffectPayload: GameEffect

    /// Build the initial (dealt) state for a seeded game.
    func setup(seatCount: Int, seed: UInt64) -> State

    /// Legal moves for a seat in a state — feeds UI, validation, and AI from one source.
    func legalMoves(for seat: SeatID, in state: State) -> [Move]

    /// Lower a move into a sequence of effects (the only place a move becomes state change).
    func lower(_ move: Move, in state: State) -> [Effect<EffectPayload>]

    /// Fold one game-specific effect into the state (engine folds the core effects).
    func apply(_ effect: EffectPayload, to state: inout State)

    /// Automatic flow after a move resolves (turn/phase/round transitions), as effects.
    /// Return an empty array when the state is stable and waiting for the next move.
    func advance(_ state: State) -> [Effect<EffectPayload>]

    /// The result, or nil while the game is still in progress.
    func outcome(_ state: State) -> Outcome?
}
