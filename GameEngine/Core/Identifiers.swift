//
//  Identifiers.swift
//  GameEngine
//
//  Core identity types. Domain-agnostic — the engine moves these around without
//  interpreting what they "mean" (see card-engine-plan.md §4.7).
//

import Foundation

/// Stable identity for a single card. The engine deals in `CardID`s; the typed face
/// lives in a `CardRegistry` consulted only by game logic.
public struct CardID: Hashable, Codable, Sendable, Comparable, ExpressibleByIntegerLiteral, CustomStringConvertible {
    public let value: Int
    public init(_ value: Int) { self.value = value }
    public init(integerLiteral value: Int) { self.value = value }
    public static func < (lhs: CardID, rhs: CardID) -> Bool { lhs.value < rhs.value }
    public var description: String { "#\(value)" }
}

/// A seat at the table. Players/teams are groupings over seats (plan §4.6).
public struct SeatID: Hashable, Codable, Sendable, Comparable, ExpressibleByIntegerLiteral, CustomStringConvertible {
    public let index: Int
    public init(_ index: Int) { self.index = index }
    public init(integerLiteral value: Int) { self.index = value }
    public static func < (lhs: SeatID, rhs: SeatID) -> Bool { lhs.index < rhs.index }
    public var description: String { "seat\(index)" }
}

/// Identity for a zone (a card container). `name` is a game-defined convention
/// (e.g. "hand", "deck", "discard", "trick", "meld"); `owner`/`index` disambiguate
/// per-seat and indexed zones (meld 2, foundation 3, …).
public struct ZoneID: Hashable, Codable, Sendable, CustomStringConvertible {
    public let name: String
    public let owner: SeatID?
    public let index: Int?

    public init(_ name: String, owner: SeatID? = nil, index: Int? = nil) {
        self.name = name
        self.owner = owner
        self.index = index
    }

    public var description: String {
        var s = name
        if let owner { s += "@\(owner.index)" }
        if let index { s += "[\(index)]" }
        return s
    }

    // Common conventions — games are free to define their own.
    public static let deck = ZoneID("deck")
    public static let discard = ZoneID("discard")
    public static let table = ZoneID("table")
    public static let trick = ZoneID("trick")
    public static func hand(_ seat: SeatID) -> ZoneID { ZoneID("hand", owner: seat) }
}

/// Who may see the faces of cards in a zone. Drives `playerView` redaction (plan §4.4, §10).
public enum Visibility: String, Codable, Sendable {
    /// Everyone sees the faces (e.g. the current trick, melds, the up-pile).
    case `public`
    /// Only the owning seat sees the faces (e.g. a player's hand).
    case ownerOnly
    /// Nobody sees the faces (e.g. the face-down deck, committed face-down moves).
    case hidden
}
