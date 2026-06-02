//
//  FoundationsTests.swift
//  GameEngineTests
//
//  Step 1 (Foundations) coverage: RNG determinism, deck builders, registry identity,
//  comparators, zone semantics, dealing.
//

import Testing
@testable import GameEngine

@Suite("Foundations")
struct FoundationsTests {

    // MARK: SeededRNG

    @Test("Same seed produces the same sequence")
    func rngDeterministic() {
        var a = SeededRNG(seed: 42)
        var b = SeededRNG(seed: 42)
        let seqA = (0..<8).map { _ in a.next() }
        let seqB = (0..<8).map { _ in b.next() }
        #expect(seqA == seqB)
    }

    @Test("Different seeds diverge")
    func rngDiffersBySeed() {
        var a = SeededRNG(seed: 1)
        var b = SeededRNG(seed: 2)
        let first = a.next()
        let second = b.next()
        #expect(first != second)
    }

    @Test("Shuffle is reproducible from the seed")
    func shuffleReproducible() {
        let deck = StandardDeck.standard52
        let registry = CardRegistry(deck)
        var r1 = SeededRNG(seed: 99)
        var r2 = SeededRNG(seed: 99)
        let shuffleA = registry.shuffled(using: &r1)
        let shuffleB = registry.shuffled(using: &r2)
        #expect(shuffleA == shuffleB)
    }

    // MARK: Deck builders

    @Test("Standard 52 deck is complete and unique")
    func standard52() {
        let deck = StandardDeck.standard52
        #expect(deck.count == 52)
        #expect(Set(deck).count == 52)
    }

    @Test("Stripped/short presets have the right sizes")
    func strippedSizes() {
        #expect(StandardDeck.stripped36.count == 36) // 9 ranks × 4
        #expect(StandardDeck.piquet32.count == 32)   // 8 ranks × 4
        #expect(StandardDeck.short24.count == 24)    // 6 ranks × 4
    }

    @Test("Copies multiply the deck (Canasta-style two decks)")
    func copies() {
        let two = StandardDeck.make(ranks: Rank.allCases, copies: 2)
        #expect(two.count == 104)
        #expect(Set(two).count == 52) // faces repeat; identity comes from the registry
    }

    // MARK: CardRegistry

    @Test("Registry assigns sequential IDs and round-trips faces")
    func registryIdentity() {
        let deck = StandardDeck.standard52
        let registry = CardRegistry(deck)
        #expect(registry.count == 52)
        #expect(registry.order == (0..<52).map { CardID($0) })
        #expect(registry.face(0) == deck[0])
        #expect(registry.face(CardID(51)) == deck[51])
    }

    @Test("Duplicate faces get distinct IDs")
    func registryDistinguishesCopies() {
        let registry = CardRegistry(StandardDeck.make(ranks: [.ace], suits: [.spades], copies: 2))
        #expect(registry.count == 2)
        #expect(registry.face(0) == registry.face(1)) // same face
        #expect(CardID(0) != CardID(1))               // different identity
    }

    // MARK: Comparators

    @Test("Ace-high vs ace-low ordering via explicit rank order")
    func comparatorAceOrder() {
        let aceHigh = FaceComparator.byRank(Rank.allCases)
        let aceLow = FaceComparator.byRank([.ace] + Rank.allCases.filter { $0 != .ace })
        let ace = StandardFace(.ace, .spades)
        let king = StandardFace(.king, .spades)
        #expect(aceHigh(king, ace))  // king < ace when ace is high
        #expect(aceLow(ace, king))   // ace < king when ace is low
    }

    @Test("Sort card IDs by face through the registry")
    func sortIDs() {
        let registry = CardRegistry([StandardFace(.king, .spades), StandardFace(.two, .spades), StandardFace(.ace, .spades)])
        let sorted = FaceComparator.sort(registry.order, in: registry, by: FaceComparator.byRank())
        #expect(sorted.map { registry.face($0).rank } == [.two, .king, .ace])
    }

    // MARK: Zone

    @Test("Zone push/pop treats the last card as the top")
    func zoneTopSemantics() {
        var zone = Zone(id: .deck, visibility: .hidden)
        zone.push(contentsOf: [CardID(1), CardID(2), CardID(3)])
        #expect(zone.top == CardID(3))
        let popped = zone.popTop()
        #expect(popped == CardID(3))
        #expect(zone.count == 2)
    }

    @Test("Zone removes a specific card and reports presence")
    func zoneRemove() {
        var zone = Zone(id: .trick, visibility: .public, cards: [CardID(1), CardID(2), CardID(3)])
        let removedExisting = zone.remove(CardID(2))
        #expect(removedExisting)
        #expect(!zone.contains(CardID(2)))
        let removedMissing = zone.remove(CardID(99))
        #expect(!removedMissing)
        let drained = zone.removeAll()
        #expect(drained == [CardID(1), CardID(3)])
        #expect(zone.isEmpty)
    }

    // MARK: Dealing

    @Test("Round-robin deals the right counts and leaves a stock")
    func dealRoundRobin() {
        let registry = CardRegistry(StandardDeck.stripped36)
        var rng = SeededRNG(seed: 7)
        let shuffled = registry.shuffled(using: &rng)
        let (hands, remaining) = Dealing.roundRobin(shuffled, seats: 2, perHand: 6)
        #expect(hands.count == 2)
        #expect(hands.allSatisfy { $0.count == 6 })
        #expect(remaining.count == 36 - 12)
        // Every dealt/remaining card is accounted for exactly once.
        let all = hands.flatMap { $0 } + remaining
        #expect(Set(all).count == 36)
    }
}
