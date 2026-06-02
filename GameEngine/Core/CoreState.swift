//
//  CoreState.swift
//  GameEngine
//
//  The universal, engine-managed part of game state (plan §4.2, §4.5). A game's own
//  State embeds a CoreState and adds game-specific fields (trump, roles, bids); the
//  engine only ever folds CoreEffects into this. Pure value type → replay/undo for free.
//

import Foundation

public struct CoreState: Sendable, Equatable {
    /// All card containers, keyed by id.
    public var zones: [ZoneID: Zone]
    /// Cards currently face-up. Overrides a zone's default visibility for redaction —
    /// e.g. a face-up card sitting in an otherwise hidden pile (plan §4.4).
    public var faceUp: Set<CardID>
    /// Seat whose turn it currently is.
    public var currentSeat: SeatID
    /// Number of seats at the table.
    public let seatCount: Int
    /// Running score per seat (teams aggregate these — plan §4.6).
    public var scores: [SeatID: Int]
    /// In-state RNG: shuffles/deals consume it so everything is reproducible (plan §4.2).
    public var rng: SeededRNG
    /// Phase stack; top of stack is the active phase (plan §4.3). Minimal for now — a
    /// name per frame; richer phase data arrives with the phase-stack work.
    public var phases: [String]

    public init(seatCount: Int, rng: SeededRNG, currentSeat: SeatID = SeatID(0)) {
        precondition(seatCount > 0, "need at least one seat")
        self.zones = [:]
        self.faceUp = []
        self.currentSeat = currentSeat
        self.seatCount = seatCount
        self.scores = [:]
        self.rng = rng
        self.phases = []
    }

    public subscript(_ id: ZoneID) -> Zone? { zones[id] }

    /// Seats in turn order starting from `currentSeat` (wrapping). Helper for layouts/AI;
    /// dynamic turn order (Durak) will live in a dedicated TurnOrder type.
    public var seatsInTurnOrder: [SeatID] {
        (0..<seatCount).map { SeatID((currentSeat.index + $0) % seatCount) }
    }
}
