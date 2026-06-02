//
//  StandardFace.swift
//  GameEngine
//
//  The face for ordinary rank×suit decks (52, stripped 36/32/24, …).
//

import Foundation

public struct StandardFace: CardFace, CustomStringConvertible, Comparable {
    public let rank: Rank
    public let suit: Suit

    public init(_ rank: Rank, _ suit: Suit) {
        self.rank = rank
        self.suit = suit
    }

    /// Natural order: by rank (ace-high), then suit. Games needing a different order
    /// pass a `FaceComparator` instead of relying on this.
    public static func < (lhs: StandardFace, rhs: StandardFace) -> Bool {
        (lhs.rank, lhs.suit) < (rhs.rank, rhs.suit)
    }

    public var description: String { "\(rank.symbol)\(suit.symbol)" }
}
