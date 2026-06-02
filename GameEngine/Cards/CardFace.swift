//
//  CardFace.swift
//  GameEngine
//
//  The face of a card is opaque to the engine and typed by each game (plan §4.7).
//  Standard games use `StandardFace`; Uno would define `{color, kind}`, Tarot
//  `{suit?, trumpNumber?}`, etc. — none of which the Core layer ever interprets.
//

import Foundation

/// Marker for a game's card-face type. Hashable/Codable/Sendable so faces can be stored
/// in a registry, encoded in an effect log, and shared across actors.
public protocol CardFace: Hashable, Codable, Sendable {}
