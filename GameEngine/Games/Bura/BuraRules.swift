//
//  BuraRules.swift
//  GameEngine
//
//  Per-game configuration for Bura (plan §6). A value type so it can be swapped on the fly, like
//  WarRules / DurakRules. Bura is the engine's first point-scoring game: capture cards worth points
//  and either play the deal out (most points wins) or race to a threshold.
//

import Foundation

/// How captured cards are scored.
public enum BuraScoring: Sendable, Equatable {
    /// Full pip count — A=11, 10=10, K=4, Q=3, J=2 (120 in the deck).
    case full
    /// "Clear" (чистые) — only aces and tens count, 10 each (80 in the deck).
    case clearOnly
}

public struct BuraRules: Sendable, Equatable {
    /// Score that wins immediately when reached. `nil` plays the whole deal out and the higher final
    /// score wins (a tie is a draw). Some traditions cite 31; casual play counts at the end.
    public var winningScore: Int?
    /// Cards held (and refilled to) per player. Standard Bura is 3.
    public var handSize: Int
    /// Allow Bura's signature 1–3 same-suit lead. When off, every lead is a single card.
    public var allowMultiCardLead: Bool
    /// How captured cards are scored.
    public var scoring: BuraScoring
    /// When the responder *can't (or won't) beat*, their surrendered cards go face down, so the
    /// opponent can't read the points they conceded (the "со сносом взакрытую" variant).
    public var faceDownSurrender: Bool
    /// A lead-first combo (three of one suit — "бура"/"молодка" — or three aces incl. the trump ace)
    /// takes the opening lead. Not a win: the led cards can still be beaten.
    public var comboLeadsFirst: Bool

    public init(winningScore: Int? = nil, handSize: Int = 3, allowMultiCardLead: Bool = true,
                scoring: BuraScoring = .full, faceDownSurrender: Bool = false,
                comboLeadsFirst: Bool = true) {
        self.winningScore = winningScore.map { max(1, $0) }
        self.handSize = max(1, handSize)
        self.allowMultiCardLead = allowMultiCardLead
        self.scoring = scoring
        self.faceDownSurrender = faceDownSurrender
        self.comboLeadsFirst = comboLeadsFirst
    }

    /// Point value of a captured rank under this configuration.
    public func points(_ rank: Rank) -> Int { Self.points(rank, scoring: scoring) }

    /// Point value of a captured rank under `scoring`. Single source of truth for scoring and the UI.
    public static func points(_ rank: Rank, scoring: BuraScoring = .full) -> Int {
        switch scoring {
        case .full:
            switch rank {
            case .ace: return 11
            case .ten: return 10
            case .king: return 4
            case .queen: return 3
            case .jack: return 2
            default: return 0
            }
        case .clearOnly:
            return (rank == .ace || rank == .ten) ? 10 : 0
        }
    }
}
