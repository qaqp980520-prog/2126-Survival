# M0.1.95 — Backrooms Entity Prototype Dispatch Integration

## Purpose

Close the integration gap between the level-scoped BackroomsEntityDirector spawn IDs and the procedural visual factories in BackroomsPortalPlayground. The existing director tests prove that each level selects the intended IDs, but they do not prove that the prototype dispatch reaches the matching factory for every selected ID.

## Version and source

- Base: main at 65b2cabc751637729d58f64c9633f888d3c8b74c.
- Feature branch: test/backrooms-entity-prototype-integration-2026-11-24-run401.
- Tested code/test candidate HEAD: 75dda2cbef00b8c687a73478cd08e932661358fb (8 commits ahead / 0 behind main).
- Final documentation-only commit will update this version record; it does not alter the tested source or test scripts.
- No production runtime code, save schema, scene, Project Settings, or input mapping changes.

## Files

- tests/backrooms_entity_prototype_integration_test.gd — scans deterministic cells and compares director output with prototype dispatch markers.
- tests/helpers/BackroomsEntityDispatchProbe.gd — test-only subclass that replaces mesh construction with lightweight Node3D markers while inheriting the real prototype dispatch method.
- .github/workflows/godot-validation.yml — required-file guards and a dedicated Godot headless test step.
- docs/BACKROOMS_ENTITY_PROTOTYPE_INTEGRATION_M0_1_95.md — this version record.

## Dependencies and import

- Godot 4.3 root project.
- systems/BackroomsEntityDirector.gd.
- prototypes/BackroomsPortalPlayground.gd.
- Existing main rosters: Level 1 Window / Smiler; Level 2 Hound / Skin-Stealer; Level 3 Clump / Faceling; Level 0 remains empty.

Import from the repository root:

~~~bash
godot --headless --path . --editor --quit
~~~

Run the focused test from the repository root:

~~~bash
godot --headless --path . --script res://tests/backrooms_entity_prototype_integration_test.gd
~~~

## Regression coverage

- Scan deterministic cells for Levels 1–3 and invoke the inherited real _spawn_level_entities_for_cell dispatch.
- Compare marker IDs against the director's selected IDs for every spawn-bearing cell.
- Verify each marker records the correct backrooms_entity_id and spawn_cell.
- Verify every configured entity has a corresponding method on the production prototype and reaches the matching dispatch override at least once.
- Verify Window dispatch only occurs when the north boundary is closed; an open north passage intentionally suppresses that wall-mounted visual.
- Verify Level 0 and unknown levels create no prototype entities.

## Runtime and compatibility boundary

- This is test and CI coverage only; existing visual factories, spawn probabilities, and production runtime behavior are unchanged.
- The probe intentionally avoids MeshInstance3D construction in headless mode. It verifies the production dispatch-to-factory routing and factory method presence, not rendered mesh geometry or visual quality.
- Current entity representations remain static procedural placeholder visuals. This work does not add pursuit, patrol, perception, collision-driven movement, damage, combat, animation, or audio.
- No new Backrooms level roster is introduced; no lore-specific spawn list is inferred.
- Headless CI does not verify rendered appearance, GPU performance, or mobile/iPhone behavior.

## Exact-head validation — 2026-11-24

Tested code/test candidate HEAD: 75dda2cbef00b8c687a73478cd08e932661358fb.

- Godot 4.3 Full Compatibility Gate [45346339368](https://github.com/qaqp980520-prog/2126-Survival/actions/runs/45346339368): **554/554 steps successful, 0 failed**.
- All 19 PR-triggered workflows visible for this candidate completed Success: the Full Gate plus 18 focused workflows.
- Mineral Grid Streaming Lifecycle [45346339791](https://github.com/qaqp980520-prog/2126-Survival/actions/runs/45346339791): Success.
- The new Backrooms entity prototype integration step #22 passed and printed: `Backrooms entity prototype integration tests passed: 3250 cells, 2643 dispatched entities.`
- Existing Backrooms steps also passed: entity director #21, portal director #23, portal visual scene #24, portal playground integration #25, player input #44, settings profile #45, and settings integration #46.
- Full Gate log audit: 7,691,793 characters / 84,146 lines / 77,794 PASS matches / 23 warnings. Actual Script/Parse/Runtime/ERROR/FAIL diagnostics: **0**; ObjectDB leaks: 0; Orphan StringName diagnostics: 0.
- Retained warnings: 19 filled draw_rect width notices, 1 nested project notice for the legacy daily_games/KROLL_Salvage_Exchange folder, 1 stale-unload rollback warning, and 2 synchronous mineral-registration rollback warnings. None is claimed fixed.
- No local Godot executable, GPU, target-device, rendered visual, FPS, or mobile/iPhone pass is claimed.

## Limitations

- The test validates dispatch/factory routing and metadata through lightweight marker nodes, not actual mesh geometry or rendered appearance.
- Existing visual factories and spawn probabilities are unchanged.
- This PR is based directly on main and is independent of the MineralChunkController rollback stack.

## Next steps

1. Obtain independent review of PR #425.
2. If approved, merge only after repository review/CI requirements are satisfied; do not bypass the review gate.
3. Rerun exact-head CI after any main synchronization.
