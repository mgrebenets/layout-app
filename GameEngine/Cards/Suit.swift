//
//  Suit.swift
//  GameEngine
//
//  Standard playing-card suit. The default suit order (clubs < diamonds < hearts <
//  spades) is just a convention; games override via a comparator (FaceComparator).
//

import Foundation

public enum Suit: Int, CaseIterable, Codable, Sendable, Comparable {
    case clubs, diamonds, hearts, spades

    public static func < (lhs: Suit, rhs: Suit) -> Bool { lhs.rawValue < rhs.rawValue }

    public enum Color: Sendable { case black, red }

    public var color: Color {
        switch self {
        case .clubs, .spades: return .black
        case .diamonds, .hearts: return .red
        }
    }

    /// Unicode pip: ♣ ♦ ♥ ♠.
    public var symbol: String {
        switch self {
        case .clubs: return "♣"
        case .diamonds: return "♦"
        case .hearts: return "♥"
        case .spades: return "♠"
        }
    }
}
