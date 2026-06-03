//
//  DurakRules.swift
//  GameEngine
//
//  Per-game configuration for Durak (plan §6). Value type so it can be swapped on the fly.
//

import Foundation

/// Who gets offered a throw-in first when several attackers could pile on.
public enum ThrowInPriority: Sendable, Equatable {
    /// The principal attacker always gets first dibs; co-attackers are offered clockwise after.
    case principalFirst
    /// Offers proceed clockwise around the table; no attacker has special standing.
    case roundRobin
}

public struct DurakRules: Sendable, Equatable {
    /// Cards each player is refilled to between bouts (classic: 6).
    public var handSize: Int
    /// Lowest rank in the deck (`.six` → 36-card deck; `.two` → full 52).
    public var lowestRank: Rank
    /// Whether attackers may throw in extra cards whose rank already appears on the table.
    public var allowThrowIn: Bool
    /// Whether, once the defender declares a take, attackers may keep throwing in matching cards
    /// (within the defender's room) before the defender scoops them all up.
    public var throwInOnTake: Bool
    /// Priority order when several attackers could throw in (multiplayer).
    public var throwInPriority: ThrowInPriority
    /// Classic rule: the very first bout of the game is limited to 5 attack cards (instead of 6).
    public var firstAttackMaxFive: Bool

    public init(handSize: Int = 6,
                lowestRank: Rank = .six,
                allowThrowIn: Bool = true,
                throwInOnTake: Bool = true,
                throwInPriority: ThrowInPriority = .principalFirst,
                firstAttackMaxFive: Bool = true) {
        self.handSize = max(1, handSize)
        self.lowestRank = lowestRank
        self.allowThrowIn = allowThrowIn
        self.throwInOnTake = throwInOnTake
        self.throwInPriority = throwInPriority
        self.firstAttackMaxFive = firstAttackMaxFive
    }
}
