# M0.1.100 — Enclosed Backrooms Cell Ceiling Geometry

## Purpose

Close the production Backrooms maze cells with a matching visual ceiling and physical ceiling boundary. The runtime already places deterministic OmniLight3D fixtures at the top of each room and builds perimeter walls to a fixed height; without a ceiling surface, the room remained open above the wall line and mobile bodies could leave through the top.

## Implementation

- `systems/BackroomsMazeCellRuntime.gd`
  - Adds `CEILING_THICKNESS = 0.18`.
  - Builds a `Ceiling` BoxMesh covering the full cell footprint.
  - Places the ceiling underside exactly at `WALL_HEIGHT` (3.2 m), flush with the perimeter wall tops.
  - Uses a cached, explicit StandardMaterial3D ceiling material.
  - Adds a matching `CeilingCollision` BoxShape3D to the existing `WorldCollision` StaticBody3D.
  - Reuses the existing activation/deactivation collision-layer transaction. Prepared destinations keep the entire world-collision body disabled; activation enables floor, perimeter walls, and ceiling together.
- Existing maze connectivity is unchanged. Open edges still omit their corresponding perimeter wall segments; the ceiling spans the room without closing those doorways.
- Existing ceiling lights remain below the ceiling underside. No navigation mesh, entity spawn, movement, save schema, project settings, or input mapping changes.

## Files

- `systems/BackroomsMazeCellRuntime.gd` — production ceiling mesh, material and collision.
- `tests/backrooms_cell_ceiling_collision_test.gd` — new production 3×3 cell geometry and physical collision regression.
- `tests/backrooms_entity_visual_factory_render_smoke_test.gd` — checks ceiling resources on Level 0 and all eight entity factory fixtures; hides room shell surfaces during isolated silhouette captures.
- `.github/workflows/godot-validation.yml` — required-file guard and Xvfb/Mesa execution step.

## Dependencies and import

- Godot 4.3 root project.
- Existing `BackroomsMazeCellRuntime`, `BackroomsMazeStreamState`, `BackroomsCellNavigationFactory`, and root `World3D` physics server.
- No new external assets, SVGs, third-party dependencies, autoloads, project settings, or import steps.

## Validation design

The new graphical test prepares a real Level 1 radius-one window and checks all nine production cell roots:

- Ceiling BoxMesh footprint, thickness, transform, and explicit material.
- Matching named collision shape and identical transform/size.
- Ceiling underside flush with wall tops.
- Existing open/closed edge wall selection remains unchanged.
- Any live ceiling light remains below the ceiling surface.
- Collision remains disabled while the destination is staged.
- After activation, every cell enables the shared WorldCollision body; a CharacterBody3D sphere moving upward in the origin cell is physically stopped by the ceiling.

The existing production visual smoke test also checks the ceiling on the Level 0 fixture and all eight entity factory fixtures.

## Validation status

Pending exact-head GitHub Actions Godot 4.3 Full Compatibility Gate, Xvfb/Mesa ceiling collision test, existing graphical entity smoke, and Hound durable round-trip. No test pass is claimed for the new branch until all exact-head jobs complete and their logs are audited.

## Limitations

- The ceiling is a primitive blockout surface with a flat material; no ceiling texture, tiles, pipes, exposed wiring, fixtures, or per-level ceiling art are included.
- Xvfb/Mesa llvmpipe validates geometry construction and physics collision in CI, not hardware-GPU lighting quality, final pixel output, FPS, or iPhone/iPad behavior.
- The ceiling does not add interior obstacles or alter the existing rectangular per-cell navigation region.
- Local Godot executable is unavailable in the authoring environment; no local engine run is claimed.

## Next steps

1. Complete the exact-head 19-workflow matrix and audit the full Gate and Xvfb/Mesa logs.
2. Correct any real parser, runtime, physics, or regression failures on the feature branch and rerun the exact new HEAD.
3. Obtain independent review for the parent Hound stack before parent-first integration; do not merge this child or main without the required review and release safeguards.
4. If the blockout ceiling is accepted, create separate visual-art direction for level-specific ceiling materials/fixtures rather than adding unverified decorative assets here.
