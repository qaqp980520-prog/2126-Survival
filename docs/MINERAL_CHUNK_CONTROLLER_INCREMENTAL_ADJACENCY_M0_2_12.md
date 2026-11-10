# Mineral Chunk Controller Incremental Adjacency Coordinator — M0.2.12

## Purpose

Connect the persistent SurfaceTerrainAdjacencyIndex, SurfaceTerrainAdjacencyScopedTransaction, and SurfaceTerrainAdjacencyCoordinator to the production MineralChunkController batch boundary.

Before this change, the synchronous streaming Director grouped chunk loads and retirements into one controller batch, but the batch still called the full SurfaceTerrainAdjacencyBinder.bind_patches() and full collider synchronization. The planner and three-participant transaction existed, but the live chunk lifecycle did not use them.

M0.2.12 changes batched chunk additions/removals to a Stable-ID delta transaction. Unaffected Patch, Edge, and Corner Cap Node instances remain eligible for preservation by the existing partial Collider manager.

## Changed files

- systems/MineralChunkController.gd
  - Owns a persistent Index, Scoped Transaction, and Coordinator for the lifetime of the controller.
  - Keeps the Index generation monotonic across full rebuild fallbacks by rebuilding the existing Index instance rather than replacing it.
  - Records per-batch added Patch instances, removed Stable IDs, and in-place Patch edits.
  - Builds deterministic remove/add arrays from the batch delta and invokes Coordinator.execute_delta().
  - Publishes the Index descriptor snapshot only after the Coordinator reports a finalized transaction.
  - Retains pending Chunk roots while a Coordinator transaction is awaiting retry.
  - Exposes has_pending_terrain_adjacency_recovery() and retry_terrain_adjacency_recovery().
  - Uses a full Binder rebuild for in-place terrain-state edits. The current Index validates the committed Patch snapshot at publish time, so same-Node state edits must not be sent through the load/unload delta path until an explicit edit reservation is implemented.
  - Reconciles the actual loaded root set through the full path after a completed rollback, then allows the Director to resume.

- systems/MineralGridStreamingDirector.gd
  - Retries retained Controller adjacency recovery before starting another synchronous window shift.
  - If the Controller reports a retained multi-participant transaction after batch close, the Director does not start a second chunk rollback batch against a still-owned transaction.
  - Reconciles the Director's managed-ID mirror after Controller recovery completes.

- tests/mineral_chunk_controller_incremental_adjacency_test.gd
  - Uses the production Controller, Index, Coordinator, Scoped Transaction, Patch, and Collider manager.
  - Verifies a chunk-window delta removes A and adds C in one transaction while preserving a disconnected D/E collider's exact Node instance.
  - Verifies an in-place Patch state edit deliberately falls back to the full Binder and advances the persistent Index generation.
  - Injects a Collider Commit failure followed by a transient Abort failure, verifies the departing Chunk root remains attached, then retries and verifies the full live root set is reconciled.

- .github/workflows/surface-terrain-controller-transaction-validation.yml
  - Adds the new production Controller integration test to the focused Godot 4.3 workflow.
  - Expands path filters and exact input checks to include the Index, Coordinator, Scoped Transaction, and Collider manager.

## Runtime flow

1. begin_terrain_adjacency_batch() clears the per-batch delta journal.
2. Each successful load_chunk() records terrain Patch additions after the Controller publishes its Stable-ID object map.
3. Each staged unload_chunk() records the departing terrain Stable IDs while keeping the old root alive.
4. Patch state-change signals are recorded separately. If any in-place edit is present, the batch uses the authoritative full Binder fallback.
5. For pure chunk load/unload batches, the Controller calls SurfaceTerrainAdjacencyCoordinator.execute_delta(remove_ids, additions).
6. The Coordinator reserves/publishes the Index generation, applies the scoped Patch neighbor delta, prepares/commits the partial Collider resource set, finalizes Patch segmentation, and finalizes the Index generation.
7. Only after the Coordinator reports success does the Controller detach and queue-free pending Chunk roots.

## Recovery contract

- If a Coordinator participant fails but cleanup completes synchronously, the Controller restores staged unloads and performs an authoritative full reconciliation before returning.
- If the Coordinator retains a pending transaction, the Controller does not cancel or free pending Chunk roots.
- retry_terrain_adjacency_recovery() retries the Coordinator first.
- A finalized retry retires pending old roots.
- A rolled-back/aborted retry restores pending old roots and runs a full reconciliation over the actual live root set, including any newly loaded roots that the Director may subsequently remove.
- The Director checks Controller recovery before opening another window batch.

## Dependencies and import

- Godot 4.3.
- Existing scripts:
  - SurfaceTerrainAdjacencyIndex.gd
  - SurfaceTerrainAdjacencyScopedTransaction.gd
  - SurfaceTerrainAdjacencyCoordinator.gd
  - SurfaceTerrainTransitionColliderManager.gd
  - SurfaceTerrainAdjacencyBinder.gd
  - SurfaceTerrainPatch.gd
  - MineralChunkLifecycleAdapter.gd
  - WorldObjectStateRegistry.gd
- No new imported textures, meshes, autoloads, project settings, or external packages.
- The Controller creates the Index/Coordinator objects at runtime; no scene wiring is required.

## Validation

Focused command:

```sh
godot --headless --path . --script res://tests/mineral_chunk_controller_incremental_adjacency_test.gd
```

The focused workflow also runs the existing Controller transaction and World Object State Registry regressions.

Full project validation remains the existing Godot 4.3 compatibility gate (554 steps), plus the production Chunk benchmark. Do not mark this version accepted until the new focused workflow and full gate complete on the exact PR head.

## Limitations

- In-place terrain-state edits intentionally use a full Binder rebuild. The Index currently treats a changed committed Patch snapshot as stale at publish time; a dedicated same-instance edit reservation/validation contract is still required before those edits can safely use the delta transaction.
- The new integration test covers disconnected Edge preservation and transient Abort recovery, but a full Radius 8 world-window benchmark with non-zero Transition Edge and Corner Cap resources is still outstanding.
- PhysicsServer allocation failure, GPU/rendered FPS, iPhone performance, and device memory remain untested.
- PR #307 is stacked on PR #306 and must remain unmerged until its parent chain and independent review are complete.

## Next step

Run the focused Controller workflow and complete 554-step Godot 4.3 gate on the exact PR head. Then extend the production integration test to a multi-Junction Radius 8 window with real Corner Cap resources and capture the actual number of preserved/staged/retired collider bodies. After that, profile the synchronous Director's end-to-end window shift on a representative hardware target.


## Exact-head integration validation corrections — 2026-11-10

The first exact-head run for PR #307 HEAD `46175ccd01339b74fc5fb26059a697fb6e2268dd` exposed three validation defects, corrected in the follow-up validation commit:

- Godot headless focused suites did not resolve the three newly referenced global script-class type names while loading `MineralChunkController.gd` through independent test entry points. The Controller now keeps these runtime-created collaborators dynamically typed and instantiates them through the existing preloaded Script constants. The parity test likewise uses its preloaded Index script without a global type annotation. This avoids a global-class-cache dependency without changing runtime object types or call order.
- The async recovery test used world X=32 while the Director's default chunk width is 64. `floori(32 / 64)` remains chunk 0, so the test did not actually shift the window. It now uses X=64 and explicitly asserts grid coordinate `(1, 0)` before checking the loaded ID.
- The production benchmark's old boundary assertion expected Collider endpoint reactivation after a full Binder clear. The incremental path intentionally does not clear unrelated endpoint bindings. The benchmark now verifies zero reactivation, exact Collider Node identity preservation, and reciprocal Patch neighbor links for the preserved seam.

The same-world full-Binder reuse fixture still expects its explicit reactivation pass; only the subsequent incremental boundary-crossing expectation changed.

Exact-head focused, lifecycle, benchmark, and full Godot 4.3 validation must be rerun after this correction. No pass is claimed for the uncorrected HEAD. PR #307 remains Draft and unmerged.


A follow-up focused run after the dynamic Controller type correction exposed one remaining global-class-cache dependency in the test fixture itself: its nested fault-injecting subclass extended `SurfaceTerrainTransitionColliderManager` by global class name. The fixture now extends `res://systems/SurfaceTerrainTransitionColliderManager.gd` directly, so the focused test resolves the exact production base script without depending on the editor's global script-class cache.


The corrected benchmark then exposed a GDScript block-scope issue in the test itself: `reuse_fixture` had been declared inside the first `if radius == 1` block and referenced from a later sibling block. It is now initialized in the enclosing radius-loop scope and assigned inside the first block, so the preserved Collider/endpoint assertions can read the same fixture after the boundary crossing.


## Radius-8 non-zero production collider fixture — M0.2.12.2

The production benchmark wrapper now injects four test-only SurfaceTerrainPatch nodes into the center chunk returned by the real SurfaceChunkFactory. The patches form a 2x2 checkerboard (height levels 0/2/2/0) using the production PATCH_SIZE, producing four real unequal-height Transition Edges and four real Corner Cap resources through the normal Controller registration and adjacency transaction path.

At Radius 8 (2,023 normal production patches plus four deterministic benchmark patches), the eastward one-chunk incremental boundary shift asserts that all four Edge bodies and all four Corner Cap bodies are reused, none are staged or retired, and all four Patch Node instances remain alive. Contracting to the shifted center asserts that all four Edge and Corner Cap resources retire and all four fixture Patch Nodes are released. The benchmark still emits 20 JSONL records; the existing Radius-1 real-factory seam test remains intact.

This is a benchmark-only fixture added by the test wrapper; SurfaceChunkFactory.gd and shipped world content are unchanged.


The Radius-8 checkerboard fixture initializes each production SurfaceTerrainPatch's initial serialized height/revision fields before the detached chunk root enters the scene tree. It does not call apply_world_object_state before _ready(), because that API refreshes CollisionShape3D nodes created by _ready(). The production Patch _ready() path therefore constructs collision geometry directly from the intended initial height levels.
