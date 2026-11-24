# M0.1.96 — Backrooms Production Entity Factory Geometry Validation

## Purpose

Extend M0.1.95 beyond dispatch-probe routing. Instantiate the real Backrooms playground scene, build real maze cells, invoke the production entity factories through the normal cell-construction path, and verify each configured prototype creates a structurally valid mesh hierarchy.

This closes a specific validation gap: M0.1.95 proved the director-to-dispatch mapping with lightweight marker nodes, but intentionally did not inspect the production factory output.

## Version and source

- Parent PR: [#425 — Verify level entity prototype dispatch](https://github.com/qaqp980520-prog/2126-Survival/pull/425).
- Parent exact HEAD: a50372bcba3d6a86073482dc2e4f43efd8ccbd28.
- New branch: test/backrooms-entity-factory-geometry-2026-11-24-run402.
- Root project: Godot 4.3.
- No production runtime code or save schema change.

## Files

- tests/backrooms_entity_factory_geometry_test.gd — production-scene test for all six visual factories.
- .github/workflows/godot-validation.yml — adds a dedicated Full Gate step with timeout, diagnostic rejection and exact success marker.
- docs/BACKROOMS_ENTITY_FACTORY_GEOMETRY_M0_1_96.md — this version record.

## Dependencies and import

- prototypes/BackroomsPortalPlayground.tscn
- prototypes/BackroomsPortalPlayground.gd
- systems/BackroomsEntityDirector.gd
- Existing Level 1–3 entity rosters and their six production factory methods.

From the repository root:

~~~bash
godot --headless --path . --editor --quit
godot --headless --path . --script res://tests/backrooms_entity_factory_geometry_test.gd
~~~

## Test contract

- Instantiate the actual production playground scene and attach it to the SceneTree before building entities.
- For each configured entity in Levels 1–3, find a deterministic spawn cell outside the active streaming window and invoke the real _create_maze_cell path.
- Verify the actual factory root name, backrooms_entity_id, and spawn_cell metadata.
- Verify the expected minimum number of MeshInstance3D parts for each prototype.
- Verify every mesh part is in the SceneTree, has a non-null Mesh resource, an explicit material override, and positive AABB dimensions.
- Preserve the Window closed-north-boundary constraint.
- Verify Level 0 and unknown levels create no entity roots.

Minimum mesh-part contracts: Window 5; Smiler 3; Hound 8; Skin-Stealer 6; Clump 7; Faceling 6.

## Validation status

- This PR was created from the already validated PR #425 HEAD.
- Local Godot executable is unavailable in the authoring environment. No local engine pass is claimed.
- Exact-head Godot 4.3 Full Compatibility Gate and focused tests are pending CI; do not mark this asset as validated until the new test step and full gate both pass.

## Limitations

- Headless mesh-resource and scene-tree validation does not render pixels or assess visual quality, scale readability, lighting, animation, collision, navigation, AI, GPU performance, FPS, or mobile/iPhone behavior.
- The test validates current procedural placeholder geometry; it does not add new gameplay behavior or alter entity rosters.
- No daily_games content is added or modified.

## Next steps

1. Inspect the PR diff and run exact-head Godot 4.3 CI.
2. If the headless renderer reports null-mesh or other diagnostics, keep the PR Draft and revise the harness rather than suppressing the errors.
3. After CI passes, request independent review; only integrate into #425 after approval and rerun the resulting exact parent HEAD.
