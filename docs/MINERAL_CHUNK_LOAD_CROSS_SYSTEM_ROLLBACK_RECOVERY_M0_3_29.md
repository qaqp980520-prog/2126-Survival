# M0.3.29 — Cross-system Chunk-load Rollback Reporting and Recovery

## Purpose

Close the gap where `MineralChunkController.load_chunk()` could reject a candidate after one participant's rollback had failed, while callers and `MineralGridStreamingDirector` only observed a generic `false` result. The previous Director report could therefore say `rollback_complete=true` even when a Controller participant still needed recovery.

## Files

- `systems/MineralChunkController.gd` — records per-participant rollback results, stores retryable snapshots, blocks further load/unload operations while recovery is pending, and exposes `recover_failed_chunk_load()`.
- `systems/MineralVeinRegistry.gd` — verifies live mineral-node rollback after an injected apply failure, retains exact node snapshots if verification fails, and exposes `recover_last_atomic_registration()`.
- `systems/MineralGridStreamingDirector.gd` — includes Controller recovery state in synchronous and asynchronous failure reports; `recover_to_world_position()` retries Controller recovery before reconciling the active window.
- `tests/mineral_chunk_controller_test.gd` — injects world-object, crop-registry, and mineral-registry rollback failures, then verifies retryable recovery and same-root retry.
- `tests/mineral_grid_streaming_director_test.gd` — verifies that an incomplete Controller rollback cannot be reported as a complete Director rollback.
- `docs/MINERAL_CHUNK_LOAD_CROSS_SYSTEM_ROLLBACK_RECOVERY_M0_3_29.md` — this record.

## Transaction behavior

- Controller reports include phase, error, `rollback_complete`, `recovery_required`, and participant-level results for crop registry, live world-object nodes, world-object registry, terrain adjacency, and mineral registry.
- If any participant cannot prove restoration, Controller retains the exact snapshots/references needed for a retry and raises a lifecycle barrier. Its pending-state query also reflects a Registry-level pending mineral recovery, even if that recovery was initiated outside the Controller. Further chunk loads and unloads are rejected until recovery succeeds.
- MineralVeinRegistry compares each live node against the pre-apply snapshot after a failed atomic registration. A mismatch creates a pending recovery record; direct register/unregister/restore mutations are blocked until that record is recovered.
- Director sync reports combine candidate cleanup, newly loaded chunk rollback, and the Controller's own rollback result. The async path uses the same aggregation.
- If the Controller reports incomplete rollback, the Director retains the detached candidate root together with the exact Controller owner instead of freeing nodes still referenced by a pending Registry recovery record. It releases that root only after that same Controller reports recovery complete; replacing or destroying the owner does not silently free the candidate.
- `recover_to_world_position()` invokes the Controller recovery hook first, then releases retained failed candidates, reconciles actual loaded IDs, and retries the requested window.

## Dependencies

Godot 4.3; MineralChunkController, MineralVeinRegistry, MineralChunkLifecycleAdapter, MineralMiningNode, CropPlotController/CropRegistry, WorldObjectStateRegistry, SurfaceTerrainAdjacencyBinder, MineralGridStreamingDirector. No plugin, external package, scene, autoload, Project Settings, or save-schema migration.

## Import / integration

No new import step. Existing scripts are loaded by the Godot project. The Controller and Registry methods are additive. Existing callers that only inspect the boolean return remain compatible; the Director detects the new report/recovery methods through its Controller contract.

## Validation plan

- Inject a live world-object apply failure after mutation and a crop snapshot restore failure; verify the Controller reports incomplete rollback, blocks new loads, retries all participants, and then accepts the same caller-owned root.
- Inject a mineral-node apply failure after mutation and a failed first rollback; verify the Registry retains a pending snapshot, Controller exposes the mineral participant failure, recovery restores the exact live mineral snapshot, and the same root can be retried.
- Inject a Controller-level incomplete rollback into the Director; verify both synchronous and recovery paths preserve the previous active set and never claim `rollback_complete=true`.
- Run the focused Controller and Director tests plus the full Godot 4.3 compatibility gate on the final PR head.

## Limitations

- Recovery is an explicit retry operation; it does not silently restart a rejected chunk load. A direct Controller caller must keep the same detached root alive until recovery completes, then retry it or generate a replacement. The Director retains its own factory-created candidate together with the original Controller identity while that Controller is pending; it does not free the candidate if the owner is replaced or destroyed.
- Missing candidate world-object nodes are skipped during recovery because a freed caller-owned root no longer has live objects to restore; the authoritative registry snapshot is still restored.
- This does not yet make every world subsystem (inventory, crop visuals, terrain collider resources, and all streaming participants) a single lock-free transaction. It provides a fail-closed Controller barrier and reports the rollback state of the participants currently owned by chunk loading.
- No GPU, rendered FPS, Xvfb/Mesa, mobile, or target-device validation is implied.

## Next

1. Complete exact-HEAD Focused and Full Compatibility Gate workflows and review their logs.
2. Keep PR #442 Draft until independent review is obtained.
3. Use the new reports to identify any remaining participant that can mutate without an observable rollback result.
4. Preserve full Binder rebuild as the correctness/recovery path until incremental terrain equivalence is proven.
