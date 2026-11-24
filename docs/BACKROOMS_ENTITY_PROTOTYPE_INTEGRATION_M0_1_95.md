# M0.1.95 — Backrooms Entity Prototype Dispatch Integration

## Purpose

Close the integration gap between the level-scoped BackroomsEntityDirector spawn IDs and the procedural visual factories in BackroomsPortalPlayground. The existing director tests prove that each level selects the intended IDs, but they do not prove that the prototype dispatch reaches the matching factory for every selected ID.

## Version and source

- Base: main at 65b2cabc751637729d58f64c9633f888d3c8b74c.
- Feature branch: test/backrooms-entity-prototype-integration-2026-11-24-run401.
- Exact candidate HEAD and CI evidence will be recorded after the final workflow completes.
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

## Validation status

Pending exact-head Godot 4.3 Full Compatibility Gate and focused test log review. No pass is claimed until the final candidate HEAD has completed CI.

## Next steps

1. Run the new integration test and full root Godot gate on the exact PR HEAD.
2. Inspect the test marker and logs for Script, Parse, Runtime, ERROR:, and FAIL: diagnostics.
3. If successful, mark the PR Ready for Review and retain it as an independent child of main; it must not be folded into the unrelated mineral rollback stack.
4. Obtain independent review before integration, then rerun exact-head CI after any synchronization with main.
