//
//  FaceComparator.swift
//  GameEngine
//
//  Reusable sort/compare primitives for common faces (plan §5). Games and the renderer
//  consume these instead of reimplementing ordering. Rank order is data: pass an explicit
//  order array when ace-low (or any custom order) is needed.
//

import Foundation

public enum FaceComparator {

    /// Order by rank using an explicit rank order (index in `order` = position), ties
    /// broken by suit. Use `Rank.allCases` for ace-high, or a custom array for ace-low.
    public static func byRank(
        _ order: [Rank] = Rank.allCases,
        suitOrder: [Suit] = Suit.allCases
    ) -> (StandardFace, StandardFace) -> Bool {
        let rankPos = positions(order)
        let suitPos = positions(suitOrder)
        return { a, b in
            let ra = rankPos[a.rank, default: order.count]
            let rb = rankPos[b.rank, default: order.count]
            if ra != rb { return ra < rb }
            return suitPos[a.suit, default: suitOrder.count] < suitPos[b.suit, default: suitOrder.count]
        }
    }

    /// Group by suit first (as in a fanned hand), then by rank within each suit.
    public static func bySuitThenRank(
        suitOrder: [Suit] = Suit.allCases,
        rankOrder: [Rank] = Rank.allCases
    ) -> (StandardFace, StandardFace) -> Bool {
        let suitPos = positions(suitOrder)
        let rankPos = positions(rankOrder)
        return { a, b in
            let sa = suitPos[a.suit, default: suitOrder.count]
            let sb = suitPos[b.suit, default: suitOrder.count]
            if sa != sb { return sa < sb }
            return rankPos[a.rank, default: rankOrder.count] < rankPos[b.rank, default: rankOrder.count]
        }
    }

    /// Sort card IDs by their faces, looking each up in the registry. Handy for the
    /// renderer (e.g. ordering a hand for display) without duplicating sort logic.
    public static func sort(
        _ ids: [CardID],
        in registry: CardRegistry<StandardFace>,
        by areInIncreasingOrder: (StandardFace, StandardFace) -> Bool
    ) -> [CardID] {
        ids.sorted { areInIncreasingOrder(registry.face($0), registry.face($1)) }
    }

    private static func positions<T: Hashable>(_ items: [T]) -> [T: Int] {
        Dictionary(uniqueKeysWithValues: items.enumerated().map { ($1, $0) })
    }
}
