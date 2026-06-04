//
//  DurakMatch.swift
//  GameEngine
//
//  A match is a series of Durak rounds (deals). It owns the cross-round state the single-deal
//  DurakGame doesn't: who attacks first each round (lowest trump on round 1, otherwise decided by
//  the previous durak and the "teaching the durak" rule), the per-player loss tally, and the
//  loss-limit that ends the match. Pure value type, so a whole match is replayable and testable
//  headlessly.
//

import Foundation

public struct DurakMatch {
    /// Per-deal rules (throw-in, first-bout cap, …). Mutable so the UI can toggle them mid-match.
    public var rules: DurakRules
    /// Number of seats; changing it means a different match (make a new `DurakMatch`).
    public let playerCount: Int
    /// Losses that end the match for a player; 0 = unlimited (play forever).
    public var lossLimit: Int
    /// When true, the next round's first attack is aimed at the previous loser (they defend);
    /// otherwise the previous loser attacks first.
    public var teachingDurak: Bool

    public private(set) var lossCounts: [SeatID: Int] = [:]
    public private(set) var lastDurak: SeatID?
    public private(set) var roundsPlayed: Int = 0

    public init(playerCount: Int,
                rules: DurakRules = DurakRules(),
                lossLimit: Int = 0,
                teachingDurak: Bool = false) {
        precondition((2...6).contains(playerCount), "Durak supports 2–6 players")
        self.playerCount = playerCount
        self.rules = rules
        self.lossLimit = lossLimit
        self.teachingDurak = teachingDurak
    }

    /// The single-deal engine for the current rules.
    public var game: DurakGame { DurakGame(rules: rules) }

    /// Deal the next round; first mover follows the match rules.
    public func newRound(seed: UInt64) -> DurakState {
        game.setup(seatCount: playerCount, seed: seed, openingAttacker: openingAttacker())
    }

    /// Opening attacker for the next round: nil on round 1 (engine picks lowest trump / random),
    /// otherwise derived from the previous durak and the teaching rule.
    public func openingAttacker() -> SeatID? {
        guard let durak = lastDurak else { return nil }
        return teachingDurak
            ? SeatID((durak.index - 1 + playerCount) % playerCount) // loser defends → seat to their right attacks
            : durak                                                 // loser attacks first
    }

    /// Record a finished round: the lone player left holding cards takes a loss. No-op unless the
    /// state is terminal. Call exactly once per round.
    public mutating func recordRound(_ finalState: DurakState) {
        guard let outcome = game.outcome(finalState) else { return }
        roundsPlayed += 1
        if case let .winners(safe) = outcome,
           let durak = (0..<playerCount).map({ SeatID($0) }).first(where: { !safe.contains($0) }) {
            lastDurak = durak
            lossCounts[durak, default: 0] += 1
        }
    }

    public var isOver: Bool {
        lossLimit > 0 && lossCounts.values.contains { $0 >= lossLimit }
    }

    /// The player who hit the loss limit (the overall loser), if the match is over.
    public var loser: SeatID? {
        guard lossLimit > 0 else { return nil }
        return (0..<playerCount).map { SeatID($0) }.first { (lossCounts[$0] ?? 0) >= lossLimit }
    }

    public func losses(for seat: SeatID) -> Int { lossCounts[seat] ?? 0 }
}
