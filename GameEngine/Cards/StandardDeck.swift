//
//  StandardDeck.swift
//  GameEngine
//
//  Composable builders + named presets for rank×suit decks (plan §5, §6 DeckSpec).
//  `make(...)` is the open primitive; the presets are conveniences built on it.
//

import Foundation

public enum StandardDeck {

    /// Build a deck from explicit ranks/suits, optionally with multiple copies
    /// (e.g. `copies: 2` for Canasta). Order is suit-major, rank-ascending.
    public static func make(ranks: [Rank], suits: [Suit] = Suit.allCases, copies: Int = 1) -> [StandardFace] {
        precondition(copies >= 1, "need at least one copy")
        var faces: [StandardFace] = []
        faces.reserveCapacity(ranks.count * suits.count * copies)
        for _ in 0..<copies {
            for suit in suits {
                for rank in ranks {
                    faces.append(StandardFace(rank, suit))
                }
            }
        }
        return faces
    }

    /// Full 52-card deck (2–A in four suits).
    public static var standard52: [StandardFace] { make(ranks: Rank.allCases) }

    /// 36-card deck (6–A) — Durak, Bura.
    public static var stripped36: [StandardFace] { make(ranks: Rank.from(.six)) }

    /// 32-card piquet deck (7–A) — Préférence, Skat, Belote.
    public static var piquet32: [StandardFace] { make(ranks: Rank.from(.seven)) }

    /// 24-card deck (9–A) — 1000 / Tysiácha, Schnapsen.
    public static var short24: [StandardFace] { make(ranks: Rank.from(.nine)) }
}
