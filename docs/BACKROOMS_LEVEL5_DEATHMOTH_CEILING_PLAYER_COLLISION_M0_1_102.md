# M0.1.102 — Level 5 Deathmoth Ceiling and Player Collision

## Purpose

Validate the ceiling against a real mobile flying entity in the newer SurfaceWorld-owned Backrooms runtime, and verify the production Deathmoth collision proxy can also interact with the player collision layer. This closes a gap left by the generic CharacterBody3D ceiling probe: the production Level 5 Deathmoth must be kept inside the room and must remain physically addressable by the player.

## Change

- Extend `tests/backrooms_cell_ceiling_collision_test.gd` with a second real production runtime scenario for Level 5.
- Use the deterministic Level 5 spawn fixture at cell `(0, 2)`, whose current spawn algorithm selects `deathmoth`.
- Prepare the actual 5×5 radius-two production window and locate the spawned `CharacterBody3D` through its `backrooms_entity_id` metadata.
- Verify the Deathmoth collision proxy and the cell ceiling are disabled while the destination is staged.
- Activate the runtime and verify the Deathmoth uses the production entity collision layer/mask and its spherical collision shape is enabled.
- Move the live Deathmoth upward and verify its own production collision mask is blocked by the cell's ceiling `WorldCollision` body.
- Move a separate player-layer CharacterBody3D probe through the cell and verify it physically collides with the live Deathmoth.

## Files

- `tests/backrooms_cell_ceiling_collision_test.gd` — adds Level 5 production spawn, ceiling contact, and player-layer collision checks.
- `docs/BACKROOMS_LEVEL5_DEATHMOTH_CEILING_PLAYER_COLLISION_M0_1_102.md` — this version record.
- `.github/workflows/godot-validation.yml` — requires this version record in the existing validation input guard.

## Dependencies and import

- Parent PR #409 exact HEAD: `8ed2b090ce4b22140819f96c01d3b88fd451e931`.
- Existing PR #428 production ceiling and active stream-shift regression.
- Godot 4.3 root project; `BackroomsEntityDirector`, `BackroomsMazeCellRuntime`, `BackroomsEntityCollisionFactory`, `BackroomsCellNavigationFactory`, `BackroomsEntityBrain`, and `BackroomsLightingProfile`.
- Existing Level 5 roster, deterministic spawn algorithm, Xvfb/Mesa software-rendered physics runner, and root World3D physics server.
- No new external assets, plugins, autoloads, project settings, import steps, or save-schema changes. Import through the existing root Godot 4.3 project.

## Deterministic fixture

- Level 5 allows only `deathmoth`.
- The current stable spawn hash selects cell `(0, 2)` for Deathmoth (4% per-cell rule; current hash bucket is 2).
- Radius two loads 25 cells and includes the deterministic spawn cell.
- The test locates the actual production entity node instead of constructing a fake Deathmoth.

## Validation status

**Pending exact-head validation.**

- Test commit: `375217f4842e1baa7f39296c7bccd85d94d44c89`.
- The active stream-shift M0.1.101 candidate previously passed its Xvfb/Mesa test, including 3 load / 6 keep / 3 unload and post-shift ceiling collision, but that earlier run does not validate this new Level 5 scenario.
- The final candidate must complete the exact-head 20-workflow matrix and pass the Xvfb/Mesa test. No result from an earlier HEAD is reused.

## Limitations

- This tests a real production Deathmoth spawn and collision proxy, but not its AI decision-making, pursuit behavior, attack logic, damage, or player health response.
- The player is a purpose-built CharacterBody3D collision probe using the production player collision layer, not the full production player scene/input controller.
- Xvfb/Mesa is software-rendered CI evidence, not hardware-GPU, FPS, final pixel-quality, or mobile-device validation.
- No production runtime logic changes in this version.

## Next steps

1. Complete the final exact-head Full Gate and Xvfb/Mesa validation; inspect the Deathmoth ceiling/player probe output and actual engine diagnostics.
2. If successful, update PR #428, M0.1.100–M0.1.102, the asset index, and the Run 407 work record.
3. Obtain independent review for parent PR #409 before integrating #428 parent-first, then rerun the resulting exact HEAD.
4. Keep Deathmoth AI/attacks and full player-scene integration as separate follow-up work; do not claim them from collision-only evidence.