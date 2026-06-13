# LayoutApp — Cross-Platform Card Games on a Turn-Based Engine

A macOS + iOS app of playable card games (War, Durak, Bura, Klondike Solitaire) built on a
Foundation-only, event-sourced game engine, rendered with SpriteKit and hosted in SwiftUI.

> History: this project began as a SpriteKit *collection-layout framework* (`SKCollectionNode` +
> pluggable layouts). The card games outgrew that model — see "Layout approach" below — and the
> collection system was removed. `LayoutKit` now contains only the shared card-rendering layer.

## Targets

- **GameEngine** (framework, Foundation only): the universal turn-based engine and the games' rules/AI.
- **LayoutKit** (framework): the shared card-rendering layer — `CardTableNode`, `CardNode`, `CardMetrics`. That's all.
- **LayoutApp** (app, multiplatform: macOS + iOS/iPadOS/Sim): scenes, SwiftUI hosts, input.
- **GameEngineTests**, **LayoutKitTests**: unit tests (LayoutKitTests covers the card layer only).

Multiplatform target settings of note: `SDKROOT = auto`, `SUPPORTED_PLATFORMS = "iphoneos iphonesimulator macosx"`,
SDK-conditioned keys (e.g. `"CODE_SIGN_ENTITLEMENTS[sdk=macosx*]"`), and a multiplatform `LD_RUNPATH_SEARCH_PATHS`
(`@executable_path/Frameworks` + an `[sdk=macosx*]` override). The Xcode project uses `objectVersion = 77`
**synchronized filesystem groups** — files on disk are in the build automatically; there are no per-file
pbxproj entries to maintain (only a small `membershipExceptions` list for a few resources).

## GameEngine

Event-sourced and game-agnostic: a `Game` protocol, a `CoreState`/registry of cards, and `Effect`
batches that mutate state. Each game (`WarGame`, `DurakGame`/`DurakMatch`/`DurakRules`/`DurakAI`,
`BuraGame`, Solitaire + `SolitaireAnalysis`) supplies rules, legal moves, and AI. Scenes never mutate
state directly — they fold the engine's effect batches and re-render. See `GameEngine/.../card-engine-plan.md`.

## Layout approach — `CardTableNode`, not a collection framework

All four games render with one model (a declarative snapshot + reconciler):

```
state ──placements(for:)──▶ [cardID: CardPlacement] ──CardTableNode.apply──▶ animated card nodes
        (pure, hand-computed                          (diff: add/remove/move/flip/resize, keyed)
         positions + zPosition)
```

- Each scene computes a **pure `placements(for: state)`** returning every card's absolute `CGPoint`,
  `zRotation`, `zPosition`, `size`, and `faceUp` — sizing via `CardMetrics.fit(maxWidth:maxHeight:)`
  (card aspect 108/78). Stacking, overlap (e.g. Durak's trick pairs, Solitaire's fans), and
  shrink-to-fit are explicit arithmetic; "stacking" is just an incrementing `zPosition` at a position.
- **`CardTableNode`** owns durable `CardNode`s keyed by card id and `apply(_:duration:)` diffs old→new:
  cards no longer present fade out, new ones are created, existing ones animate to their new placement
  (move/rotate/flip/resize), with **keyed** actions so a re-apply (e.g. on resize) replaces rather than
  races an in-flight animation. Because ids persist, a card glides across "zones" (deck→hand→table→discard) for free.
- **Drag/drop is visual only.** The dragged node tracks the cursor; on drop the scene *proposes* a move
  (from a geometric gate + hit-test) and the **engine validates it** (`game.legalMoves`). Legal → mutate
  state → recompute placements → `apply` re-snaps the board. Illegal → `snapBack`. The game state is the
  source of truth, never the node — so there's no node-moving "coordinator."

This is why the games don't (and shouldn't) use a UICollectionView-style container: cards span multiple
zones with bespoke overlap and rule-gated drops, which a single bounded collection+layout can't express.

## Scenes & hosting

- `PointerInputScene` (SKScene base) unifies macOS `NSEvent` and touch into `pointerDown/Moved/Up/Secondary`
  hooks (in scene space). It also carries `top/bottom/left/rightSafeInset`, set by the host.
- Scenes use `scaleMode = .resizeFill`, `anchorPoint = .zero` (origin bottom-left, y-up).
- `GameSceneHost` (SwiftUI) pins `scene.size` to the measured size (SwiftUI `SpriteView` doesn't reliably
  resize a `.resizeFill` scene on iOS → anamorphic stretch otherwise) and, when `fullScreen`, forwards the
  device safe-area insets via a full-bleed UIKit `safeAreaInsetsDidChange` probe (updates on every rotation,
  including landscape↔landscape; `GeometryProxy.safeAreaInsets` reports 0 once safe area is ignored).
- Per-game SwiftUI hosts (`DurakHostView`, `SolitaireHostView`) present full-screen boards and a felt-styled
  **settings/debug sheet** behind a gear button. Rules, seed, etc. live in the sheet — not on the board.
  Chrome (✕ exit, gear, scoreboard) is drawn **in-scene** as SpriteKit nodes; SF Symbols/emoji over words.

## Building and running

Open `LayoutApp.xcodeproj`, pick the **LayoutApp** scheme and a macOS or iOS destination, build & run.
The landing page lists the four games. Durak takes over the full screen; the others push a scene view.

Note: `xcodebuild test` can't bind "My Mac" in this environment — run tests from the Xcode GUI (or `xcrun xctest`).

## Working here

- Keep SpriteKit scenes platform-agnostic; do native chrome in SwiftUI so it ports to iOS unchanged.
- Add UI as SF Symbols/emoji, not words, where reasonable.
- When changing card layout, edit the scene's `placements(for:)` (and `CardMetrics`-based sizing) — that
  pure function plus `CardTableNode` is the whole rendering contract.
