# M0.3.31 — Chunk-scoped WorldObject Registry Recovery

## Purpose

Harden M0.3.30 so a failed chunk rollback cannot restore a registry-wide snapshot over newer records belonging to unrelated chunks. The Controller also blocks world-save capture and whole-world object restoration while lifecycle recovery is pending.

## Files

- `systems/WorldObjectStateRegistry.gd`: chunk snapshots, chunk restore, per-chunk write leases, and global-restore rejection while a lease is active.
- `systems/MineralChunkController.gd`: chunk-scoped load/unload rollback snapshots; retained lease during incomplete recovery; world-save capture/restore barriers.
- `tests/world_object_state_registry_test.gd`: chunk isolation, foreign-record rejection, token ownership, and write-lease tests.
- `tests/mineral_chunk_controller_test.gd`: verifies unrelated chunk writes survive recovery and world-wide writers are blocked; unload fault injection now targets chunk restore.
- `docs/WORLD_OBJECT_REGISTRY_CHUNK_SCOPED_RECOVERY_M0_3_31.md`: this version record.

## Dependencies

Godot 4.3; WorldObjectStateRegistry; MineralChunkController; MineralGridStreamingDirector; WorldObjectStatefulProp; world save/restore through MineralChunkController. Parent PR #443 / M0.3.30, exact base `c7b303ba075aa0c18ebd213b0f9e3af232566785`.

## Import / integration

No package, plugin, scene, autoload, Project Settings, or save-schema migration. Existing scripts load normally. Controller binding now requires the chunk-snapshot and lease methods from the project's WorldObjectStateRegistry implementation.

## Writer audit

At the parent head, production Registry mutations are centralized in MineralChunkController load/unload and world-object capture/restore. `scripts/world.gd` routes save capture and restore through those Controller methods; it does not mutate the Registry directly. `world/SurfaceWorld.gd` reads a snapshot for transition rollback. `WorldObjectStatefulProp.gd` exposes state methods but does not write the Registry. No other production call site directly invokes Registry set/forget/restore mutation methods at this base. The registry-level lease also protects future direct same-chunk writers.

## Transaction behavior

- Load/unload rollback captures only the affected chunk's object records.
- If recovery is incomplete, the Controller locks writes/deletes for that chunk using a unique token.
- Other chunks remain writable and their newer records survive recovery.
- Only the matching token can restore the leased chunk.
- Whole-registry restore is rejected while any chunk lease is active.
- The Controller releases the lease only after crop, live-object, object-registry, terrain, and mineral participants all report successful recovery.
- Chunk restore validates the resulting complete registry against global record/property/string budgets and rejects stable-ID collisions with other chunks.

## Validation status

Pending exact-head GitHub Actions Godot 4.3 validation. Local Godot executable is unavailable; no local engine pass is claimed. No GPU, rendered FPS, Xvfb/Mesa, mobile, or target-device validation is implied.

## Limitations

- This is a recoverable Controller lifecycle barrier, not a lock-free transaction across every world subsystem.
- Direct Registry callers must respect per-chunk leases; same-chunk writes are rejected while recovery is pending.
- Chunk snapshots currently filter the record map; a dedicated chunk index is not introduced.
- Full Binder rebuild remains the correctness/recovery path.

## Next

1. Run focused WorldObjectStateRegistry and MineralChunkController tests plus the full Godot 4.3 Compatibility Gate on the exact child head.
2. Review exact-head logs and warning changes.
3. Keep the stacked PR Draft until parent #443 is reviewed/integrated and the child receives independent review.
4. Continue auditing external save/restore writers before background persistence is allowed during pending recovery.
