//
//  SeededRNG.swift
//  GameEngine
//
//  Deterministic, value-type RNG. Lives inside game state so shuffles/deals are pure
//  and reproducible from (seed + effect log) — the basis for replay, tests, and netcode
//  (plan §4.2). Fixes the prior kartoteka-utility non-determinism.
//

import Foundation

/// A reproducible `RandomNumberGenerator` (SplitMix64). Same seed → same sequence,
/// on every platform and run. Codable so it can be persisted as part of the state.
public struct SeededRNG: RandomNumberGenerator, Codable, Sendable, Equatable {
    private var state: UInt64

    public init(seed: UInt64) {
        self.state = seed
    }

    public mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}
