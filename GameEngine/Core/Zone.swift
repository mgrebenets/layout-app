//
//  Zone.swift
//  GameEngine
//
//  A zone is a typed, owned, visibility-tagged ordered container of card IDs.
//  Generalizes the prior CardCollection/SlotCollection (plan §4.5).
//

import Foundation

/// An ordered container of cards, identified by `id`. Convention: the **top** of a pile
/// is the last element (`cards.last`), so draws/pushes happen at the end.
public struct Zone: Codable, Sendable, Equatable, Identifiable {
    public let id: ZoneID
    public var visibility: Visibility
    public private(set) var cards: [CardID]

    public init(id: ZoneID, visibility: Visibility, cards: [CardID] = []) {
        self.id = id
        self.visibility = visibility
        self.cards = cards
    }

    public var isEmpty: Bool { cards.isEmpty }
    public var count: Int { cards.count }
    public var top: CardID? { cards.last }
    public func contains(_ card: CardID) -> Bool { cards.contains(card) }

    /// Add a card to the top.
    public mutating func push(_ card: CardID) { cards.append(card) }

    /// Add cards to the top, preserving order (last given becomes the new top).
    public mutating func push(contentsOf newCards: [CardID]) { cards.append(contentsOf: newCards) }

    /// Add a card to the **bottom** of the pile (it will be drawn last) — e.g. War winnings
    /// returning under the stock, or a card going back to the base of a draw pile.
    public mutating func pushBottom(_ card: CardID) { cards.insert(card, at: 0) }

    /// Shuffle this zone's cards in place using the given generator (consume the in-state RNG so
    /// the result is reproducible from the seed).
    public mutating func shuffle<R: RandomNumberGenerator>(using generator: inout R) {
        cards.shuffle(using: &generator)
    }

    /// Remove and return the top card, if any.
    @discardableResult
    public mutating func popTop() -> CardID? { cards.popLast() }

    /// Remove a specific card wherever it sits. Returns whether it was present.
    @discardableResult
    public mutating func remove(_ card: CardID) -> Bool {
        guard let i = cards.firstIndex(of: card) else { return false }
        cards.remove(at: i)
        return true
    }

    /// Remove all cards and return them (e.g. collecting a trick).
    @discardableResult
    public mutating func removeAll() -> [CardID] {
        defer { cards.removeAll(keepingCapacity: true) }
        return cards
    }
}
