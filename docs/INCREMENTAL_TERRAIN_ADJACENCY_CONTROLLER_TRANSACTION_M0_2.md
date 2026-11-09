# Incremental Terrain Adjacency Controller Transaction M0.2

## Purpose

Make the existing full-rebuild terrain path rollback-safe before wiring the detached M0.1 adjacency index into production. This stage does not replace the full rebuild or change the playable load-radius policy.

## Runtime changes

- `systems/MineralChunkController.gd`
  - Capture the live neighbor links and shared-transition activation flags for the candidate patches and their direct pre-existing neighbors before the binder mutates them.
  - If the binder, transition-manager creation, or collider synchronization fails, restore the captured reciprocal links and activation flags.
  - Do not clear the committed transition-manager resources or descriptor snapshot on a failed candidate synchronization.
  - Load ordering: attach/restore candidate root, register minerals, then publish adjacency; if adjacency fails, unregister the candidate minerals before detaching the root.
  - Unload ordering outside a batch: save state and unregister minerals, commit adjacency while the departing root and patch Nodes remain attached, then remove Controller maps and queue the root for deletion.
  - Unload ordering inside an adjacency batch: save state and unregister minerals, record a pending retirement, and keep the root/maps attached. The final batch commit excludes all pending roots in one rebind, then retires them only after collider synchronization succeeds.
  - If a batch rebind fails, cancel every pending retirement, re-register minerals and restore only the departing chunk's object-state records while retaining the exact old roots and maps.
  - Director rollback checks for an already-held root first and cancels its pending retirement instead of generating a duplicate replacement root.

## Transaction invariants

1. A candidate rebind must not destroy the previous live patch-neighbor graph when validation or collider staging fails.
2. Direct neighbors outside the new patch set are captured because clearing a selected patch clears the reciprocal side on that external neighbor.
3. Shared-transition activation is restored only after reciprocal neighbor policies have been restored.
4. The old chunk root remains alive through removal-side validation and the candidate collider-manager commit.
5. The existing `SurfaceTerrainTransitionColliderManager.sync_transitions()` remains the resource owner; this change relies on its current contract that staged resources are freed and old managed bodies are retained on pre-commit failure.
6. The full-rebuild binder remains the production adjacency algorithm and correctness oracle.
7. An unload inside an async adjacency batch commits immediately while the old root is alive. That commit includes all currently published deferred loads/state changes, so it clears the dirty bit and prevents a redundant batch-end rebuild; later operations set it again. Consecutive unloads can still each force a full rebind; a pending-retire queue is a future optimization, not implemented here.

## Files

- `systems/MineralChunkController.gd`
- `systems/MineralGridStreamingDirector.gd`
- `tests/surface_terrain_controller_transaction_test.gd`
- `.github/workflows/godot-validation.yml`
- `.github/workflows/surface-terrain-controller-transaction-validation.yml`

## Dependencies

- Godot 4.3.
- `SurfaceTerrainAdjacencyBinder.gd`
- `SurfaceTerrainPatch.gd`
- `SurfaceTerrainTransitionColliderManager.gd`
- `MineralChunkLifecycleAdapter.gd`

## Import and test

From the repository root:

```sh
godot --headless --path . --editor --quit
godot --headless --path . --script res://tests/surface_terrain_controller_transaction_test.gd
```

The focused workflow runs the same test in the Godot 4.3 CI container. The full compatibility workflow also includes the regression.

## Test coverage

The fault-injected test builds three real `SurfaceTerrainPatch` nodes with two reciprocal edges and active transition sides. It attempts to unload the third patch while a fake transition manager rejects synchronization, then verifies:

- unload returns false;
- the old root remains attached and unqueued;
- both reciprocal edges, including the edge to a patch outside the candidate set, are restored;
- all four shared-transition activation flags are restored;
- the committed descriptor snapshot and world-object registry snapshot are unchanged.

The test then retries with the fake manager succeeding and verifies that the departing edge is removed, the unaffected edge remains, the new descriptor snapshot is published, and the old root is queued only after the adjacency commit.
The batch regression loads a replacement chunk and stages an old chunk for retirement, then verifies one shared synchronization commits both changes before the old root is detached. A separate injected batch-commit failure verifies that the exact old root, reciprocal adjacency, mineral registration and world-object registry snapshot are restored. Another rollback path cancels a pending retirement without creating a replacement root. A failing adapter verifies that failed mineral registration never publishes terrain adjacency.

## Limits and next steps

- Multiple unloads in one async batch now share one full-rebuild commit; the implementation still uses the full-rebuild binder rather than the detached incremental index.
- The pending-retirement queue is in-memory transaction state only and is never serialized.
- This is a Controller-level rollback stage, not the final detached-index/edge-junction transaction manager.
- The injected failure exercises the Controller's manager-failure contract; it does not simulate every real collision-shape allocation or physics-server failure.
- The full rebuild still performs global adjacency work.
- Rendered/GPU, iPhone, and target-device QA are not covered.
- Next: run exact-head focused, production benchmark and full Godot 4.3 workflows; add real manager staging/activation fault injection; then implement the edge↔junction affected-component closure and preserve-set transaction around the verified rollback boundary.
