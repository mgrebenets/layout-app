//
//  GameState.swift
//  GameEngine
//
//  A game's state embeds the universal CoreState and adds its own fields (trump, roles,
//  bids, the card registry). The engine only touches `core` (plan §4.2, §5.1).
//

import Foundation

public protocol GameState: Sendable, Equatable {
    var core: CoreState { get set }
}
