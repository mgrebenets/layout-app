//
//  SolitaireRules.swift
//  GameEngine
//
//  Per-game configuration for Klondike solitaire (plan §8). A value type, like the other games' rules.
//

import Foundation

public struct SolitaireRules: Sendable, Equatable {
    /// Cards flipped from the stock to the waste per draw. Klondike "turn three" is 3; "turn one" is 1.
    public var drawCount: Int
    /// Maximum number of times the waste may be recycled back into the stock. `nil` is unlimited.
    public var redealLimit: Int?

    public init(drawCount: Int = 3, redealLimit: Int? = nil) {
        self.drawCount = max(1, drawCount)
        self.redealLimit = redealLimit.map { max(0, $0) }
    }
}
