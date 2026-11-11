# Backrooms Headless Entity Dispatch Contract — M0.0.5

## Purpose

Exercise the same level-specific entity factory dispatch used by streamed Backrooms cells in headless Godot CI. Previously, the spawn dispatcher skipped every non-Window entity in headless mode. The Director whitelist tests proved candidate selection, but did not prove that Smiler, Hound, Skin-Stealer, Clump, Faceling, Duller and Deathmoth reached their runtime factory roots.

## Runtime change

- Remove the global headless skip from _spawn_level_entities_for_cell().
- Each non-Window factory now creates its normal Node3D root, assigns backrooms_entity_id and spawn_cell, then returns before creating renderer-only MeshInstance3D or material resources when DisplayServer is headless.
- The root position is set by the existing factory before the headless guard, so CI exercises the actual factory root and deterministic cell placement rather than a separate test-only substitute.
- Window retains its owned-wall eligibility check, wall direction, transform and metadata-only headless path.
- Graphical mode continues through the existing visual factory code without changing entity geometry.

## Files

- prototypes/BackroomsPortalPlayground.gd
- tests/backrooms_portal_playground_test.gd
- docs/BACKROOMS_HEADLESS_ENTITY_DISPATCH_M0_0_5.md

## Dependencies and import

- Godot 4.3.
- Existing BackroomsEntityDirector, level whitelist and deterministic cell hash.
- Existing Backrooms playground scene and entity factory functions.
- No third-party packages, new autoloads, Project Settings changes, portal destination changes or save-schema changes.
- Import from repository root: godot --headless --path . --import.

## Regression coverage

The Backrooms playground integration test invokes _spawn_level_entities_for_cell() for a deterministic candidate of every configured non-Window entity in Levels 1–5 and verifies:

- The expected runtime factory root is created.
- backrooms_entity_id and spawn_cell metadata match the selected entity and deterministic cell.
- The root position matches the existing factory's deterministic coordinate hash and per-entity offset/height.
- No MeshInstance3D is created in headless mode.
- Existing Window tests still verify valid owned-wall placement, blocked open-boundary candidates, wall direction, transform and metadata.
- Level 0 remains empty through the separate Director whitelist regression.

The test searches the existing fixed 81×81 positive/negative coordinate grid for deterministic entity candidates; it does not alter candidate probabilities.

## Validation status

- A new exact-head Godot 4.3 Full Compatibility Gate is required for this branch.
- Local Godot is unavailable in the current execution environment; no local engine run is claimed.
- Headless validation proves dispatch, root metadata and renderer avoidance, not graphical appearance, AI behavior, collision, pathfinding, lighting or iPhone performance.

## Next steps

1. Run the exact-head Godot 4.3 Full Compatibility Gate.
2. If any entity fails to dispatch or creates a render resource in headless mode, fix the affected factory before considering the PR validated.
3. Keep this PR Draft and unmerged until its exact-head gate and independent review are complete.
4. Perform graphical-mode visual inspection and later add per-entity AI only as a separate, testable system.