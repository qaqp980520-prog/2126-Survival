# M0.1.95 — Backrooms Entity Prototype Dispatch Integration

## Purpose

Close the integration gap between the level-scoped BackroomsEntityDirector spawn IDs and the procedural visual factories in BackroomsPortalPlayground. The existing director tests prove that each level selects the intended IDs, but they do not prove that the prototype creates the corresponding visual root for every selected ID.

## Version and source

- Base: main at 65b2cabc751637729d58f64c9633f888d3c8b74c.
- Feature branch: test/backrooms-entity-prototype-integration-2026-11-24-run401.
- Exact candidate HEAD and CI evidence will be recorded after the final workflow completes.
- No production runtime code, save schema, scene, Project Settings, or input mapping changes.

## Files

- tests/backrooms_entity_prototype_integration_test.gd — exercises the real prototype dispatch method and entity visual factories.
- .github/workflows/godot-validation.yml — required-file guard and a dedicated Godot headless test step.
- docs/BACKROOMS_ENTITY_PROTOTYPE_INTEGRATION_M0_1_95.md — this version record.

## Dependencies and import

- Godot 4.3 root project.
- systems/BackroomsEntityDirector.gd.
- prototypes/BackroomsPortalPlayground.gd.
- Existing level rosters on main: Level 1 Window / Smiler; Level 2 Hound / Skin-Stealer; Level 3 Clump / Faceling; Level 0 remains empty.

Import from the repository root:

~~~bash
godot --headless --path . --editor --quit
~~~

Run the focused test from the repository root:

~~~bash
godot --headless --path . --script res://tests/backrooms_entity_prototype_integration_test.gd
~~~

## Regression coverage

- Scan deterministic cell coordinates for Levels 1–3 and invoke the actual _spawn_level_entities_for_cell prototype dispatch.
- Compare rendered entity-root metadata against the director's selected IDs for every spawn-bearing cell.
- Verify each visual root records the correct backrooms_entity_id and spawn_cell.
- Verify every entity in each configured level roster reaches a visual factory at least once in the scan.
- Verify Window visuals are created only when the north boundary is closed; an open north passage intentionally suppresses that wall-mounted visual.
- Verify Level 0 and unknown levels create no prototype entities.

## Runtime and compatibility boundary

- This is test and CI coverage only; the existing visual factories and spawn probabilities are unchanged.
- The current entity representations remain static procedural placeholder visuals. This work does not add pursuit, patrol, perception, collision-driven movement, damage, combat, animation, or audio.
- No new Backrooms level roster is introduced; no lore-specific spawn list is inferred.
- Headless CI does not verify rendered appearance, GPU performance, or mobile/iPhone behavior.

## Validation status

Pending exact-head Godot 4.3 Full Compatibility Gate and focused test log review. No pass is claimed until the final candidate HEAD has completed CI.

## Next steps

1. Run the new integration test and full root Godot gate on the exact PR HEAD.
2. Inspect the test marker and logs for Script, Parse, Runtime, ERROR:, and FAIL: diagnostics.
3. If successful, mark the PR Ready for Review and retain it as an independent child of main; it must not be folded into the unrelated mineral rollback stack.
4. Obtain independent review before integration, then rerun exact-head CI after any parent/main synchronization.
