# Incremental Terrain Adjacency Controller Transaction M0.2

## Purpose

Make the existing full-rebuild terrain path rollback-safe before wiring the detached M0.1 adjacency index into production. This stage does not replace the full rebuild or change the playable load-radius policy.

## Runtime changes

- `systems/MineralChunkController.gd`
  - Capture the live neighbor links and shared-transition activation flags for the candidate patches and their direct pre-existing neighbors before the binder mutates them.
  - If the binder, transition-manager creation, or collider synchronization fails, restore the captured reciprocal links and activation flags.
  - Do not clear the committed transition-manager resources or descriptor snapshot on a failed candidate synchronization.
  - Load ordering: attach/restore candidate root, register minerals, then publish adjacency; if adjacency fails, unregister the candidate minerals before detaching the root.
  - Unload ordering: save state and unregister minerals, prepare/commit adjacency while the departing root and patch Nodes remain attached, then remove Controller maps and queue the root for deletion.
  - If unload adjacency fails, re-register minerals and restore the object-state registry snapshot while retaining the old root and maps.

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
It also loads a replacement chunk inside an adjacency batch, unloads the old chunk, and verifies one immediate synchronization plus a zero-rebuild batch end. A second fault case verifies failed mineral registration does not call the transition manager or bind the candidate patch.

## Limits and next steps

- The unload path preserves batch correctness and avoids a redundant final rebuild, but multiple unloads in one batch may still perform one immediate full rebind each; a deferred pending-retire transaction is a future performance improvement.

- This is a Controller-level rollback stage, not the final detached-index/edge-junction transaction manager.
- The injected failure exercises the Controller's manager-failure contract; it does not simulate every real collision-shape allocation or physics-server failure.
- The full rebuild still performs global adjacency work.
- Rendered/GPU, iPhone, and target-device QA are not covered.
- Next: run the exact-head focused and full Godot 4.3 workflows; add real manager staging/activation fault injection; then design the edge↔junction affected-component closure and preserve-set transaction around the verified rollback boundary.
