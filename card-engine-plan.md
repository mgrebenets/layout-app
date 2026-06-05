# Card Engine — Design Plan

A universal engine for **turn-based card games**, plus a thin per-game layer. Goal: implement
many structurally-different games (War, Durak, Preference, 1000, Bura, Hearts, Uno, Canasta,
Go Fish, Poker, Trinka, …) on one shared skeleton without forcing them into a single rule format.

> Status: design. Nothing implemented yet. This doc is the spec the implementation works against.

---

## 1. Guiding principle

> **Universal skeleton + declarative data + per-game logic.**

- The **skeleton** (phase/turn state machine, state container, move log, RNG, player views) is
  100% shared and contains 0% of any game's rules.
- **Data** describes the genuinely tabular parts: deck composition, rank/trump ordering, scoring
  tables, player counts, config flags.
- **Logic** (the move vocabulary + legal-move generation + apply + flow) is delegated to each game.

We explicitly reject a fully-declarative "universal rule format." It works for War and collapses at
poker side-pots and Durak's dynamic attack/defense. A format rich enough to express those *is* a
programming language. Prior art proves this (see §3): the previous engine's single `Move` type was
Durak/Bura-shaped and could not express a poker raise, a Go Fish request, or a Canasta meld.

Out of scope: real-time games (Spit, Speed, Egyptian Ratscrew) — no turn structure.

---

## 2. Prior art in `../` and reuse decisions

| Project | What it is | Decision |
|---|---|---|
| **kartoteka-reloaded** | Real engine attempt: enum state machine (`InitGame→StartRound→StartTurn→DealCards→MakeMove→ApplyMove→EndTurn→EndRound→EndGame`), `GameStateRunner`, `Game`+`Rules`/`BuraRules`/`DruncardRules`, `Move`+`CardPair`, `Card`(NSCoding,`Ownable`), `BoxedCardArray`/`SlotCollection`. Implements **Bura**, **Druncard**. | **Reuse the ideas:** state-machine phases, rules hierarchy, human/AI player polymorphism. **Rewrite:** no NSCoding (→ Codable), no SpriteKit in model, generalize `Move`, add seeded RNG + undo + network. |
| **kartoteka-neo** | Layout/visualization prototype (ancestor of `layout-app`). No rules. | Not an engine. UI reference only. |
| **kartoteka-playingcard** | `PlayingCard`/`Rank`/`Suite`, localized, `Comparable`. | Clean but hardcoded 13×4 — **generalize** for jokers/wilds/custom ranks. |
| **kartoteka-deck** | `typealias Deck=[PlayingCard]`, 52/36 factories, `makeDeck(ranks:suites:)`, grouping. | Replace alias with a real `Deck`/`DeckSpec`; add multi-deck, special cards, dealing. |
| **kartoteka-utility** | Fisher–Yates shuffle, random draw. | Keep algorithm; **inject `RandomNumberGenerator`** for determinism. |

**Key lesson:** the skeleton generalized across games; the move/rules layer did not. The engine
boundary must put the move vocabulary on the *game* side.

---

## 3. Taxonomy — what the engine must cover

Games grouped by mechanic (the only axis that matters for an engine). Representative games and the
wrinkle each family forces on the engine:

1. **Trick-taking** — one card per player into a trick; comparison rule picks winner.
   - Plain-trick: Whist, Spades, Bridge · Point-trick: **Preference, 1000, Belote, Skat** ·
     Avoidance: **Hearts**. Wrinkles: follow-suit obligation, trump (fixed/bid/bottom),
     **auction phase**, in-play declarations (1000 marriages).
2. **Capturing / multi-card trick** — **Bura**, Briscola. Throw several cards, must capture;
     trump from bottom card; per-card point values; combos.
3. **Beat-or-take (attack/defense shedding)** — **Durak**. Dynamic attacker/defender **roles**,
     variable-length exchanges, last holder loses, randomizable turn order.
4. **Shedding / matching** — **Uno**, Crazy Eights, Mau-Mau. Match rank/suit/color; **action cards**
     mutate flow & direction; **non-standard deck**.
5. **Rummy / melding** — Gin, **Canasta** (2 decks + jokers, partnerships, wild 2s, frozen pile),
     Phase 10. Persistent table melds as owned/shared zones.
6. **Fishing / requesting** — **Go Fish** (ask for a rank → deduction), Scopa/Cassino (capture from table).
7. **Vying / betting** — **Poker, Trinka/Teen Patti**, Brag. Chips, betting rounds as a sub-machine,
     side pots, hand-ranking evaluator, hidden hole cards. Banking sub-type: **Blackjack** (dealer role).
8. **Comparing (no decisions)** — **War**. Degenerate trick: forced/simultaneous moves.
9. **Patience / Solitaire** — Klondike, **Druncard**. 1 player, rich table zones.

### The seven axes of variation (= what rules must parameterize or delegate)

| Axis | Cheap end | Expensive end (drives design) |
|---|---|---|
| **Zones** | hand, deck, discard | trick area, per-player **melds**, shared table, **pot/chips**, foundations |
| **Turn order** | fixed clockwise | **dynamic roles** (Durak), reversible (Uno), simultaneous (War), bid order ≠ play order |
| **Phases/round** | deal → play | deal → **auction** → play → score; deal → **betting rounds** → showdown |
| **Move vocabulary** | play one card | bid/pass, bet/raise/call/fold, **ask-for-rank**, declare-meld, beat-card, choose-wild, knock |
| **Comparison** | rank order | trump, **follow-suit**, beats-relation, **poker evaluator**, meld validity |
| **Win/scoring** | most tricks | card-points, **avoid** (Hearts), empty-hand first/last, melds, best hand, **race to N**, partnerships |
| **Deck** | standard 52 | 36/32/24 stripped, **multi-deck**, **jokers/wilds**, **custom action cards** |

---

## 4. Architecture

### 4.1 The core: lower moves to effects, fold effects to state

Two pure functions form the heart:

```swift
func lower(_ move: Move, in state: State) -> [Effect]        // per-game: intent -> primitives
func applyEffect(_ state: State, _ effect: Effect) -> State  // engine: fold one effect
```

A `Move` is validated, *lowered* into a sequence of `Effect`s, and those effects fold into the next
state. The effect stream is canonical (see §4.2) — simultaneously the animation script, the network
packet, and the replay log. Purity buys replay, undo, deterministic tests, and netcode for free.

### 4.2 State = fold of effects (event sourcing)

```
State == effects.reduce(empty, applyEffect)
Move (player intent) --lower--> [Effect] (canonical, self-contained events)
```

- **Effects are the single source of truth.** `applyEffect` is **engine-owned and game-agnostic** for
  the universal effect vocabulary (move card between zones, flip, collect, advance turn, adjust score),
  so games stop hand-writing state mutations — they only *lower* moves into effects.
- Effects are grouped by the move that produced them (a transaction): **undo** = truncate to the last
  move boundary and re-fold; **replay/tests** = re-fold the log; **network/spectate** = ship effects,
  a client needs only an interpreter, not the rules.
- **Seeded RNG lives in the state.** Shuffle/deal consume the state's RNG and emit deal effects, so
  everything is reproducible from (seed + effect log). Fixes prior kartoteka non-determinism.
- **Hidden info**: the authoritative log holds full effects (with identity); each player receives a
  `playerView`-redacted projection (face-down deal → "a card moved"; later `reveal` effect carries the
  identity on flip).

### 4.3 Phase stack + opt-in scaffolding (decided)

`Game → Round → Phase → Turn` is the mental model, but the engine does **not** hardcode those four
levels (War has no phase; poker nests betting rounds inside a hand). The core is a **phase stack**
driven by the game's `advance(after:)`, which emits push/pop/replace phase effects. On top, the engine
ships reusable, tested helpers games opt into:

- **`TurnOrder`** — clockwise / dynamic-role (Durak) / reversible (Uno) / simultaneous-commit (the
  `CommitPhase` from §10). **Lives in the state**, so reversals and role-swaps are ordinary effects and
  replay stays exact. Replaces the prior art's fragile `turnPlayerIdx`/`eldestIdx`/`trickTakerIdx`.
- **`bestOfN`** round counter.

`Round`/`Turn` are thus conventions composed from helpers, not mandatory engine levels. The prior
`GameState` enum is the degenerate single-level case.

### 4.4 Player views (hidden information)

Card games hide information (opponents' hands, stock order, hole cards). The engine filters full
state → per-player view. Required for both networking and AI. Designed in from the start, not bolted on.

### 4.5 Zones

A `Zone` is a typed, owned, visibility-tagged card container. Generalizes the prior
`CardCollection`/`SlotCollection`. Examples: `hand(player)`, `deck`, `discard`, `trick`,
`meld(player, id)`, `table`, `pot`, `foundation(id)`. Visibility: `public`, `owner-only`, `hidden`.

### 4.6 Teams & control (decided)

- **Teams** are an optional grouping over seats in state; default = each player is a singleton team
  (War / 1v1 Durak / Hearts / Go Fish pay nothing for it). `TurnOrder` and scoring consult the grouping:
  turns alternate across teams, points/tricks aggregate per team, win is per team.
- **Controller ≠ seat.** The active *party* for a turn may be a **team**, and a per-game **control
  policy** decides which member actually acts and from which hand. This covers **team Durak** (the team
  chooses which teammate plays) and subsumes the deferred **Bridge dummy** (declarer controls partner's
  hand). One concept, not two special cases.
- **Betting / pots** (blinds, bet/call/raise/fold, all-in side pots) is a **reusable vying-family
  module**, not engine core — shared by Poker / Trinka / Brag. Blackjack banking is a separate component.

### 4.7 Card model (decided)

A `Card` is an **identified token with an opaque, game-defined face**:

```swift
struct Card { let id: CardID; var isFaceUp: Bool; let face: FaceData }
```

The engine moves/flips/collects cards **by ID and never interprets `face`**; only game logic
(`legalMoves`, `lower`, `score`, comparison) reads it. Standard games store `{rank, suit}`, Uno
`{color, kind}`, Tarot `{suit?, trumpNumber?}` — so non-standard decks need no engine changes and no
generics infect `State`/`Zone`/`Effect`. **`DeckSpec`** is open/composable from ranks/suits/specials +
`copies`, with named presets (`standard52`, `stripped36`, `uno`, `tarot`). Reusable **sort/compare
primitives** for common faces (rank×suit orderings) ship as opt-in components so games and the renderer
don't reimplement sorting.

---

## 5. The engine / game boundary

### 5.1 Per-game protocol (the logic that must be code)

```swift
protocol Game {
    associatedtype State: GameState
    associatedtype Move: Codable

    static var spec: GameSpec { get }                          // declarative config (see §6)

    func setup(players: Int, rng: inout RNG) -> [Effect]       // emits deal/assign effects
    func legalMoves(for player: PlayerID, in state: State) -> [Move]
    func lower(_ move: Move, in state: State) -> [Effect]      // intent -> primitive effects
    func advance(after state: State) -> [Effect]               // phase/turn/round transitions, as effects
    func playerView(of state: State, for player: PlayerID) -> State
    func outcome(of state: State) -> Outcome?                  // nil until game over
}
```

The engine owns `applyEffect(state, effect) -> state` for the universal effect vocabulary; games only
*lower* moves into effects (and may define game-specific effects folded by the game).

`legalMoves` is the workhorse: it feeds the **UI** (what's playable), the **validator** (reject
illegal moves), and the **AI** (search space) from one definition.

**`Move` is a per-game enum**, deliberately not a shared struct — this is the fix for prior art's
ceiling. Examples:

```swift
enum HeartsMove   { case play(Card); case pass([Card]) }
enum DurakMove    { case attack([Card]); case defend(against: Card, with: Card); case take; case done }
enum UnoMove      { case play(Card, chosenColor: Color?); case draw; case pass }
enum PokerMove    { case fold; case check; case call; case bet(Int); case raise(to: Int) }
enum GoFishMove   { case ask(player: PlayerID, rank: Rank) }
enum CanastaMove  { case draw(fromDiscard: Bool); case meld([Card]); case layOff(Card, onto: MeldID); case discard(Card) }
```

### 5.2 Players

`Player` protocol with implementations: `HumanPlayer` (awaits UI input), `AIPlayer`
(searches `legalMoves`), `NetworkPlayer` (awaits remote move). Mirrors the prior human/AI split but
move-driven and cancellable.

---

## 6. Declarative rule data (`GameSpec`)

The data layer — richer than the prior `makeDeck(ranks:suites:)`:

```swift
struct GameSpec {
    var players: ClosedRange<Int>
    var deck: DeckSpec
    var ranking: RankingSpec
    var teams: TeamSpec?           // partnerships (Bridge, Canasta, Belote)
    var scoring: ScoreTable?       // lookup tables only (card→points, event→points, targets)
    var options: [String: Value]   // variant toggles
}

struct DeckSpec {                  // must cover all of §3's "expensive end"
    var copies: Int                // 1, or 2 for Canasta
    var ranks: [RankSpec]          // standard, stripped 36/32/24, or fully custom
    var suits: [SuitSpec]
    var specials: [SpecialCard]    // jokers, wilds, Uno action cards
}

struct RankingSpec {               // comparison data, not logic
    var order: [Rank]              // game-specific rank order
    var trump: TrumpRule           // none | fixed(Suit) | bottomCard | bidWinner
    var followSuit: Bool
}
```

`ScoreTable` holds **lookup data only** (card→points, event→points, thresholds). **Scoring logic is a
per-game `score(state) -> [Party: Int]`** that consults the table and emits score effects — conditional
cases (Hearts' shooting the moon, Preference's pool/undertrick penalties) are code, not data. Poker
**hand evaluators** and rummy/canasta **meld validators**, plus the **betting module** (§4.6), are
**reusable code components** — pure functions shared across games in a family, not engine core and not
per-game duplicated.

---

## 7. Acceptance tests (validate the abstraction)

Implement one game from each structurally-distinct family. If all compile against an **unchanged**
engine, the design holds. Wherever a game has to fight the protocol, that's a design smell to feed back.

| Game | Family | Stresses |
|---|---|---|
| **War** | comparing | forced/simultaneous moves, auto-play |
| **Hearts** | trick / avoidance | follow-suit, passing phase, avoid-scoring |
| **Durak** | beat-or-take | dynamic roles, variable-length phase, empty-hand win |
| **Uno** | shedding | custom deck, action cards, reversible turn order |
| **Go Fish** | fishing | request moves, hidden hands, set collection |
| **Poker** (Hold'em) | vying | betting sub-machine, chips, side pots, hand eval, hidden cards |
| **Canasta** *(stretch)* | rummy | multi-deck, wilds, partnerships, persistent melds |
| **Preference / 1000** *(stretch)* | point-trick + auction | bidding phase, contract, tabular scoring, declarations |

---

## 8. Build sequence

1. **Foundations** ✅ — `Card` (identified token + opaque face, §4.7), `DeckSpec` + presets + dealing,
   seeded `RNG`, `Zone`, sort/compare primitives. (`Identifiers`, `SeededRNG`, `Zone`, `Dealing`,
   `Rank`/`Suit`/`StandardFace`/`CardFace`/`StandardDeck`/`CardRegistry`/`FaceComparator`.)
2. **Engine core** ✅ — `CoreState`, `CoreEffect`, engine-owned fold (`apply`), plus the generic
   layer: `GameEffect`/`Effect<Payload>`/`GameState`/`Outcome`. `TurnOrder`-in-state, `CommitPhase`,
   teams grouping, `playerView` + `redact` still to enrich (currently minimal: `currentSeat`, phase
   stack as `[String]`).
3. **`Game` protocol + driver loop** ✅ — `Game` (setup/legalMoves/lower/apply/advance/outcome) and
   `GameDriver` (lower → fold → advance-to-fixpoint → fold). Concurrency model TBD.
4. **War** ✅ — end-to-end game proving the loop. Real rules now: captures return to the **bottom**
   of the winner's stock; a tie triggers a proper **war** (lay N face-down + 1 face-up, repeat on
   re-tie). **Configurable, on the fly** via `WarRules` (face-down count 1–3, fixed vs shuffled
   winnings) — the scene rebuilds its `WarGame` with new rules between moves. `advance` does one beat
   per call so wars are watchable. **Playable in-app**: a `War` scenario on the landing page →
   `WarScene` (`LayoutApp macOS/WarScene.swift`); rule pills at the top edit rules live; each played
   pile renders through an **`SKCollectionNode`** horizontal `StackLayout` so war cards fan out.
   New universal effects added for this: `moveToBottom` and `shuffle` (§4.1).
5. **Hearts, Durak, Uno, Go Fish, Poker** — one per family (the acceptance set). *Parallelizable.*
   - **Durak** ✅ — **2–6 players** (podkidnoy / throw-in). First game with **player decisions** and
     **game-specific effects** (`DurakEffect`: roles, trump, table pairs, passes, eliminations) folded
     via the `.game(...)` arm; card moves stay universal. Dynamic attacker/defender roles + co-attacker
     **throw-in cycle** driven by `advance` (offer → auto-pass → bita/scoop), trump beating, take/pass,
     draw-up, elimination, durak detection. Configurable rules: throw-in on/off, throw-in-on-take,
     **priority (principal-first ↔ round-robin)**, first-bout ≤5. A reusable **`DurakMatch`** (engine)
     wraps a series of rounds: first-mover logic (lowest trump → random; later rounds from the previous
     loser + **teaching-the-durak**), per-player loss tally, and loss-limit (1–5 or unlimited). Engine +
     `DurakAI` + tests: AI playthroughs 2–6 players + round-robin (terminate, conserve 36), throw-in-on-take,
     first-bout cap, and a headless match-to-loss-limit. **Playable in-app**: `DurakScene` (up to 4) —
     AI opponents with role badges + loss tallies, two rows of live rule/match pills.
     - **Rendering (Stage A)** ✅ — a reusable, game-agnostic **card library in LayoutKit**: durable
       `CardNode` (one per card ID — body + centre/corner pips, with a bottom-right upside-down pip)
       and `CardTableNode`, which animates every card to a target `CardPlacement` (move/rotate/flip),
       so deals/attacks/defends/sweeps are watchable; input is locked until the beat settles. Layering
       uses a per-node z **band** (SpriteKit z is additive down the hierarchy, so children keep *small*
       offsets) — guarded by a pixel `CardOcclusionTests` (a front card must hide the back card's pips).
     - **Input UX (Stage B1)** ✅ — **click-to-select with legal-move highlighting**: legal cards are
       outlined teal (`legalMoves`), clicking one **lifts** it (yellow outline) as a candidate, and a
       second click or a **Play** button commits — clicking elsewhere cancels. Selection/highlight live
       on `CardPlacement`/`CardNode` (`setHighlighted`/`setSelected`), pixel-tested by `CardDecorationTests`.
       **Revisit (feedback):** drop the standing legal-move highlight (too much hand-holding for players who
       know the rules); single-card play should be **one gesture** (double-click or drag), not pick-then-confirm;
       reserve click-to-pop selection for **multi-card** attacks (B2). Drive any highlight only reactively (e.g. drop
       targets while dragging). Not yet actioned — revisit before further input work.
       Next: **B2** multi-select → atomic same-rank attacks (needs an `attack([CardID])` engine move);
       **B3** drag-and-drop with highlighted drop targets (lean on `NodeCoordinator`).
     Roles still live in game
     state (a shared `TurnOrder` component can be extracted once a second role-based game needs it).
6. **Reusable family components** — poker hand evaluator, meld validator, betting/pot module, score tables.
7. **Stretch games** — Canasta, Preference/1000, Bura (port from reloaded).
   - **Bura** ✅ — 2-player trump trick-taking on `stripped36`, the engine's **first point-scoring game**
     and first **multi-card move**: the leader plays **1–3 same-suit cards** (`lead([CardID])`), the
     responder must **beat every one** (perfect matching via `beatsAll`) or surrenders the same count
     (`respond([CardID])`). Rank strength is the **Ace-Ten order** — 6 7 8 9 J Q K **10 A** (the Ten sits
     just below the Ace, above the King). `lower` places the cards; `advance` resolves the completed trick
     — sweep to the winner's hidden won pile, `addScore` the captured points, hand them the lead — then
     refills **one card at a time, alternating** (winner first, then clockwise) so the two hands stay equal
     as the deck runs out (only the last card — the face-up trump at the bottom — can leave a one-card gap).
     - **Scoring (configurable via `BuraRules`)**: counting is **full** (A=11, 10=10, K=4, Q=3, J=2; 120
       total) or **clear** (aces & tens only, 10 each; 80 total). `winningScore` is optional — `nil` plays
       the deal out and the **higher final score wins** (default); a value (e.g. 31) ends the deal the
       instant it's reached. Surrendered cards may be dropped **face down** (`faceDownSurrender`) so the
       points conceded stay hidden.
     - **Combos (lead-first, configurable via `comboLeadsFirst`, on by default):** a hand of **three of one
       suit** — trumps ("**бура**") or non-trumps ("**молодка**"/"письмо") — or **three aces incl. the trump
       ace** takes the **opening lead** (applied in `setup`). None is an auto-win — three *low* trumps led
       can still be beaten by three higher trumps; the win is then just the points. **Mid-game, бура lets
       the non-leader claim the lead out of turn**: at a trick boundary a `.buraOffer` phase offers the
       three-trump holder a `claimBura` / `declineBura` choice (a "Lead bura" / "Pass" button), with
       attacker-first priority (the leader holding bura keeps it). молодка stays opening-only.
       `isLeadCombo` / `beatAssignment` are public for the UI and tests.
       - **Terminal handling:** the deal ends when the deck is dry and, at a trick boundary, a hand is
         empty (uneven hands from multi-card leads no longer deadlock); leftover cards aren't scored.
     - Engine + `BuraAI` + 18 tests (setup/120-point invariant, Ace-Ten beat rule, single- & multi-card
       beat-vs-surrender, winner-first refill, equal-hands refill when the deck runs low, threshold win,
       play-to-end win, clear counting, face-down surrender visibility, lead combos (incl. bura),
       three-low-trumps-is-not-a-win, mid-game bura claim/decline, attacker-keeps-lead, beat-assignment
       pairing, and a multi-seed AI playthrough conserving 36 cards with scores == captured).
     **Validated:** the engine spans beyond elimination games — scoring and list-valued moves work with
     no core changes. **Playable in-app**: `BuraScene` reuses the LayoutKit card library with Stage-A
     animation (lead → answer → sweep-to-won-pile → refill). Input applies the [[durak-input-ux-direction]]
     feedback — **no standing highlight**: single click *pops* a card into a pending set, **double-click
     plays a single card outright**, and a context button (Lead / Beat / Give, shown only when the popped
     set is a legal move) commits a multi-card play. The trick renders **Durak-style**: each answer
     **overlaps the card it beats** (on top), while a surrender **tucks under** the lead (face down if
     `faceDownSurrender`). **A click-to-continue pause** holds the opponent's
     answer on the table so you can see what was beaten or dropped before it sweeps. Live rule pills:
     win-at (end/31/41), count (full/clear), snos (open/closed face-down surrender), multi-lead on/off.
     - **Variants backlog** (from the canonical RU rules — capture-for-later, not yet built):
       *по рангам* (lead 2–3 of the same **rank**, not
       only same suit); *с перебором* (must land 31–50, bust over 50); *без козырей* (no trump); *открытая*
       (one/both hands open, with compensation points); *с пересдачея* (redeal if dealt a combo); *с даве*
       ("dave" — double-or-concede); penalties (false win declaration / out-of-turn or extra draw = loss);
       a 12-"ball" **match** scoring variant; 3-closed-vs-4-open hands. Three-of-a-kind sixes: not in this
       source — confirm with the user. Buркозел is a separate game.
     - **Match / loss-points layer** (user-requested, like `DurakMatch`): a match runs to a target of
       **loss points** (an even number — 6, 12, …); the deal loser accrues loss points scaled by how badly
       they lost — **2** for a normal loss, **4** if they finished under the "safe" score (**30** with 2
       players, **20** with 3+), and **6** for **0 takes** (won no tricks). First to the target loses.
   - **Solitaire (Klondike)** ✅ — the engine's **first single-player, non-trick game** (validates the zone
     model on a new shape). Stock (`.deck`) + waste, four **foundations** (build up A→K by suit, ace low),
     seven **tableau** piles (build down K→A in alternating colour; tableau zones are `.hidden` with the
     `faceUp` set revealing exposed cards). One game-specific field — a **redeal counter** — folded by
     `SolitaireEffect.usedRedeal`; everything else is CoreState. Moves: `draw` (turn `drawCount` to the
     waste, or **recycle** the waste when the stock is dry, capped by `redealLimit`) and `move(CardID, to:)`
     — the engine finds the source zone and, for a tableau→tableau move, **carries the whole face-up run**
     on top of the card (the face-up portion is always a valid descending-alternating run). `advance` does
     the one automatic step: flip a newly-exposed tableau top face-up. `outcome` wins when all four
     foundations hold 52 cards. Default **turn-three, unlimited redeals** (`SolitaireRules`). Engine + 10
     tests (deal shape, foundation build-up, tableau build-down + king-to-empty, run-carry move,
     exposed-card flip, draw-three + recycle, redeal-limit gating, win, and a greedy auto-player that
     terminates conserving 52 cards). **Playable in-app**: `SolitaireScene` — **drag** a card/run onto a
     foundation or tableau, **click** a card to send it straight to its foundation, **click the stock** to
     deal or recycle; faint slot outlines mark empty piles, rule pills toggle draw 1/3 and the redeal cap.
     (Drag lifts the durable `CardNode`s via a new `CardTableNode.node(_:)` accessor; a drop validates
     against `legalMoves` and snaps back if illegal.) *Backlog:* limited-redeal default for casino
     draw-three, a solver/hints, auto-complete, scoring (standard/Vegas), other solitaires (FreeCell,
     Spider) on the same zone model.
8. **Cross-cutting** — undo/redo (truncate-and-refold), persistence (Codable effect log), networking
   (effect sync), AI search over `legalMoves`.

Decouple from SpriteKit throughout — the model is UI-agnostic; `layout-app` renders effects and emits moves.

### Testing on this machine

`xcodebuild test -destination 'platform=macOS'` **cannot bind My Mac** for multi-platform test bundles
on this internal Xcode (confirmed: LayoutKit fails identically — it is an environment quirk, not a
project issue). Tests run fine in the Xcode GUI. For **headless** runs (CI, the step-5 workflow agents):

```sh
xcodebuild build-for-testing -scheme GameEngine -destination 'generic/platform=macOS'
BUNDLE=$(find ~/Library/Developer/Xcode/DerivedData -name GameEngineTests.xctest -type d | head -1)
DYLD_FRAMEWORK_PATH="$(dirname "$BUNDLE")" xcrun xctest "$BUNDLE"
```

---

## 9. Workflow plan (parallel implementation)

Once steps 1–4 exist (engine + protocol + one reference game), step 5 is the ideal **workflow**:
spawn one agent per acceptance game in an isolated worktree, each implementing the `Game` protocol
against the unchanged engine. This both produces the games and **adversarially stress-tests the
abstraction** — protocol friction reported back becomes design fixes. A prior design-exploration
workflow (N competing engine-core proposals → judged → synthesized) is optional before step 2.

---

## 10. Open questions & decisions

### Resolved

- **Simultaneous moves** → a **commit-then-resolve phase**. The phase collects one *committed*
  move per player, in any order, each hidden (face-down) from the others; once all players have
  committed, it flips/resolves them together. Covers Druncard (order is irrelevant), War-with-prison
  (a player chooses deck-vs-prison *before* seeing opponents — their committed card stays face-down
  via `playerView` until everyone has committed), Hearts passing, poker blinds. Engine needs a
  `CommitPhase` that gates on "all committed" before applying resolution.
- **Effect vocabulary** → **typed per-game effect variants** (`Effect` = universal cases +
  `.game(GameEffect)`); engine folds universal (`move/flip/collect/turn/score`), game folds its own
  (`setTrump/assignRole/setBid`). No stringly-typed state bag. Most game effects ride alongside a
  universal effect, so the renderer ignores game effects it doesn't understand (optional per-game
  renderer extension for genuinely game-specific animation).
- **Effect redaction (hidden info)** → a single **authoritative engine** (local for hotseat/AI, server
  for online) holds the full effect log; a pure `redact(effect, for: player)` strips the face of any
  card a player may not see (card present by ID, `face = hidden`); a later `flip`/`reveal` carries the
  identity. Clients consume **effects, never moves**, so a redacted client cannot reconstruct hidden
  state. Only the authoritative engine runs `lower`/`legalMoves` over full state.

### Model ↔ view bridge (LayoutKit) — decided

- **Events vs. diffing → effects, event-sourced** (see §4.1–4.2). Engine emits a canonical effect
  stream; the renderer is an effect interpreter. State is the fold of effects.
- **Stable card identity**: each card carries a persistent ID → one durable `CardNode` across folds;
  IDs reproduced from (seed + effect log).
- **Zone ↔ node mapping**: each `Zone` renders as an `SKCollectionNode`; card movement is an animated
  transfer between collection nodes — which LayoutKit's `NodeCoordinator` already supports.
- **Input → Move**: a drag/drop into a zone produces a candidate `Move`, validated/highlighted by
  `legalMoves`.
- **Pacing**: an effect queue decoupled from state transitions; AI/turn advance gated on (or decoupled
  from) animation completion.

### Deferred

- **Bridge dummy-hand control** — a per-game `playerView` + control-override detail (subsumed by the
  controller≠seat concept in §4.6).
- **P2P / anti-cheat authority** (commitment schemes / mental poker, no trusted host) — irrelevant until
  a real peer-to-peer product need; the authoritative-engine model covers hotseat/AI/online.
- **Driver concurrency model** (async driver loop, `MainActor` for the renderer, AI pacing) — an
  implementation decision to settle when building the driver (step 3 in §8).
