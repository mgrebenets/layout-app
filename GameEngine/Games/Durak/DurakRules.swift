//
//  DurakRules.swift
//  GameEngine
//
//  Per-game configuration for Durak (plan §6). Value type so it can be swapped on the fly.
//

import Foundation

public struct DurakRules: Sendable, Equatable {
    /// Cards each player is refilled to between bouts (classic: 6).
    public var handSize: Int
    /// Lowest rank in the deck (`.six` → 36-card deck; `.two` → full 52).
    public var lowestRank: Rank
    /// Whether the attacker may throw in extra cards whose rank already appears on the table.
    public var allowThrowIn: Bool
    /// Whether, once the defender declares a take, attackers may keep throwing in matching cards
    /// (within the defender's room) before the defender scoops them all up.
    public var throwInOnTake: Bool

    public init(handSize: Int = 6, lowestRank: Rank = .six, allowThrowIn: Bool = true, throwInOnTake: Bool = true) {
        self.handSize = max(1, handSize)
        self.lowestRank = lowestRank
        self.allowThrowIn = allowThrowIn
        self.throwInOnTake = throwInOnTake
    }
}
