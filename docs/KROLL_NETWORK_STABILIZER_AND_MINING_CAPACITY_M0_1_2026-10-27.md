# Run 23 — KROLL Network Stabilizer + underground mining capacity guard

## New game
- Path: daily_games/KROLL_Network_Stabilizer/
- Engine: Godot 4.3+, no external assets or add-ons.
- Gameplay: 10×8 relay-defense grid, 3 waves (8/10/12 packets), 10 core integrity, 100 starting credits, 40-credit auto-relays, 12-credit kill reward. Relays may be placed during build or combat but never on the route or outside the board.
- Controls: click a free tile to place; Space/click Start Wave to begin; R/click Restart to reset.
- Tests: deterministic rules and scene smoke test cover placement, economy, waves, targeting, escapes, win state, and restart.

## Existing survival system
- Extend tests/underground_mining_playground_test.gd to fill the shared inventory's iron_ore count to SurvivalInventory.MAX_SAVED_COUNT, attempt mining, and assert that inventory rejection leaves vein stock unchanged.
- Restore the original valid inventory snapshot after the injected overflow case so the rest of the test is isolated.
- Preserve the invariant that all mineable veins are below the surface and surface exploration exposes no mining action.

## Validation
- A dedicated GitHub Actions workflow runs Godot 4.3 import, rules, runtime smoke, and underground integration tests.
- Local Godot executable is unavailable in this environment; no local GUI/GPU/iPhone test is claimed. Merge is prohibited until exact-head CI passes.


## CI workflow note
- The canonical pre-merge validation is the existing .github/workflows/godot-validation.yml, which imports Network Stabilizer, runs its rules and runtime smoke tests, and runs the underground mining capacity regression on the pull-request head.
- The temporary focused workflow used during the candidate experiment was removed because a newly introduced workflow file is not guaranteed to run for the same pull request before it exists on the base branch.
- Merge only after the canonical workflow succeeds on the exact current PR head.
