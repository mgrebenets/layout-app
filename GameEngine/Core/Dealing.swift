//
//  Dealing.swift
//  GameEngine
//
//  Pure dealing helpers over card IDs. Game `setup` uses these to distribute a shuffled
//  deck into hands; they emit no effects themselves (plan §8 step 1).
//

import Foundation

public enum Dealing {

    /// Round-robin deal: hand out one card at a time to each of `seats` hands until each
    /// holds `perHand`, drawing from the **end** (top) of `pile`.
    ///
    /// - Returns: a hand per seat (in seat order) plus the cards left in the pile.
    /// - Precondition: `seats > 0` and the pile holds at least `seats * perHand` cards.
    public static func roundRobin(_ pile: [CardID], seats: Int, perHand: Int) -> (hands: [[CardID]], remaining: [CardID]) {
        precondition(seats > 0, "need at least one seat")
        let total = seats * perHand
        precondition(pile.count >= total, "pile has \(pile.count) cards, need \(total)")

        var hands = Array(repeating: [CardID](), count: seats)
        var drawn = pile
        for n in 0..<total {
            hands[n % seats].append(drawn.removeLast())
        }
        return (hands, drawn)
    }
}
