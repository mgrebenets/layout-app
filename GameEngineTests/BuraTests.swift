//
//  BuraTests.swift
//  GameEngineTests
//
//  Validates Bura — the engine's first point-scoring game (plan §7). Covers setup, the beat rule,
//  single- and multi-card trick resolution (beat vs surrender), winner-first refill, the score-to-31
//  win, and an AI-vs-AI playthrough that must terminate while conserving all 36 cards and keeping the
//  running scores equal to the points actually captured.
//

import Testing
@testable import GameEngine

@Suite("Bura")
struct BuraTests {

    private let s0 = SeatID(0)
    private let s1 = SeatID(1)
    private func won(_ seat: SeatID) -> ZoneID { ZoneID("won", owner: seat) }

    private func total(_ state: BuraState) -> Int {
        state.core.zones.values.reduce(0) { $0 + $1.count }
    }

    private func points(in zone: ZoneID, _ state: BuraState) -> Int {
        (state.core[zone]?.cards ?? []).reduce(0) { $0 + BuraRules.points(state.registry.face($1).rank) }
    }

    private func fold(_ effects: [Effect<BuraEffect>], into state: inout BuraState, with game: BuraGame) {
        for effect in effects {
            switch effect {
            case let .core(coreEffect): state.core.apply(coreEffect)
            case let .game(gameEffect): game.apply(gameEffect, to: &state)
            }
        }
    }

    /// Lower a move and run `advance` to a fixpoint — what the driver does.
    private func play(_ move: BuraMove, _ state: inout BuraState, _ game: BuraGame) {
        fold(game.lower(move, in: state), into: &state, with: game)
        var guardCount = 0
        while true {
            let batch = game.advance(state)
            if batch.isEmpty { break }
            fold(batch, into: &state, with: game)
            guardCount += 1
            if guardCount > 10_000 { break }
        }
    }

    /// Build a fixed two-player state. Card indices refer to `faces`.
    private func makeState(faces: [StandardFace], hand0: [Int], hand1: [Int], deck: [Int],
                           trump: Suit, leader: SeatID = SeatID(0), scores: [SeatID: Int] = [:]) -> BuraState {
        let registry = CardRegistry(faces)
        var core = CoreState(seatCount: 2, rng: SeededRNG(seed: 0), currentSeat: leader)
        core.apply(.createZone(.deck, .hidden))
        core.apply(.createZone(.trick, .public))
        core.apply(.createZone(won(s0), .hidden))
        core.apply(.createZone(won(s1), .hidden))
        core.apply(.createZone(.hand(s0), .ownerOnly))
        core.apply(.createZone(.hand(s1), .ownerOnly))
        core.zones[.hand(s0)]?.push(contentsOf: hand0.map { CardID($0) })
        core.zones[.hand(s1)]?.push(contentsOf: hand1.map { CardID($0) })
        core.zones[.deck]?.push(contentsOf: deck.map { CardID($0) })
        for (seat, value) in scores { core.apply(.addScore(seat, value)) }
        return BuraState(core: core, registry: registry, trump: trump,
                         leader: leader, attack: [], response: [], phase: .leading)
    }

    // MARK: - Setup & rules

    @Test("Setup deals 3 each, leaves a 30-card deck with the trump face up, 120 points in play")
    func setup() {
        let state = BuraGame().setup(seatCount: 2, seed: 42)
        #expect(state.registry.count == 36)
        #expect(state.core[.hand(s0)]?.count == 3)
        #expect(state.core[.hand(s1)]?.count == 3)
        #expect(state.core[.deck]?.count == 30)
        #expect(state.core.faceUp.count == 1)                 // the trump card at the deck's bottom
        #expect(state.core[.deck]?.cards.first.map { state.core.faceUp.contains($0) } == true)
        #expect(total(state) == 36)
        let deckPoints = state.registry.order.reduce(0) { $0 + BuraRules.points(state.registry.face($1).rank) }
        #expect(deckPoints == 120)
    }

    @Test("Beat rule: the Ten outranks the King (just below the Ace); a trump beats a non-trump")
    func beats() {
        #expect(BuraGame.beats(StandardFace(.ten, .hearts), StandardFace(.king, .hearts), trump: .spades))   // 10 > K
        #expect(!BuraGame.beats(StandardFace(.king, .hearts), StandardFace(.ten, .hearts), trump: .spades))
        #expect(BuraGame.beats(StandardFace(.ace, .hearts), StandardFace(.ten, .hearts), trump: .spades))     // A > 10
        #expect(BuraGame.beats(StandardFace(.king, .hearts), StandardFace(.queen, .hearts), trump: .spades))  // K > Q
        #expect(BuraGame.beats(StandardFace(.six, .spades), StandardFace(.ace, .hearts), trump: .spades))     // trump beats
        #expect(!BuraGame.beats(StandardFace(.ace, .hearts), StandardFace(.six, .spades), trump: .spades))
        #expect(!BuraGame.beats(StandardFace(.ace, .hearts), StandardFace(.king, .clubs), trump: .spades))    // off-suit
    }

    // MARK: - Single-card tricks

    @Test("A beaten lead goes to the responder, who scores the points and leads next")
    func responderBeatsAndTakes() {
        // K♥ led, beaten by 10♥ (the Ten outranks the King in Bura). Trump spades, empty deck.
        var state = makeState(faces: [StandardFace(.king, .hearts), StandardFace(.ten, .hearts)],
                              hand0: [0], hand1: [1], deck: [], trump: .spades)
        let game = BuraGame()
        play(.lead([0]), &state, game)
        #expect(state.phase == .responding)
        #expect(state.core.currentSeat == s1)
        play(.respond([1]), &state, game)

        #expect(state.leader == s1)                       // responder won the trick
        #expect(state.core.scores[s1] == 14)              // K(4) + 10(10)
        #expect(state.core[won(s1)]?.count == 2)
        #expect(state.core[.trick]?.isEmpty == true)
        #expect(total(state) == 2)
    }

    @Test("An unbeaten lead goes to the leader, who scores and keeps the lead")
    func leaderTakesOnSurrender() {
        // 10♥ led, answered by 6♣ (off-suit non-trump) → surrender, leader takes.
        var state = makeState(faces: [StandardFace(.ten, .hearts), StandardFace(.six, .clubs)],
                              hand0: [0], hand1: [1], deck: [], trump: .spades)
        let game = BuraGame()
        play(.lead([0]), &state, game)
        play(.respond([1]), &state, game)

        #expect(state.leader == s0)
        #expect(state.core.scores[s0] == 10)
        #expect(state.core[won(s0)]?.count == 2)
    }

    // MARK: - Multi-card lead

    @Test("A two-card same-suit lead beaten by two trumps is taken by the responder")
    func multiCardLeadBeaten() {
        // Lead 10♥ + K♥ (hearts); beaten by 6♠ + 7♠ (trumps beat non-trumps).
        let faces = [StandardFace(.ten, .hearts), StandardFace(.king, .hearts),
                     StandardFace(.six, .spades), StandardFace(.seven, .spades)]
        var state = makeState(faces: faces, hand0: [0, 1], hand1: [2, 3], deck: [], trump: .spades)
        let game = BuraGame()

        #expect(game.legalMoves(for: s0, in: state).contains(.lead([0, 1])))
        play(.lead([0, 1]), &state, game)
        #expect(state.attack == [0, 1])
        play(.respond([2, 3]), &state, game)

        #expect(state.leader == s1)
        #expect(state.core[won(s1)]?.count == 4)
        #expect(state.core.scores[s1] == 14)              // 10 + 4 (the trump 6, 7 score nothing)
    }

    @Test("A multi-card lead that can't be fully beaten is a surrender to the leader")
    func multiCardLeadSurrendered() {
        // Lead 10♥ + K♥; answered by 6♣ + 7♣ (neither beats) → leader takes all four.
        let faces = [StandardFace(.ten, .hearts), StandardFace(.king, .hearts),
                     StandardFace(.six, .clubs), StandardFace(.seven, .clubs)]
        var state = makeState(faces: faces, hand0: [0, 1], hand1: [2, 3], deck: [], trump: .spades)
        let game = BuraGame()
        play(.lead([0, 1]), &state, game)
        play(.respond([2, 3]), &state, game)

        #expect(state.leader == s0)
        #expect(state.core[won(s0)]?.count == 4)
        #expect(state.core.scores[s0] == 14)              // 10 + 4 (clubs score nothing)
    }

    // MARK: - Refill

    @Test("After a trick both refill to three, the winner drawing first")
    func refillWinnerFirst() {
        // Both hold 3; a 1-card trick drops each to 2; deck has a single card → the winner reaches 3.
        let faces = [StandardFace(.six, .hearts), StandardFace(.eight, .clubs), StandardFace(.nine, .clubs),
                     StandardFace(.seven, .hearts), StandardFace(.eight, .diamonds), StandardFace(.nine, .diamonds),
                     StandardFace(.queen, .spades)]
        var state = makeState(faces: faces, hand0: [0, 1, 2], hand1: [3, 4, 5], deck: [6], trump: .spades)
        let game = BuraGame()
        play(.lead([0]), &state, game)      // 6♥
        play(.respond([3]), &state, game)   // 7♥ beats → s1 wins and draws first

        #expect(state.leader == s1)
        #expect(state.core[.hand(s1)]?.count == 3)        // winner topped back up
        #expect(state.core[.hand(s0)]?.count == 2)        // loser left short (deck ran dry)
        #expect(state.core[.hand(s1)]?.contains(CardID(6)) == true)
        #expect(state.core[.deck]?.isEmpty == true)
        #expect(total(state) == 7)
    }

    @Test("Refill draws one at a time so hands stay equal when the deck runs low")
    func refillKeepsHandsEqual() {
        // Both hold 3; a two-card trick drops each to 1; the deck has exactly 2 → each draws one and
        // both reach 2 (the old fill-winner-first logic gave the winner both, a 3-vs-1 gap).
        let faces = [StandardFace(.six, .hearts), StandardFace(.seven, .hearts), StandardFace(.nine, .clubs),
                     StandardFace(.six, .spades), StandardFace(.seven, .spades), StandardFace(.nine, .diamonds),
                     StandardFace(.eight, .clubs), StandardFace(.eight, .diamonds)]
        var state = makeState(faces: faces, hand0: [0, 1, 2], hand1: [3, 4, 5], deck: [6, 7], trump: .spades)
        let game = BuraGame()
        play(.lead([0, 1]), &state, game)      // 6♥ 7♥
        play(.respond([3, 4]), &state, game)   // 6♠ 7♠ (trumps) beat both → s1 wins, leads next

        #expect(state.leader == s1)
        #expect(state.core[.hand(s0)]?.count == 2)
        #expect(state.core[.hand(s1)]?.count == 2)   // equal — neither hogged the low deck
        #expect(state.core[.deck]?.isEmpty == true)
    }

    // MARK: - Winning

    // MARK: - Scoring & winning

    @Test("Reaching the winning score ends the game immediately, even with cards left")
    func reachingTargetWins() {
        // s0 sits on 25; capturing 10♥ (worth 10) crosses 31 although both still hold cards.
        let faces = [StandardFace(.ten, .hearts), StandardFace(.six, .clubs),
                     StandardFace(.six, .diamonds), StandardFace(.seven, .diamonds),
                     StandardFace(.eight, .diamonds), StandardFace(.nine, .diamonds)]
        var state = makeState(faces: faces, hand0: [0, 2], hand1: [1, 3], deck: [4, 5],
                              trump: .spades, scores: [s0: 25])
        let game = BuraGame(rules: BuraRules(winningScore: 31))
        play(.lead([0]), &state, game)      // 10♥, surrendered to by 6♣
        play(.respond([1]), &state, game)

        #expect(state.core.scores[s0] == 35)
        #expect(game.outcome(state) == .winner(s0))
        #expect((state.core[.deck]?.count ?? 0) > 0) // won on the threshold, not by exhausting the deck
    }

    @Test("With no threshold the deal is played out and the higher score wins")
    func playToEndHighestWins() {
        // One card each, empty deck: s0 leads A♥, s1 gives 6♣. s0 captures 11 and — with all cards
        // now gone — wins the deal.
        var state = makeState(faces: [StandardFace(.ace, .hearts), StandardFace(.six, .clubs)],
                              hand0: [0], hand1: [1], deck: [], trump: .spades)
        let game = BuraGame() // winningScore nil → play to the end
        #expect(game.outcome(state) == nil)
        play(.lead([0]), &state, game)
        play(.respond([1]), &state, game)
        #expect(state.core.scores[s0] == 11)
        #expect(game.outcome(state) == .winner(s0))
    }

    @Test("Clear counting scores only aces and tens, 10 each")
    func clearCountingCountsOnlyAcesAndTens() {
        // A♥ led, K♥ can't beat it → s0 takes A♥ + K♥. Full would be 15; clear counts only the ace.
        var state = makeState(faces: [StandardFace(.ace, .hearts), StandardFace(.king, .hearts)],
                              hand0: [0], hand1: [1], deck: [], trump: .spades)
        let game = BuraGame(rules: BuraRules(scoring: .clearOnly))
        play(.lead([0]), &state, game)
        play(.respond([1]), &state, game)
        #expect(state.core[won(s0)]?.count == 2)
        #expect(state.core.scores[s0] == 10) // A=10, K=0 under clear counting
    }

    @Test("Face-down surrender hides the conceded cards; a beat stays face up")
    func faceDownSurrenderVisibility() {
        let game = BuraGame(rules: BuraRules(faceDownSurrender: true))
        // Surrender: 10♥ led, 6♣ can't beat → dropped face down.
        var s = makeState(faces: [StandardFace(.ten, .hearts), StandardFace(.six, .clubs)],
                          hand0: [0], hand1: [1], deck: [], trump: .spades)
        fold(game.lower(.lead([0]), in: s), into: &s, with: game)
        fold(game.lower(.respond([1]), in: s), into: &s, with: game)
        #expect(s.core.faceUp.contains(CardID(0)) == true)   // the lead stays visible
        #expect(s.core.faceUp.contains(CardID(1)) == false)  // the surrendered card is hidden

        // Beat: 6♥ led, 6♠ (trump) beats → played face up even with face-down surrender on.
        var t = makeState(faces: [StandardFace(.six, .hearts), StandardFace(.six, .spades)],
                          hand0: [0], hand1: [1], deck: [], trump: .spades)
        fold(game.lower(.lead([0]), in: t), into: &t, with: game)
        fold(game.lower(.respond([1]), in: t), into: &t, with: game)
        #expect(t.core.faceUp.contains(CardID(1)) == true)   // the beating card is visible
    }

    // MARK: - Combos

    @Test("Lead-first combos: three of one suit (bura or molodka), or three aces incl. the trump ace")
    func leadCombos() {
        let trump = Suit.spades
        #expect(BuraGame.isLeadCombo([StandardFace(.six, .hearts), StandardFace(.nine, .hearts), StandardFace(.king, .hearts)], trump: trump)) // molodka (non-trump)
        #expect(BuraGame.isLeadCombo([StandardFace(.six, .spades), StandardFace(.nine, .spades), StandardFace(.king, .spades)], trump: trump)) // bura (three trumps)
        #expect(BuraGame.isLeadCombo([StandardFace(.ace, .hearts), StandardFace(.ace, .clubs), StandardFace(.ace, .spades)], trump: trump))   // three aces incl. trump ace
        #expect(!BuraGame.isLeadCombo([StandardFace(.ace, .hearts), StandardFace(.ace, .clubs), StandardFace(.ace, .diamonds)], trump: trump)) // no trump ace
        #expect(!BuraGame.isLeadCombo([StandardFace(.six, .hearts), StandardFace(.nine, .hearts), StandardFace(.king, .clubs)], trump: trump))  // mixed suits
    }

    @Test("Three trumps lead-first is not a win: three low trumps can be beaten by three higher trumps")
    func buraIsNotAutoWin() {
        // s0 leads its three low trumps; s1 beats every one with higher trumps and takes the trick.
        let faces = [StandardFace(.six, .spades), StandardFace(.seven, .spades), StandardFace(.eight, .spades),
                     StandardFace(.king, .spades), StandardFace(.ten, .spades), StandardFace(.ace, .spades)]
        var state = makeState(faces: faces, hand0: [0, 1, 2], hand1: [3, 4, 5], deck: [], trump: .spades)
        let game = BuraGame()
        #expect(game.outcome(state) == nil) // holding three trumps is not, by itself, a win
        play(.lead([0, 1, 2]), &state, game)
        play(.respond([3, 4, 5]), &state, game)
        #expect(state.leader == s1)              // the higher trumps beat the bura
        #expect(state.core[won(s1)]?.count == 6)
    }

    @Test("The non-leader holding bura is offered the lead; claiming takes it, declining keeps it")
    func buraClaimOffer() {
        // Trump spades. s0 leads but holds no trumps; s1 (the non-leader) holds three trumps.
        let faces = [StandardFace(.six, .hearts), StandardFace(.seven, .hearts), StandardFace(.eight, .hearts),
                     StandardFace(.six, .spades), StandardFace(.seven, .spades), StandardFace(.eight, .spades)]
        func fresh() -> BuraState { makeState(faces: faces, hand0: [0, 1, 2], hand1: [3, 4, 5], deck: [], trump: .spades, leader: s0) }
        let game = BuraGame()

        var offered = fresh()
        fold(game.advance(offered), into: &offered, with: game) // advance offers s1 the claim
        #expect(offered.phase == .buraOffer)
        #expect(offered.core.currentSeat == s1)
        #expect(game.legalMoves(for: s1, in: offered) == [.claimBura, .declineBura])

        var claimed = offered
        play(.claimBura, &claimed, game)
        #expect(claimed.leader == s1)            // claimant takes the lead out of turn
        #expect(claimed.phase == .leading)
        #expect(claimed.core.currentSeat == s1)

        var declined = offered
        play(.declineBura, &declined, game)
        #expect(declined.leader == s0)           // natural leader keeps the lead
        #expect(declined.phase == .leading)
        #expect(declined.core.currentSeat == s0)
    }

    @Test("With the leader holding bura, no claim is offered (attacker-first priority)")
    func buraLeaderKeepsLead() {
        // s0 leads AND holds the three trumps; s1 has none → no offer, s0 simply leads.
        let faces = [StandardFace(.six, .spades), StandardFace(.seven, .spades), StandardFace(.eight, .spades),
                     StandardFace(.six, .hearts), StandardFace(.seven, .hearts), StandardFace(.eight, .hearts)]
        var state = makeState(faces: faces, hand0: [0, 1, 2], hand1: [3, 4, 5], deck: [], trump: .spades, leader: s0)
        let game = BuraGame()
        fold(game.advance(state), into: &state, with: game)
        #expect(state.phase == .leading)         // no bura offer raised
    }

    @Test("beatAssignment pairs answers with the cards they beat, and is nil on a surrender")
    func beatAssignmentPairs() {
        let faces = [StandardFace(.ten, .hearts), StandardFace(.king, .hearts),
                     StandardFace(.six, .spades), StandardFace(.seven, .spades),
                     StandardFace(.six, .clubs), StandardFace(.seven, .clubs)]
        let state = makeState(faces: faces, hand0: [], hand1: [], deck: [], trump: .spades)
        let game = BuraGame()
        #expect(game.beatAssignment([CardID(2), CardID(3)], [CardID(0), CardID(1)], in: state) != nil) // 2 trumps beat 2 hearts
        #expect(game.beatAssignment([CardID(4), CardID(5)], [CardID(0), CardID(1)], in: state) == nil)  // clubs can't beat hearts
    }

    // MARK: - Playthrough

    @Test("AI vs AI playthrough terminates with an outcome, conserving 36 cards and scoring honestly")
    func aiPlaythrough() {
        let game = BuraGame()
        let ai = BuraAI()
        for seed: UInt64 in [0xB00B, 1, 7, 42, 0xC0FFEE] {
            var driver = GameDriver(game, seatCount: 2, seed: seed)
            var moves = 0
            while driver.outcome == nil, moves < 100_000 {
                let seat = driver.currentSeat
                guard let move = ai.move(for: seat, in: driver.state, game: game) else { break }
                driver.apply(move)
                moves += 1
                #expect(total(driver.state) == 36)
                // Scores always equal the points sitting in the won piles.
                let captured = points(in: won(s0), driver.state) + points(in: won(s1), driver.state)
                let scored = driver.state.core.scores[s0, default: 0] + driver.state.core.scores[s1, default: 0]
                #expect(captured == scored)
            }
            #expect(driver.outcome != nil)
        }
    }
}
