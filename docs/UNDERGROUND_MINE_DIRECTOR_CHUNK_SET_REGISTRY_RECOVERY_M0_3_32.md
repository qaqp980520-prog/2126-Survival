# M0.3.32 — Underground Director Chunk-Set Registry Recovery

## Purpose

Remove world-wide Registry rollback from `UndergroundMineDirector`. A failed multi-chunk window transition must restore only the chunks involved in that transition and preserve newer writes to unrelated loaded and unloaded chunks.

## Files

- `systems/WorldObjectStateRegistry.gd`: deterministic multi-chunk snapshot, validation, and restore; merges selected records into the current Registry and validates global budgets before commit.
- `systems/MineralVeinRegistry.gd`: chunk-set mineral snapshots and exact restoration; merges only selected records, refreshes unrelated loaded veins from their current live state, preserves unrelated unloaded records, preflights live nodes, and restores live-node state if apply fails.
- `systems/UndergroundMineDirector.gd`: computes the complete affected chunk set before mutation; captures both scoped snapshots; resolves Controller recovery barriers before compensation; restores the two Registry scopes as a compensated pair; stops stale-root restoration after the first failed load.
- `tests/world_object_state_registry_test.gd`: multi-chunk capture/restore, selected-chunk rollback, unrelated-write preservation, foreign-record rejection, duplicate-ID rejection, and rejection while a selected chunk write lease is active.
- `tests/underground_mine_director_test.gd`: deterministic factory-failure injection that commits newer object state, an unrelated loaded mineral update, and an unrelated unloaded mineral update after the Director snapshot; verifies all three survive rollback.

## Dependencies

Godot 4.3; UndergroundMineDirector; MineralChunkController; WorldObjectStateRegistry; MineralVeinRegistry; MineralMiningNode; existing Controller recovery APIs from parent PR #443 and chunk-scoped WorldObject leases from parent PR #444.

## Import / integration

No package, plugin, scene, autoload, Project Settings, or save-schema migration. Existing scripts load normally. The Director now requires these Registry methods:
- WorldObjectStateRegistry: `to_chunk_set_save_dict`, `validate_chunk_set_save_dict`, `restore_chunk_set_save_dict`.
- MineralVeinRegistry: `to_chunk_set_snapshot`, `validate_chunk_set_snapshot`, `restore_chunk_set_snapshot`.

The chunk-set APIs use existing stable IDs with the `<chunk_id>/vein/<local_id>` convention for mineral ownership.

## Transaction behavior

- The snapshot scope is computed before mutation from only planned new chunk loads plus stale chunks scheduled for unload. Already-loaded desired chunks are excluded; a no-op window transition skips snapshot creation entirely.
- World-object restore replaces only records whose `chunk_id` is in the selected set. Unrelated records are copied from the live Registry at restore time.
- Mineral restore replaces only records whose stable-ID prefix before `/vein/` is in the selected set. Unrelated unloaded records are retained; unrelated loaded records are refreshed from their current live node before the merged Registry is validated.
- Both Registry APIs validate the complete merged payload before their commit point.
- The Director prevalidates both snapshots, captures the current object chunk set before compensation, restores object state, then restores minerals. If mineral restoration rejects, it compensates the object Registry back to its pre-compensation chunk set.
- Controller recovery is attempted before any Director compensation. If the shared Controller recovery barrier remains active, compensation fails closed.
- Stale chunk restoration stops at the first failed candidate instead of continuing to issue operations behind a possible lifecycle barrier.
- The existing full Binder rebuild remains the correctness/recovery fallback.

## Validation status

Code and regression tests are committed to the stacked PR branch. Exact-head Godot 4.3 CI has not yet completed at this version record's creation. Local Godot is unavailable; no local engine pass is claimed. No GPU, rendered FPS, Xvfb/Mesa, mobile, or target-device validation is implied.

## Limitations

- This is a synchronous Director compensation transaction, not a lock-free transaction across all world systems.
- Mineral chunk-set restore relies on the Director's synchronous execution boundary; it does not introduce a separate per-chunk mineral write lease.
- Mineral stable-ID ownership is recognized by the `/vein/` delimiter; legacy mineral IDs outside that convention are not included in chunk-set snapshots.
- If live-node rollback itself fails, MineralVeinRegistry retains its existing pending atomic-registration recovery record and blocks further mutations.
- PR #446 is stacked on parent PR #444, which is itself stacked on #443 and #442. No PR in this chain may be merged out of order.

## Next

1. Run exact-head Godot 4.3 Focused and Full Compatibility Gates.
2. Inspect the complete Full Gate log and reconcile all warnings.
3. Keep PR #446 Draft until exact-head CI succeeds and the parent chain receives independent review.
4. After parent-first integration, verify the Director no longer calls world-wide `to_save_dict()/restore_save_dict()` for rollback.
