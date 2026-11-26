# M0.3.36 — Backrooms Load-entry Recovery Preflight

## Purpose

Make the Backrooms prototype's direct file-backed load entry point reject an unresolved mineral Registry recovery before it probes, opens, or parses either the primary or backup save file.

## Authoritative base and branch

- Parent PR #449 exact HEAD: `c8ea73916be1eff208594301cc614fe58804d5de`.
- Previous PR #450 candidate HEAD before this follow-up: `544fee6a557f0cf3178707866ba6cd77686db350`.
- Backup branch: `backup/pr450-before-load-entrypoint-guard-2026-11-26-run11`.
- Updated PR branch: `fix/backrooms-save-recovery-barrier-2026-11-26-run449`.
- This remains a stacked child of PR #449. Do not merge before #449 and the parent-first dependency chain are independently reviewed and integrated.

## Files

- `prototypes/BackroomsPortalPlayground.gd`
- `tests/world_session_save_roundtrip_test.gd`
- `docs/BACKROOMS_LOAD_ENTRYPOINT_RECOVERY_PREFLIGHT_M0_3_36.md`

## Implementation

- Add a recovery-barrier preflight at the very beginning of `load_game()`.
- Return before `FileAccess.file_exists()`, opening, parsing, backup fallback, corrupt-primary promotion, or any world restore while the barrier is pending.
- Keep the existing guard in `load_world_state_from_dictionary()` as defense in depth for direct dictionary callers.
- Keep `save_game()` guarded through `serialize_world_state()`.
- Keep the atomic writer, primary/backup format, save schema, and normal recovery behavior unchanged.

## Regression coverage

Extend `tests/world_session_save_roundtrip_test.gd` to verify:

- Missing MineralVeinRegistry fails closed.
- A Registry without the recovery-state API fails closed.
- Missing Registry/API blocks serialization, direct file save, and direct file load.
- Pending atomic-registration recovery blocks serialization, direct file save, direct file load, and dictionary restore.
- Primary, backup, and corrupt-diagnostic file bytes remain unchanged while blocked.
- Inventory, mineral records, crop records, player position, and portal-world state remain unchanged.
- Normal serialization resumes after the recovery fixture is cleared.

## Dependencies and import

- Existing `MineralVeinRegistry.has_pending_atomic_registration_recovery()` and `get_last_atomic_registration_report()` APIs.
- Existing Backrooms prototype `serialize_world_state()`, `load_world_state_from_dictionary()`, and atomic file writer.
- No new package, plugin, autoload, scene, Resource, project setting, or save-schema migration.
- Uses existing `res://` script paths; no manual import step.

## Scope and limitations

- This hardens the Backrooms prototype's existing `user://backrooms_playground_save.json` path only.
- The configured production main scene remains `world/SurfaceWorld.tscn`; production SurfaceWorld still has stream-state serialization but no durable disk-backed world save/load implementation. Track that separately in Issue #451.
- The recovery barrier is in-memory and does not survive process termination.
- This is a preflight guard, not a replacement for a future durable recovery journal.

## Validation

- Previous candidate HEAD `544fee6a...` completed Godot 4.3 Full Compatibility Gate run [45846287760](https://github.com/qaqp980520-prog/2126-Survival/actions/runs/45846287760): 553/553 steps successful, 0 failed, 0 skipped.
- This M0.3.36 follow-up changes the exact HEAD; its focused and full Godot 4.3 CI must be rerun before claiming final validation.
- Local Godot executable is unavailable; no local engine run is claimed.
- No GPU, rendered FPS, Xvfb/Mesa, mobile, or target-device validation is claimed.

## Next steps

- Run focused Backrooms save/load integration tests and the exact-head Full Compatibility Gate.
- Keep PR #450 Draft until exact-head CI and parent-first independent review are complete.
- Continue Issue #451 separately after PR #449 is reviewed and integrated; do not conflate prototype persistence with production SurfaceWorld persistence.
