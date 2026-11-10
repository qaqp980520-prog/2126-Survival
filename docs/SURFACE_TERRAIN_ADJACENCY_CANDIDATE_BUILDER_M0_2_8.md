# Surface Terrain Non-mutating Candidate Descriptor Builder M0.2.8

## Purpose

Separate candidate topology discovery from live neighbor-state mutation. The partial collider transaction requires a complete candidate descriptor map, but callers must not invoke the legacy mutating Binder immediately before Prepare because that path clears and rebinds shared-transition state across the supplied patch set.

M0.2.8 exposes the exact descriptor preflight as a read-only operation and makes the existing full Binder consume the same implementation, preventing algorithm drift.

## API

`SurfaceTerrainAdjacencyBinder.build_candidate_descriptors(patches, stable_ids_by_instance={}, profile_enabled=false)`

The function:

- Validates live in-tree patches, unique instance IDs, unique non-empty Stable IDs, patch-size consistency, and persisted world-object state.
- Uses the existing tolerance-sized spatial buckets to reject duplicate positions and discover cardinal neighbors.
- Builds canonical `SurfaceTerrainTransitionDescriptor` records in deterministic pair order.
- Returns a complete descriptor dictionary plus counts and optional candidate-build timing.
- Does not call `bind_neighbor_patch()`, `clear_neighbor_edge_state()`, segmentation batch APIs, or any shared-transition mutation API.
- Returns the internal pair records only for the legacy Binder to apply after preflight; callers that only need candidate topology should consume `descriptors`.

## Full Binder compatibility

`bind_patches()` now performs the mutating-method capability preflight, calls `build_candidate_descriptors()`, then applies the returned pair records through the existing reciprocal-clear deduplication and segmentation-batch path.

The descriptor map returned by the pure builder must equal the map returned by a successful full bind for the same patch set. Existing error behavior and full-rebuild semantics remain the compatibility path.

## Files

- `systems/SurfaceTerrainAdjacencyBinder.gd` — shared pure candidate preflight and legacy bind application.
- `tests/surface_terrain_adjacency_binder_test.gd` — parity and no-side-effect assertions.
- `.github/workflows/surface-terrain-adjacency-candidate-builder-validation.yml` — focused Godot 4.3 validation.
- `docs/SURFACE_TERRAIN_ADJACENCY_CANDIDATE_BUILDER_M0_2_8.md` — this contract.

## Dependencies

- `SurfaceTerrainTransitionDescriptor.gd`
- `SurfaceTerrainPatch.gd` read-only edge profile and world-object state APIs.
- Existing spatial bucket and reciprocal clear helpers in `SurfaceTerrainAdjacencyBinder.gd`.

## Import and test

Run from repository root with Godot 4.3:

- `godot --headless --path . --editor --quit`
- `godot --headless --path . --script res://tests/surface_terrain_adjacency_binder_test.gd`

Focused workflow: `.github/workflows/surface-terrain-adjacency-candidate-builder-validation.yml`.

## Regression coverage

- A valid four-patch candidate produces the same two canonical descriptors as the legacy Binder.
- Candidate building leaves all reciprocal neighbor bindings empty before the Binder is called.
- Candidate building leaves ground ramps and collision-segmentation refresh counters unchanged.
- An invalid Stable ID is rejected by the pure builder without disturbing an already committed reciprocal neighbor pair.
- The legacy Binder returns a descriptor map identical to the pure builder and continues to apply reciprocal neighbor state.
- Existing duplicate-position, state validation, unload, reciprocal-clear deduplication, and failure-batch regressions remain in the same test suite.

## Limits

- This is a non-mutating full-candidate descriptor builder, not yet an incremental spatial-index delta query. It still validates and scans the complete supplied patch set.
- It does not update patch neighbor state for a scoped subset.
- It does not wire the partial collider API into MineralChunkController.
- The full Binder and full collider rebuild remain the compatibility/fallback path.
- No PhysicsServer internal allocation-failure injection, GPU/Rendered FPS, iPhone, target-device memory, or touch QA is claimed.

## Next

1. Use this pure builder to produce complete candidate descriptors before calling the M0.2.7 partial collider transaction.
2. Add a scoped adjacency-state apply API that changes only the old+candidate affected component.
3. Add end-to-end parity between partial Binder state, partial collider resources, and the full rebuild oracle.
4. Wire the transaction into the Chunk Controller only after scoped apply and rollback are validated.
