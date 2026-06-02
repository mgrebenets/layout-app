//
//  CardRegistry.swift
//  GameEngine
//
//  The typed table mapping CardID → face. Built once at game setup and immutable
//  thereafter. The Core engine moves IDs between zones; only game logic reaches into
//  the registry to read faces (plan §4.7).
//

import Foundation

public struct CardRegistry<Face: CardFace>: Sendable, Equatable {
    /// Faces keyed by the ID assigned at construction.
    public let faces: [CardID: Face]
    /// IDs in creation order (IDs 0..<count, matching the input order).
    public let order: [CardID]

    /// Assign sequential IDs (0, 1, 2, …) to the given faces. Duplicate faces are fine —
    /// each gets its own distinct ID (two-deck games, jokers).
    public init(_ deck: [Face]) {
        var map: [CardID: Face] = [:]
        var ids: [CardID] = []
        map.reserveCapacity(deck.count)
        ids.reserveCapacity(deck.count)
        for (i, face) in deck.enumerated() {
            let id = CardID(i)
            map[id] = face
            ids.append(id)
        }
        self.faces = map
        self.order = ids
    }

    public var count: Int { order.count }

    /// The face for an ID. Traps on an unknown ID — IDs only come from this registry.
    public func face(_ id: CardID) -> Face {
        guard let face = faces[id] else {
            preconditionFailure("CardID \(id) is not in this registry")
        }
        return face
    }

    public func faces(_ ids: [CardID]) -> [Face] { ids.map(face) }

    /// All IDs in a fresh shuffled order, consuming the (in-state) RNG so the result is
    /// reproducible from the seed.
    public func shuffled(using rng: inout SeededRNG) -> [CardID] {
        order.shuffled(using: &rng)
    }
}
