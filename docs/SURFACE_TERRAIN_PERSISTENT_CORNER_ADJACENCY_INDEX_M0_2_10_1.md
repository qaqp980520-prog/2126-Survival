# Surface Terrain Persistent Corner/Junction Adjacency Index — M0.2.10.1

## Status

Implementation and focused regression are committed on the child branch of PR #303. Exact-head Godot 4.3 validation is pending; no test pass is claimed until the workflow completes on the final HEAD.

## Goal

Replace the per-delta reconstruction of the complete Edge↔Junction report graph with a persistent, clone-on-write graph owned by SurfaceTerrainAdjacencyIndex. The index now retains canonical descriptors and resolver reports across generations, updates only reports belonging to touched Stable IDs, and computes affected closure over the union of committed and candidate topology.

This is the first implementation slice of the M0.2.10 design. It does not yet wire the index into MineralChunkController or publish Index/Patch/Collider state through one production coordinator.

## Files

- systems/SurfaceTerrainAdjacencyIndex.gd — persistent descriptor cache, per-Stable-ID corner reports, Edge↔Junction graph, copy-on-write graph delta, union closure, and generation reservation API.
- tests/surface_terrain_adjacency_index_test.gd — checkerboard two-Junction closure, unrelated-edge exclusion, old/new report and descriptor projections, generation reservation, stale-plan rejection, release and full-Binder parity.
- .github/workflows/surface-terrain-adjacency-index-validation.yml — Godot 4.3 exact project import and index regression workflow; now watches resolver/planner dependencies and checks the new APIs.
- This document records the implementation boundary and acceptance contract.

## Persistent graph model

The index owns:

- _descriptors_by_edge_key: committed complete descriptor map.
- _corner_reports_by_stable_id: resolver reports produced by transition-required edges, grouped by the Patch Stable ID that owns each corner report.
- _edge_to_junctions: Edge Key to Junction Keys.
- _junction_to_edges: Junction Key to Edge Keys.
- _edge_junction_refcounts: reference counts for report-to-edge/junction links, preventing one report removal from deleting a link still referenced by another report.

Rebuild performs one full descriptor build and one graph build. A delta then:

1. Computes the existing touched Stable ID set from changed IDs and old/candidate cardinal neighbors.
2. Builds old and candidate local descriptors only for those touched IDs.
3. Runs the corner resolver over those local descriptors and retains candidate reports only for touched IDs.
4. Shallow-copies the graph dictionaries; only arrays for graph keys being changed are duplicated before mutation.
5. Removes old touched reports and adds candidate touched reports using reference-counted links.
6. Replaces descriptor keys incident to touched IDs while preserving descriptor records outside that neighborhood.
7. Traverses the union of committed and candidate Edge↔Junction graphs from the exact affected Edge seeds.
8. Returns exact old/new closure descriptor and report projections in the delta summary.

The union traversal deliberately includes removed old links and newly added candidate links. This prevents a topology split from losing the old component before the transaction has staged all resources that must be retired.

## Generation reservation

New API:

- reserve_delta(plan_id) — reserves the current committed generation for one coordinator transaction.
- release_delta_reservation(plan_id) — releases the reservation without discarding the prepared plan.
- commit_delta(plan_id) — a different plan cannot publish while a reservation is held; successful commit publishes the descriptor cache and all graph maps together.
- abort_delta(plan_id) — aborting the reserved plan releases its reservation.
- rebuild(...) — refuses to replace the index while a reservation is active.

Other plans may be prepared while a reservation is held, but cannot publish. After the reserved plan advances the generation, those older plans are rejected as stale. This prevents a competing Index commit between participant preparation and the coordinator's publication barrier.

## Public diagnostics

- get_corner_reports_by_stable_id() returns detached report copies.
- get_corner_graph_stats() returns patch/descriptor/report/Junction/link counts and reservation state.
- get_corner_graph_closure(seed_edge_keys) queries the committed graph without rebuilding the report graph.
- get_edge_descriptors() returns a detached copy of the committed descriptor cache rather than rebuilding descriptors from every Patch.

## Dependencies and import

Dependencies:

- SurfaceTerrainTransitionDescriptor.gd
- SurfaceTerrainCornerConflictResolver.gd
- SurfaceTerrainAffectedComponentPlanner.gd
- SurfaceTerrainPatch.gd and its world-object snapshot contract

No new project setting or autoload is required. The class is loaded through the existing preload("res://systems/SurfaceTerrainAdjacencyIndex.gd") call sites. The index remains a RefCounted participant and stores Patch identity through the existing WeakRef-backed records.

## Regression acceptance added

The focused index test now builds a 3×2 checkerboard with seven connected grid edges and one independent transition edge:

- Initial rebuild stores eight corner reports and two Junctions.
- A seed in the connected grid closes over exactly seven grid edges and two Junctions.
- The isolated transition edge is excluded.
- Replacing the upper-middle Patch with a same-Stable-ID Node at a new height changes three direct edges.
- The old/new union closure still contains all seven grid edges and both old Junctions.
- Old and candidate closure projections contain seven descriptors each; report projections contain eight old reports and two surviving candidate reports.
- After commit, the candidate graph contains only the two surviving reports; a candidate-only closure reaches one Junction and two edges.
- The independent descriptor remains present.
- The committed descriptor cache matches the legacy full Binder oracle.
- The committed per-Stable-ID corner report cache matches an independently executed full CornerConflictResolver oracle after both rebuild and delta commit.

Generation-reservation regressions:

- Two plans can be prepared from one generation.
- Reserving one plan blocks the other plan from committing.
- Full rebuild is rejected while a reservation is active.
- The reserved plan commits and advances the generation.
- The competing plan is then rejected as stale.
- An explicitly released reservation leaves its plan valid for a later commit.

## Limitations

- This PR adds persistent graph state to the Index but does not yet change MineralChunkController.end_terrain_adjacency_batch(); the production controller still uses the full Binder/full collider sync path.
- Candidate descriptor discovery for a load/unload delta still uses the existing touched-ID neighbor queries, but initial rebuild and any explicit full rebuild remain full-set operations.
- The graph currently models resolver reports generated from transition-required Edge descriptors; it does not replace the Corner Cap geometry resolver or collider manager.
- Index generation reservation is an API primitive; the cross-participant coordinator that reserves the Index while Patch and Collider participants prepare is not yet implemented.
- No PhysicsServer allocation-failure injection, rendered/GPU benchmark, iPhone, target-device memory, or touch QA is claimed.

## Next

Implement the coordinator that consumes plan_delta() closure projections, reserves the Index generation, prepares the scoped Patch neighbor transaction and partial Collider transaction, publishes all three participants, and retires pending Chunk roots only after every participant finalizes. Add failure injection at each publication boundary and compare every committed delta with the full Binder/full Collider oracle.
