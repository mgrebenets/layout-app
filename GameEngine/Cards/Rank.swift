//
//  Rank.swift
//  GameEngine
//
//  Standard playing-card rank. Raw value is ace-high (ace = 14) as a sensible default;
//  games that need a different order supply a comparator (see FaceComparator) rather
//  than relying on raw ordering (plan §5, §6 RankingSpec).
//

import Foundation

public enum Rank: Int, CaseIterable, Codable, Sendable, Comparable {
    case two = 2, three, four, five, six, seven, eight, nine, ten
    case jack, queen, king, ace   // 11, 12, 13, 14

    public static func < (lhs: Rank, rhs: Rank) -> Bool { lhs.rawValue < rhs.rawValue }

    /// J, Q, K.
    public var isCourt: Bool { self == .jack || self == .queen || self == .king }
    /// 2–10 (pip cards).
    public var isPip: Bool { rawValue <= 10 }

    /// Short label: "2"…"10", "J", "Q", "K", "A".
    public var symbol: String {
        switch self {
        case .jack: return "J"
        case .queen: return "Q"
        case .king: return "K"
        case .ace: return "A"
        default: return String(rawValue)
        }
    }

    /// Ranks at or above `low` — the building block for stripped decks
    /// (e.g. `from(.six)` → 36-card deck ranks).
    public static func from(_ low: Rank) -> [Rank] {
        allCases.filter { $0.rawValue >= low.rawValue }
    }
}
