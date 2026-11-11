# Backrooms Level 1 Window Boundary Placement — M0.0.4

## Purpose

Fix a placement defect in the existing Level 1 Window prototype. Previously, the selector only attempted to create a Window when the cell's north edge was closed. A valid west boundary was ignored, and the prototype transform left a visible gap between the frame and the wall's inner face.

## Runtime change

- Select deterministically from the cell-owned north and west boundary walls that are closed.
- Return no placement when neither owned boundary is a wall; never attach a Window to an open passage.
- Rotate the frame toward the selected wall: north uses 0 radians, west uses +90 degrees so its face points into the room.
- Align the frame's wall-facing edge to the inner face of the 0.22 m wall using the 0.16 m frame depth. The local wall inset is 0.19 m from the cell boundary.
- Reuse named wall/frame constants for both maze wall geometry and Window placement.
- Preserve the Level 1 whitelist and 18% per-cell candidate chance. No other entity roster, portal destination, save schema, setting, or external dependency changes.

## Files

- \`prototypes/BackroomsPortalPlayground.gd\`
- \`tests/backrooms_portal_playground_test.gd\`
- \`docs/BACKROOMS_LEVEL1_WINDOW_BOUNDARY_PLACEMENT_M0_0_4.md\`

## Dependencies and import

- Godot 4.3.
- Existing Backrooms maze edge ownership and \`BackroomsEntityDirector\`.
- No third-party packages, autoloads, Project Settings, or save-format changes.
- Import from repository root: \`godot --headless --path . --import\`.

## Regression coverage

The portal playground integration test samples an 81 × 81 cell grid spanning negative and positive coordinates and verifies deterministic selection, closed-edge validity, no placement when neither owned edge is closed, both north/west orientations, expected transform, inward-facing normal, and frame alignment with the inner wall face.

The headless integration also finds deterministic Level 1 Window candidates with and without a valid owned wall and drives the actual `_spawn_level_entities_for_cell` path. A valid candidate must create a metadata-only `Entity_Window` Node3D with the expected cell, wall direction and transform; an invalid candidate must create no Window. Headless mode skips MeshInstance3D creation for that Window and keeps other render-only entity factories disabled, avoiding dummy-renderer errors while still exercising runtime dispatch.

## Validation status

- Local Godot executable is unavailable in this environment; no local engine run is claimed.
- This branch requires its own exact-head Godot 4.3 Full Compatibility Gate.
- Headless tests validate placement selection and transforms but do not visually inspect the rendered frame. Graphical-mode appearance and iPhone behavior remain outstanding.

## Next step

Inspect the north- and west-facing Window frame in graphical mode after exact-head CI. Keep the stacked PR Draft and unmerged until independent review and graphical verification are complete.


## Run 215 headless spawn-path coverage follow-up — 2026-11-11

- The previous exact-head PR #325 gate passed 553/553 steps with 0 failures; this follow-up extends coverage beyond helper transforms to the actual runtime `_spawn_level_entities_for_cell` dispatch path.
- In headless mode, Level 1 Window candidates may create a metadata-only `Entity_Window` Node3D, preserving `backrooms_entity_id`, `spawn_cell`, `wall_direction` and the computed transform without creating MeshInstance3D nodes. Other render-only entity factories remain skipped.
- Regression now verifies a valid Window candidate creates the expected metadata/transform, a candidate with no owned north/west wall creates no Window, and no headless mesh nodes are introduced.
- This follow-up commit requires a new exact-head Godot 4.3 Full Compatibility Gate. Local Godot remains unavailable; graphical rendering and iPhone behavior remain unverified.
- Next: inspect the new exact-head CI result, then perform graphical-mode Window appearance and Z-fighting review; keep the stacked PR Draft / Unmerged pending independent review.


## Headless geometry contract and realized placement measurement — Run 216

- The Window factory now consumes `_window_entity_geometry_specs()` as the single source for its pane and four frame bars. The descriptor data is renderer-independent, so the same dimensions used by the graphical factory can be checked in headless Godot without constructing MeshInstance3D nodes.
- The integration test validates the exact five part names, unique descriptors, positive Vector3 dimensions, pane/frame material roles, symmetric top/bottom and left/right placement, and the 0.16 m frame depth relative to the 0.07 m pane depth.
- The 81 × 81 deterministic sample now reports `WINDOW_PLACEMENT_RATE`: candidate count, candidates placed on an owned closed wall, candidates rejected because both owned walls are open, candidate rate, realized rate, and candidate realization percentage. This separates EntityDirector's configured 18% candidate chance from the final wall-eligible Window spawn rate.
- The test asserts every Window candidate is accounted for as either placed or blocked, with at least one valid placement, while retaining both north/west orientation and flush-wall checks.
- Exact-head Godot 4.3 CI is required after this follow-up. Local Godot, graphical material/Z-fighting inspection, and iPhone verification remain unavailable/unverified.
