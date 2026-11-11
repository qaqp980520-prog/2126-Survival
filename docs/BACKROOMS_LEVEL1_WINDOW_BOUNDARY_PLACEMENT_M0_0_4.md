# Backrooms Level 1 Window Boundary Placement — M0.0.4

## Purpose

Fix a placement defect in the existing Level 1 Window prototype. Previously, the selector only attempted to create a Window when the cell's north edge was closed. A valid west boundary was ignored, and the prototype transform left a visible gap between the frame and the wall's inner face.

## Runtime change

- Select deterministically from the cell-owned north and west boundary walls that are closed.
- Return no placement when neither owned boundary is a wall; never attach a Window to an open passage.
- Rotate the Window frame toward the selected wall: north uses 0 radians, west uses -90 degrees.
- Align the frame's wall-facing edge to the inner face of the 0.22 m wall using the 0.16 m frame depth. The local wall inset is 0.19 m from the cell boundary.
- Reuse named wall/frame constants for both maze wall geometry and Window placement.
- Preserve Level 1 whitelist and 18% per-cell candidate chance. This does not change other entity rosters, portal destinations, save schema, settings, or external dependencies.

## Files

- \`prototypes/BackroomsPortalPlayground.gd\`
- \`tests/backrooms_portal_playground_test.gd\`
- \`tests/backrooms_entity_director_test.gd\` (candidate-rate label clarification)
- \`docs/BACKROOMS_ENTITY_SPAWN_DISTRIBUTION_REGRESSION_M0_0_3.md\` (candidate-rate semantics)
- \`docs/BACKROOMS_LEVEL1_WINDOW_BOUNDARY_PLACEMENT_M0_0_4.md\`

## Dependencies and import

- Godot 4.3.
- Existing Backrooms maze edge ownership, \`BackroomsEntityDirector\`, and \`BackroomsPortalPlayground\`.
- No third-party packages, autoloads, Project Settings, or save-format changes.
- Import from repository root: \`godot --headless --path . --import\`.

## Regression coverage

The portal playground integration test samples an 81 × 81 cell grid spanning negative and positive coordinates and verifies:

- The chosen direction is deterministic.
- A selected north/west edge is actually closed.
- Cells with no closed cell-owned north/west edge return no placement.
- Both north and west placements are exercised by the fixture.
- The Window transform has the expected position and orientation.
- The frame's wall-facing edge is flush with the inner wall face.
- The source contract wires the chosen direction into the Window visual factory.

The existing entity director distribution test now emits \`SPAWN_CANDIDATE_RATE\`. Its percentage describes deterministic cell-level candidate selection, not the final rendered-instance count; a geometry-specific placement may be skipped when no suitable boundary exists.

## Validation status

- Local Godot executable is unavailable in this environment; no local engine run is claimed.
- The new branch requires its own exact-head Godot 4.3 Full Compatibility Gate.
- Headless tests validate placement selection and transforms but do not visually inspect the rendered frame. Graphical-mode appearance and iPhone behavior remain outstanding.

## Next step

Review the exact-head Full Compatibility Gate, then inspect the north- and west-facing Window frame in graphical mode. Keep the stacked PR Draft and unmerged until independent review and graphical verification are complete.
