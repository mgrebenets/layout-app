//
//  Outcome.swift
//  GameEngine
//
//  Terminal result of a game (plan §5.1). Per-seat; teams aggregate seats (§4.6).
//

import Foundation

public enum Outcome: Sendable, Equatable {
    case winner(SeatID)
    case winners([SeatID])
    case draw
}
