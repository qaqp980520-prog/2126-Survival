# M0.1.103 — Multi-direction Active Stream Ceiling Collision Regression

## Purpose

Extend the production Backrooms ceiling regression beyond the single eastward shift covered by M0.1.101. Repeated cardinal and diagonal shifts must preserve overlapping cell roots, retire only outgoing roots, keep the exact radius-one window, and activate the ceiling collision in every newly streamed cell.

## Change

- Extend `tests/backrooms_cell_ceiling_collision_test.gd` with a six-transaction stream-shift cycle after the existing initial eastward shift.
- Exercise all four cardinal directions around the starting center: (1,0) → (1,1) → (0,1) → (0,0) → (1,0).
- Exercise a diagonal out-and-back pair: (1,0) → (2,1) → (1,0).
- For every cardinal shift, assert 3 loaded / 6 retained / 3 unloaded cells.
- For every diagonal shift, assert 5 loaded / 4 retained / 5 unloaded cells.
- Assert the stream generation advances exactly once per committed shift, an overlapping root retains object identity, the outgoing root is freed, and the exact nine-cell radius-one key set is committed.
- Assert every active cell keeps its production WorldCollision body and ceiling shape enabled.
- Move a CharacterBody3D probe into each newly streamed leading cell and verify the new cell's own ceiling blocks upward motion.

## Files

- `tests/backrooms_cell_ceiling_collision_test.gd` — repeated cardinal/diagonal streaming, root lifecycle, exact window, collision activation, and per-shift ceiling probes.
- `.github/workflows/godot-validation.yml` — require this version record in the existing validation input guard; the existing Xvfb/Mesa production ceiling step executes the expanded test script.
- `docs/BACKROOMS_MULTI_DIRECTION_ACTIVE_STREAM_CEILING_M0_1_103.md` — this version record.

## Dependencies and import

- Parent PR #409 exact HEAD: `8ed2b090ce4b22140819f96c01d3b88fd451e931`.
- Child PR #428 exact validated HEAD before this follow-up: `668d92647b0ca05f1c140d3f2c0c4d0325bd03d6`.
- Godot 4.3 root project; `BackroomsMazeCellRuntime`, `BackroomsMazeStreamState`, `BackroomsEntityDirector`, and `BackroomsEntityCollisionFactory`.
- Existing Xvfb/Mesa llvmpipe production physics runner. Import through the existing root Godot 4.3 project; no new external assets, plugins, autoloads, project settings, or save-schema changes.

## Validation status

Pending exact-head validation. The earlier Run 407 20/20 workflow result validates the previous HEAD only and is not reused for this expanded test.

## Limitations

- The stream-shift sequence is deterministic and uses radius one. It covers all four cardinal directions and a diagonal out-and-back pair, but not random long-distance teleports or every possible stream radius.
- The collision probe is a CharacterBody3D using the production world-geometry collision layer, not the full production player controller.
- This validates cell-root streaming and ceiling collision, not Deathmoth AI pursuit, attacks, damage, player health, or navigation.
- Xvfb/Mesa is software-rendered CI evidence, not hardware-GPU, FPS, final pixel-quality, or mobile-device validation.
- No local Godot executable is available; the exact-head engine result must come from GitHub Actions.

## Next steps

1. Complete the exact-head Full Compatibility Gate and Xvfb/Mesa production ceiling test.
2. Audit the complete Full Gate and focused job logs for actual Godot diagnostics, not shell-guard echoes.
3. If successful, update this version record, PR #429, the asset index, and Run 408 Notion record with exact evidence.
4. Obtain independent review for parent PR #409 before integrating #428 parent-first; rerun the resulting exact HEAD after integration.
