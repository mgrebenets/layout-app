//
//  GameEffect.swift
//  GameEngine
//
//  Marker for a game's own effect payload (plan §10: typed per-game effect variants).
//  The engine folds CoreEffects; the game folds these. A game with no game-specific
//  state (e.g. War) uses an uninhabited enum.
//

import Foundation

public protocol GameEffect: Sendable, Equatable {}
