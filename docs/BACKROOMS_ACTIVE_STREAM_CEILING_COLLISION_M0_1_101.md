# M0.1.101 — Active Backrooms Stream-Shift Ceiling Collision Regression

## Purpose

Extend the M0.1.100 production ceiling/collision regression beyond initial destination activation. A ceiling that works in the first 3×3 window must also remain physically active when the live Backrooms stream shifts, creates new cells, retains overlapping cells, and retires cells that leave the window.

## Change

- Update `tests/backrooms_cell_ceiling_collision_test.gd` to exercise the existing production `BackroomsMazeCellRuntime.sync_to_world_position()` path after activating a real Level 1 radius-one window.
- Shift the active center from cell `(0, 0)` to `(1, 0)` using world position `Vector3(CELL_SIZE, 0, 0)`.
- Assert the stream transaction loads 3 east-edge cells, retains 6 overlapping cells, and unloads 3 west-edge cells.
- Assert the origin cell root is retained by identity and the old `(-1, 0)` root is retired and removed from the runtime.
- Assert all 9 cells in the committed window keep their shared `WorldCollision` body enabled.
- Move a real `CharacterBody3D` probe into newly streamed cell `(2, 0)` and verify its active production ceiling physically blocks upward movement.

## Files

- `tests/backrooms_cell_ceiling_collision_test.gd` — adds the active stream-shift and post-shift physics assertions.
- `docs/BACKROOMS_ACTIVE_STREAM_CEILING_COLLISION_M0_1_101.md` — this version record.

## Dependencies and import

- Parent PR #409 exact HEAD: `8ed2b090ce4b22140819f96c01d3b88fd451e931`.
- Existing PR #428 production ceiling implementation and `BackroomsMazeCellRuntime.sync_to_world_position()`.
- Godot 4.3 root project, existing `BackroomsMazeStreamState`, root `World3D` physics server, and Xvfb/Mesa software-rendered test runner.
- The existing Full Gate Xvfb/Mesa step already invokes `tests/backrooms_cell_ceiling_collision_test.gd`; no new workflow command, project setting, autoload, plugin, external asset, import step, or save-schema change is required.
- Import through the existing root Godot 4.3 project. No new resource files are introduced.

## Validation design

The test first preserves the M0.1.100 checks for all 9 initial cells, staged collision disablement, activation, and upward collision in the origin cell. It then:

1. Captures the existing origin root and west-edge root.
2. Calls the production active-window shift to center `(1, 0)`.
3. Verifies the exact 3-load / 6-keep / 3-unload transaction counts.
4. Verifies overlapping root identity is preserved and the retired west-edge root is freed.
5. Verifies the new 3×3 window has 9 active `WorldCollision` bodies.
6. Moves the same real CharacterBody3D probe into newly streamed cell `(2, 0)` and verifies the new ceiling collision owns the blocking contact.

## Validation status

The code change is committed at the PR #428 feature branch. Exact-head Godot 4.3 Full Compatibility Gate, Xvfb/Mesa ceiling test, graphical entity smoke, and the 20-workflow matrix are pending for the final candidate. The earlier M0.1.100 pass validates the prior HEAD only and is not reused as evidence for this update.

## Limitations

- This is a runtime stream-shift and collision regression, not a rendered-pixel, hardware-GPU, FPS, or mobile-device test.
- The test uses a CharacterBody3D physics probe rather than a full player scene or Deathmoth AI controller.
- It validates one eastward one-cell window shift at radius one. Repeated multi-direction shifts and direct player/Deathmoth interactions remain separate follow-ups.
- No production runtime logic is changed in this version; the test exercises the existing transaction.

## Next steps

1. Complete the exact-final-HEAD 20-workflow matrix and audit the Full Gate and Xvfb/Mesa logs.
2. If all checks pass, update PR #428's evidence and mark it Ready for Review.
3. Obtain independent review for parent PR #409 before parent-first integration; then rerun exact-head validation on the resulting child HEAD.
4. Add direct player/Deathmoth collision coverage only after the entity's actual runtime integration point is confirmed; do not mix the legacy Level 4 playground with the newer SurfaceWorld runtime.
