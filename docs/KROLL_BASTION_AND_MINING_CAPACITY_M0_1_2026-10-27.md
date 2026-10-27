# Run 23 — KROLL Bastion Protocol + underground mining capacity guard

## New game
- Path: daily_games/KROLL_Bastion_Protocol/
- Engine: Godot 4.3+, no external assets or add-ons.
- Gameplay: 10×8 tower-defense grid, 3 waves (8/10/12 enemies), 10 core lives, 100 starting credits, 40-credit auto-turrets, 12-credit kill reward. Turrets may be placed during build or combat but never on the route or outside the board.
- Controls: click a free tile to place; Space/click Start Wave to begin; R/click Restart to reset.
- Tests: deterministic rules and scene smoke test cover placement, economy, waves, targeting, escapes, win state, and restart.

## Existing survival system
- Extend tests/underground_mining_playground_test.gd to fill the shared inventory's iron_ore count to SurvivalInventory.MAX_SAVED_COUNT, attempt mining, and assert that inventory rejection leaves vein stock unchanged.
- Restore the original valid inventory snapshot after the injected overflow case so the rest of the test is isolated.
- Preserve the invariant that all mineable veins are below the surface and surface exploration exposes no mining action.

## Validation
- A dedicated GitHub Actions workflow runs Godot 4.3 import, rules, runtime smoke, and underground integration tests.
- Local Godot executable is unavailable in this environment; no local GUI/GPU/iPhone test is claimed. Merge is prohibited until exact-head CI passes.
