# Architecture

The scene tree owns presentation. The run controller owns game state. Pure services evaluate poker hands, calculate score events, build shop offers, and validate persistence. UI scripts select and present existing scene instances rather than constructing the whole game.

## Scene composition

```text
scenes/main.tscn
├── Felt / CRT canvas shaders
├── RunController       scenes/run_controller.tscn
├── AudioDirector       Music + Effects AudioStreamPlayer nodes
├── RunHUD              scenes/ui/run_hud.tscn
├── CompactHUD          portrait status strip
├── TableView           scenes/ui/table_view.tscn
│   ├── Joker inventory instances     scenes/ui/joker_card.tscn
│   ├── Playing-card instances        scenes/ui/playing_card.tscn
│   ├── Scoring stage and controls
│   └── ShopView                      scenes/ui/shop_view.tscn
│       └── ShopOffer instances       scenes/ui/shop_offer.tscn
└── Dialog              scenes/ui/dialog.tscn
```

The main `game_ui.gd` script is the composition root. It connects UI intent signals to controller methods, coordinates score animation, loads preferences, and adjusts the layout to the viewport. `table_view.gd` owns selection and card positioning; `hud.gd` formats run statistics; `dialog.gd` owns reusable inspection/new-run/settings UI. `audio_director.gd` manages ordinary audio-player nodes and increases pitch during the scoring cascade. Card and shop scenes expose signals and setup methods for reusable instances.

## Rules and state

| Component | Responsibility |
| --- | --- |
| `RunController` | The authoritative run state, actions, inventory, blind progression, signal emission and autosave |
| `PokerEvaluator` | Detects the strongest hand and the indices of the cards that score; handles wild suits and Stone cards |
| `ScoreEngine` | Processes base hand, scoring cards, held effects and ordered Jokers into chips, Mult, total and presentation events |
| `RunEconomy` | Seeded weighted shop offers with rarity/discount modifiers and voucher lookup; purchases and payouts are committed by the controller |
| `RunConsumables` | Validates consumable targets and changes permanent cards using their stable IDs |
| `RunPersistence` | Validates and serializes run state, performs atomic save replacement and restores exact RNG state |
| `GameCatalog` | Provides authored Joker Resources and immutable consumable/voucher definitions |
| `JokerData` | Typed, exported Resource fields for an individual Joker |

The run phases are `blind → playing → shop → blind`, ending in `won` after the eighth ante's boss or `lost` when no valid continuation remains. Only controller methods mutate a run. Methods validate state, indices, affordability, capacity and target restrictions before changing state. A successful mutation commits a save and emits `changed`. `phase_changed`, `scored`, and `notice` communicate transitions, score results and rejected actions to the UI.

The UI blocks actions during score animation. The controller completes a hand atomically before animation begins, which means a suspension during the cascade cannot replay a score or award money twice.

## Scoring order

1. Evaluate the played poker hand and load base Chips/Mult at its current level.
2. Visit scoring cards in order. Apply rank chips, enhancements, editions, seals, and card-triggered Joker effects. A debuffed card contributes no scoring effects.
3. Visit held cards for Steel effects and retriggers.
4. Visit passive Jokers in inventory order. Apply each additive/multiplicative effect immediately, including the Joker's edition at its defined point.
5. Calculate `floor(chips × mult)`. Return score events, earned cash and destroyed card IDs for the controller to apply.

There is one mutable Mult accumulator. A +Mult operation adds to its current value and a ×Mult operation multiplies its current value; these operations are deliberately not collected into separate final sums/products. Moving a Joker changes the ordering of the array passed to the scorer.

Run previews simulate the next hand with a cloned RNG. They never consume live randomness, mutate cards/inventory, or apply returned rewards/destruction. The pure scorer's `context.preview` flag additionally supports excluding random outcomes. Actual score event lists are consumed by the UI for the scoring cascade and audio cues.

## Determinism and persistence

`RunController` owns a dedicated `RandomNumberGenerator` seeded from the normalized seed string. Fisher–Yates shuffling, shop choices and random effects use that generator. Determinism applies to the same build and the same action sequence; presentation timing and audio never consume game RNG.

Cards have stable IDs. Temporary hand/draw arrays are reconciled with the permanent deck by ID, so card enhancement, copying and destruction survive later shuffles. Saves include deck, draw order, hand, inventory, levels, economy, phase, boss state and RNG state.

`RunPersistence` writes a temporary JSON file before replacing `user://run_save.json`. It validates the schema, known item IDs, collection types, card shapes and numeric bounds before loading. The RNG seed/state are decimal strings to preserve 64-bit precision through JSON. Numeric card fields and prices are normalized to integers after loading.

UI preferences are separate in `user://settings.cfg`. Tests can point a controller at a different `save_path`; the shell test runner also isolates application-data directories.

## Add content

To add a Joker, duplicate a compatible Resource in `resources/jokers/`, set its ID, title, description, rarity, price, effect, condition, amount, artwork and accent, then add the Resource to `GameCatalog.JOKER_RESOURCES`. Reuse an existing score effect/condition where possible. For a new kind of effect, add one focused dispatch branch to `ScoreEngine` and a behavior test showing its order relative to existing effects.

Consumables and vouchers are declared in `GameCatalog`. Their controller mutations belong in `RunConsumables` or the relevant economy/controller method, with validation before mutation. Add tests for insufficient funds, full inventory, invalid selection and permanent-deck updates where those conditions apply.

UI structure and appearance remain editable in `.tscn` scenes, theme/style `.tres` Resources, and the two canvas shaders. Global visual changes should use the theme rather than duplicate per-widget constants.

## Validation boundaries

The scoring suite covers poker classification, scoring subsets, Ace-low straights, enhancements, seals, Joker ordering, debuffs and preview determinism. The run suite covers seeded replay, transitions, shop/consumable validation, save/load, boss constraints and campaign completion. Its transition fixture lowers targets to isolate the state machine. A separate campaign-playthrough runner uses legal game actions and real blind targets to validate one complete seeded run. One winning seed does not establish balance or a general win rate.

Rendering/export checks complement these tests. Real phone frame rate, battery use, operating-system lifecycle behavior, store compliance and long-run balance require further platform/playtesting work.
