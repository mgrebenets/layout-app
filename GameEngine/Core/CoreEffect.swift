//
//  CoreEffect.swift
//  GameEngine
//
//  The universal effect vocabulary (plan §4.1, §10). These are the primitive, self-
//  contained events the engine folds into CoreState — simultaneously the animation
//  script, the network packet, and the replay log. Game-specific changes (trump, roles)
//  are carried by a separate per-game effect type, folded by the game.
//

import Foundation

public enum CoreEffect: Sendable, Equatable {
    /// Create an (empty) zone with a default visibility.
    case createZone(ZoneID, Visibility)
    /// Move a card from one zone to another (to the top of the destination).
    case move(CardID, from: ZoneID, to: ZoneID)
    /// Move a card to the **bottom** of the destination (War winnings, returning to a draw pile).
    case moveToBottom(CardID, from: ZoneID, to: ZoneID)
    /// Shuffle a zone's cards using the in-state RNG (e.g. reshuffling captured cards, or a discard
    /// back into the deck). Reproducible from the seed.
    case shuffle(ZoneID)
    /// Reveal or hide a specific card (independent of its zone's default visibility).
    case setFaceUp(CardID, Bool)
    /// Set whose turn it is.
    case setTurn(SeatID)
    /// Add (or subtract) points for a seat.
    case addScore(SeatID, Int)
    /// Push a new phase frame.
    case pushPhase(String)
    /// Pop the current phase frame.
    case popPhase
}
