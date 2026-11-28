# M0.3.30 — Cross-system Chunk-unload Rollback Reporting and Recovery

## Purpose

Close the unload-side gap in the Controller/Director recovery barrier. Before this change, a world-object registry snapshot restore could fail during chunk unload, but the Controller only emitted an error and returned false. The Director then attempted more unload/load compensation calls even though the Controller could already be in an inconsistent state.

## Files

- `systems/MineralChunkController.gd` — records unload failure phases, verifies world-object registry restoration, queues exact retry snapshots, and routes terrain-adjacency recovery through the existing lifecycle barrier.
- `systems/MineralGridStreamingDirector.gd` — synchronous and asynchronous stale-unload paths stop further compensation when the Controller reports pending lifecycle recovery; the report marks deferred work explicitly.
- `tests/mineral_chunk_controller_test.gd` — injects a registry write that commits and then rejects, followed by a failed snapshot restore; verifies the barrier, exact recovery, and retry of the same chunk.
- `tests/mineral_grid_streaming_director_test.gd` — verifies the Director does not issue a second compensating unload while the Controller barrier is active and reconciles the actual loaded set after recovery.
- `docs/MINERAL_CHUNK_UNLOAD_CROSS_SYSTEM_ROLLBACK_RECOVERY_M0_3_30.md` — this record.

## Dependencies

Godot 4.3; MineralChunkController, MineralVeinRegistry, MineralChunkLifecycleAdapter, WorldObjectStateRegistry, SurfaceTerrainAdjacencyBinder, MineralGridStreamingDirector. Parent candidate: PR #442 / M0.3.29.

## Import / integration

No new import step, package, plugin, scene, autoload, Project Settings, or save-schema migration. Existing scripts and test files are loaded by the project. Controller uses the existing `recover_failed_chunk_load()` entry point as the lifecycle recovery API to preserve caller compatibility.

## Behavior

- Every unload-side world-object snapshot rollback result is checked.
- A registry snapshot restore is considered successful only when the method returns true and a fresh `to_save_dict()` exactly matches the snapshot.
- Live world-object restoration now verifies the node's read-back state after `apply_world_object_state()`; crop restoration verifies the registry payload after restore.
- If a registry implementation mutates its records and then returns false, a failed snapshot restore creates a fail-closed recovery barrier and retains the exact pre-unload registry snapshot.
- Binder failures distinguish non-mutating preflight rejection from possible live-state mutation. Full adjacency refresh is attempted only when needed; failed refresh is included in the recovery barrier.
- Mineral batch-unregistration rejection reports its participant status and checks both object-registry and terrain restoration.
- The existing recovery method retries the object-registry snapshot and/or terrain adjacency before clearing the barrier.
- Director synchronous and asynchronous stale-unload failures do not attempt additional compensation while the Controller barrier is active. They publish the Controller report and mark new-load rollback and stale restoration as deferred. `recover_to_world_position()` then asks the Controller to recover, reconciles actual loaded IDs, and retries the requested window.

## Validation

- Controller regression: injected post-commit rejection plus one failed restore must leave the chunk owned, report `rollback_complete=false`, block further load/unload, then restore the exact object registry snapshot and allow the same chunk to unload successfully.
- Director regression: a pending Controller unload-recovery barrier must stop compensating unload calls; explicit recovery must reconcile the actual Controller IDs and finish the requested active window.
- Run the exact-head Godot 4.3 Full Compatibility Gate and the focused Controller/Director workflows. Inspect the full log; do not rely on prior-head evidence.

## Limitations

- This extends the existing Controller recovery API and is not a lock-free global transaction across every world subsystem.
- Direct callers still need to call `recover_failed_chunk_load()` after a failed unload report indicates recovery is required; the Director does this through `recover_to_world_position()`.
- Full Binder rebuild remains the correctness/recovery path. No incremental-adjacency equivalence is claimed.
- Local Godot executable is unavailable in the current working environment; CI is the executable Godot 4.3 headless validation. No GPU, rendered FPS, Xvfb/Mesa, mobile, or target-device validation is claimed.

## Next

1. Complete exact-head Focused and Full Compatibility Gate workflows.
2. Review the full Godot log and warning classifications.
3. Obtain independent review for parent PR #442 and this child PR.
4. After approval, integrate the parent/child chain in order and rerun validation on the resulting main candidate.
