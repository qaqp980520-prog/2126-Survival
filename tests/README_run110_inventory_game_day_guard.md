# Run 110 — Inventory Game-Day Property Guard

## Change

SurvivalInventory.game_day was a public typed integer. The supported set_game_day() method clamps values to the save range, but direct assignment bypassed that clamp. A negative or oversized day could therefore make runtime carry-limit behavior disagree with the saved/loaded contract and produce a snapshot that strict validation rejects.

The model now stores _game_day privately and exposes a guarded game_day property. Direct assignments and set_game_day() use the same [1, MAX_SAVED_GAME_DAY] clamp. Strict save loading remains atomic and rejects malformed external payloads.

## Regression coverage

- tests/inventory_weight_boundaries.gd: direct negative/oversized assignment and serialized-day boundary checks.
- tests/inventory_game_day_property_test.gd: bridge serialization preserves unrelated world fields, the clamped day is serialized, invalid restore leaves live day/counts unchanged, and valid restore still works.

## Dependencies and import

No new dependencies. Root Godot 4.3 project. Run:

godot --headless --path . --script res://tests/inventory_game_day_property_test.gd

Also run the existing inventory boundary and save-adapter tests.

## Limits

- World-save schema remains version 1.
- counts remains public for legacy compatibility; this change only guards the game-day property.
- Local rendered GUI/GPU and physical iPhone testing are separate acceptance tasks.
