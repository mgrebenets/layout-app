//
//  CoreState+Apply.swift
//  GameEngine
//
//  The engine-owned fold: applyEffect for the universal vocabulary (plan §4.1–4.2).
//  This is game-agnostic — games never hand-write these mutations, they only *lower*
//  moves into effects. State == effects.reduce(empty, apply).
//

import Foundation

public extension CoreState {

    /// Fold a single universal effect into the state.
    mutating func apply(_ effect: CoreEffect) {
        switch effect {
        case let .createZone(id, visibility):
            zones[id] = Zone(id: id, visibility: visibility)

        case let .move(card, from, to):
            precondition(zones[from] != nil, "move from missing zone \(from)")
            precondition(zones[to] != nil, "move to missing zone \(to)")
            zones[from]?.remove(card)
            zones[to]?.push(card)

        case let .moveToBottom(card, from, to):
            precondition(zones[from] != nil, "move from missing zone \(from)")
            precondition(zones[to] != nil, "move to missing zone \(to)")
            zones[from]?.remove(card)
            zones[to]?.pushBottom(card)

        case let .shuffle(zoneID):
            precondition(zones[zoneID] != nil, "shuffle of missing zone \(zoneID)")
            // Pull the zone out before shuffling so we don't access `zones` and `rng` simultaneously.
            var zone = zones[zoneID]!
            zone.shuffle(using: &rng)
            zones[zoneID] = zone

        case let .setFaceUp(card, up):
            if up { faceUp.insert(card) } else { faceUp.remove(card) }

        case let .setTurn(seat):
            currentSeat = seat

        case let .addScore(seat, points):
            scores[seat, default: 0] += points

        case let .pushPhase(name):
            phases.append(name)

        case .popPhase:
            _ = phases.popLast()
        }
    }

    /// Fold a sequence of effects, returning the resulting state (non-mutating).
    func applying(_ effects: [CoreEffect]) -> CoreState {
        var state = self
        for effect in effects { state.apply(effect) }
        return state
    }
}
