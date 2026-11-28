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

At parent PR #443 HEAD, the primary Controller mutation paths are MineralChunkController load/unload and Controller-mediated world-object capture/restore. `scripts/world.gd` routes world-save operations through Controller; `world/SurfaceWorld.gd` reads a snapshot; `WorldObjectStatefulProp.gd` exposes state without direct Registry mutation.

A broader scan of 45 production GDScript files also found `systems/UndergroundMineDirector.gd` using world-wide `WorldObjectStateRegistry.to_save_dict()/restore_save_dict()` for multi-chunk window rollback. That path is not covered by M0.3.31 and is tracked in [Issue #445](https://github.com/qaqp980520-prog/2126-Survival/issues/445). The Registry's global restore now fails closed while any chunk lease is active, but the Director can still overwrite newer unrelated object records when no lease is active. Do not treat the writer audit as complete until #445 is addressed.

The Director also uses a world-wide `MineralVeinRegistry` snapshot; Issue #445 requires a separate decision on whether that mineral snapshot needs chunk-scoped restore.

## Transaction behavior

- Load/unload rollback captures only the affected chunk's object records.
- If recovery is incomplete, the Controller locks writes/deletes for that chunk using a unique token.
- Other chunks remain writable and their newer records survive recovery.
- Only the matching token can restore the leased chunk.
- Whole-registry restore is rejected while any chunk lease is active.
- The Controller releases the lease only after crop, live-object, object-registry, terrain, and mineral participants all report successful recovery.
- Chunk restore validates the resulting complete registry against global record/property/string budgets and rejects stable-ID collisions with other chunks.

## Validation status

Exact-head PR #444 commit a2b50163237d199c2f177d4ddfd5b7af4c275e73 passed the Godot 4.3 Full Compatibility Gate: 553/553 steps, 0 failed, 0 skipped. Focused Runs 103, 104, and 105–107 also succeeded. The earlier d5d481f Full Gate failure was a test-fixture expectation error corrected in test-only commit a2b5016. Local Godot executable is unavailable; no local engine pass is claimed. No GPU, rendered FPS, Xvfb/Mesa, mobile, or target-device validation is implied.

## Limitations

- This is a recoverable Controller lifecycle barrier, not a lock-free transaction across every world subsystem.
- Direct Registry callers must respect per-chunk leases; same-chunk writes are rejected while recovery is pending.
- Chunk snapshots currently filter the record map; a dedicated chunk index is not introduced.
- UndergroundMineDirector's world-wide WorldObjectStateRegistry snapshot/restore remains a separate follow-up in Issue #445.
- MineralVeinRegistry still uses a world-wide snapshot in the Director; its chunk-scope requirements are part of Issue #445.
- Full Binder rebuild remains the correctness/recovery path.

## Next

1. Address Issue #445: scope UndergroundMineDirector's object-state rollback snapshot to planned loads and stale unloads; separately audit the MineralVeinRegistry snapshot.
2. Keep PR #444 Draft until parent #443 is reviewed/integrated and the child receives independent review.
3. After #445 is resolved, re-run the full Godot 4.3 Compatibility Gate on the integrated exact head.
