//
//  Effect.swift
//  GameEngine
//
//  The full effect = universal core vocabulary + the game's own payload (plan §4.1, §10).
//  This is the canonical event: animation script, network packet, and replay log in one.
//

import Foundation

public enum Effect<Payload: GameEffect>: Sendable, Equatable {
    /// A universal effect the engine folds into `CoreState`.
    case core(CoreEffect)
    /// A game-specific effect the game folds into its own state.
    case game(Payload)
}
