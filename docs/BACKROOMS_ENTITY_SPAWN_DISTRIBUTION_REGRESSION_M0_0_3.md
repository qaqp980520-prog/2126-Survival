# Backrooms Entity Spawn Distribution Regression — M0.0.3

## Purpose

Protect the level-specific Backrooms spawn rules from accidental balance drift. M0.0.2 already checked exact rosters, deterministic cell selection, per-level whitelists and that each configured entity can appear. This test-only follow-up also checks the configured percentage table and the observed distribution over a fixed 81 × 81 grid spanning positive and negative coordinates.

## Files

- `tests/backrooms_entity_director_test.gd`
- `docs/BACKROOMS_ENTITY_SPAWN_DISTRIBUTION_REGRESSION_M0_0_3.md`

## Runtime behavior

No gameplay behavior, scene wiring, save data, portal destinations, project settings or external dependencies change. The existing M0.0.2 roster and chance values remain the contract:

| Entity | Expected per-cell chance |
| --- | ---: |
| Window | 18% |
| Smiler | 7% |
| Hound | 8% |
| Skin-Stealer | 5% |
| Clump | 6% |
| Faceling | 8% |
| Duller | 6% |
| Deathmoth | 4% |

## Regression coverage

- The chance table must exactly match the versioned prototype balance values above.
- Every Level 0–5 roster must match its explicit whitelist; Level 0 remains empty and unknown levels fail closed.
- Repeated queries for each of the 6,561 sampled cells must return identical results.
- Every spawned entity must belong to that level's whitelist, and every configured entity must appear at least once in the sample.
- Each entity's measured sample frequency must remain within ±1.5 percentage points of its configured chance.
- The test prints one `SPAWN_CANDIDATE_RATE` line per entity with expected rate, observed rate and sample count, so CI logs retain concrete distribution evidence.

The finite grid is a deterministic regression sample, not a statistical guarantee for every possible world coordinate. These rates measure `BackroomsEntityDirector.get_cell_spawns()` candidate selection, not the number of rendered instances. Geometry-specific placement can legitimately skip a candidate when the required wall or surface is unavailable.

## Dependencies and import

- Godot 4.3.
- Existing `systems/BackroomsEntityDirector.gd`.
- No third-party packages or additional resources.
- Import from repository root: `godot --headless --path . --import`.
- Focused regression: `godot --headless --path . --script res://tests/backrooms_entity_director_test.gd`.

## Validation status

The parent PR #322 exact-head Full Compatibility Gate passed at 553/553 steps with 0 failures on HEAD `571622999262ffd4a80fa61ba9753beda095820a` (Run #43004298451). This M0.0.3 branch adds the spawn-frequency assertions and must pass its own exact-head Godot 4.3 gate before it is considered validated.

Local Godot is unavailable in the current execution environment; no local engine test is claimed. Graphical entity appearance, entity AI and iPhone behavior are outside this test's scope.

## Next step

Wait for the child PR's exact-head Full Compatibility Gate, inspect its `SPAWN_CANDIDATE_RATE` output, and keep the PR Draft / Unmerged until independent review and graphical-mode inspection are complete.
