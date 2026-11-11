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

## Validation status

- Local Godot executable is unavailable in this environment; no local engine run is claimed.
- This branch requires its own exact-head Godot 4.3 Full Compatibility Gate.
- Headless tests validate placement selection and transforms but do not visually inspect the rendered frame. Graphical-mode appearance and iPhone behavior remain outstanding.

## Next step

Inspect the north- and west-facing Window frame in graphical mode after exact-head CI. Keep the stacked PR Draft and unmerged until independent review and graphical verification are complete.
