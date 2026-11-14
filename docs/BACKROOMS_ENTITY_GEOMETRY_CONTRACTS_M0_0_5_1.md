# Backrooms Duller／Deathmoth Renderer-Independent Geometry Contract — M0.0.5.1

## Purpose

Make the Level 4 Duller and Level 5 Deathmoth procedural geometry inspectable in headless Godot without constructing renderer-only MeshInstance3D resources. The same geometry specifications now drive the graphical factories and the headless regression, avoiding a test-only duplicate of the visual dimensions.

## Runtime implementation

- Extract Duller parts into `_duller_entity_geometry_specs()`.
- Extract Deathmoth wings, rear wings, abdomen, thorax, head, compound eyes, antennae and six legs into `_deathmoth_entity_geometry_specs()`.
- Add `_add_entity_geometry_specs()` as the single renderer-side builder for BoxMesh and SphereMesh parts.
- Preserve the existing root transforms, entity metadata, materials, dimensions, and rotations from M0.0.5.
- Validate the complete spec array before adding any visual child, preventing partial geometry construction on malformed data.
- Headless mode still creates metadata-only entity roots and skips all renderer-only mesh resources.

## Regression coverage

The Backrooms playground integration test now checks:

- Duller has exactly six uniquely named parts, positive dimensions, one featureless sphere head, symmetric arms and legs, and the existing torso/head dimensions.
- Deathmoth has exactly sixteen parts: two wings, two rear wings, abdomen, thorax, head, two compound eyes, two antennae and six legs.
- Left/right wing, rear-wing, eye and antenna placement is mirrored; wing rotations are opposite.
- Wing, body and eye material roles are explicit and consistent.
- Every box/sphere specification has a valid position, rotation, positive dimensions and allowed material key.
- The existing headless runtime-dispatch regression still verifies the real factory roots, deterministic positions and absence of MeshInstance3D nodes.

## Files

- `prototypes/BackroomsPortalPlayground.gd`
- `tests/backrooms_portal_playground_test.gd`
- `docs/BACKROOMS_ENTITY_GEOMETRY_CONTRACTS_M0_0_5_1.md`

## Dependencies and import

- Godot 4.3.
- Existing `BackroomsEntityDirector` and Backrooms portal playground scene.
- No external packages, autoloads, Project Settings, save schema, or scene wiring changes.
- Root import: `godot --headless --path . --editor --import --quit`.
- Focused test: `godot --headless --path . --script res://tests/backrooms_portal_playground_test.gd`.

## Validation and limitations

- This commit requires a new exact-head Godot 4.3 Full Compatibility Gate.
- Local Godot is unavailable in this environment; no local engine pass is claimed.
- Headless CI validates the geometry data contract and dispatch, not the rendered appearance, material transparency, lighting, Z-fighting, collision, AI or iPhone performance.
- Graphical-mode inspection remains required before treating the new entity visuals as visually accepted.

## Next step

Run the exact-head Full Compatibility Gate and inspect the focused Backrooms integration output. After CI passes, keep the stacked PR Draft until independent review and graphical-mode inspection are complete.


## Run 263.1 — finite-value and failure-atomic builder guard

- The geometry builder now rejects non-finite position, rotation, box-size, sphere-radius and sphere-height values, as well as zero/negative dimensions.
- All specs are validated before the first MeshInstance3D is created.
- The headless regression supplies a valid first part followed by an invalid zero-width box and asserts that the builder rejects the complete array with zero children added.
- This specifically verifies failure atomicity without constructing renderer-only nodes.
- New exact-head Godot 4.3 Full Compatibility Gate is required; no local Godot executable is available.
