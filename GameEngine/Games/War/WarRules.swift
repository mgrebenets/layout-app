//
//  WarRules.swift
//  GameEngine
//
//  Per-game configuration for War (plan §6: each game has its own configurable rules). A value
//  type so it can be swapped on the fly — the scene rebuilds its `WarGame` with new rules between
//  moves and the in-progress state carries on under them.
//

import Foundation

public struct WarRules: Sendable, Equatable {
    /// Number of cards each player lays face-down in a war before the deciding face-up card.
    /// Clamped to 1...3.
    public var warFaceDownCount: Int
    /// When the winner collects a pile, reshuffle their stock (anti-loop) vs. keep a fixed order.
    public var shuffleWinnings: Bool
    /// Common variation: the lowest card (2) beats the highest (ace). Only affects the 2-vs-ace
    /// match-up; every other comparison is still "higher rank wins".
    public var twoBeatsAce: Bool

    public init(warFaceDownCount: Int = 1, shuffleWinnings: Bool = false, twoBeatsAce: Bool = false) {
        self.warFaceDownCount = min(3, max(1, warFaceDownCount))
        self.shuffleWinnings = shuffleWinnings
        self.twoBeatsAce = twoBeatsAce
    }
}
