# Mineral Chunk Controller Radius-8 Collider Preservation Benchmark — M0.2.12.2

## Purpose

Exercise the incremental Controller/Index/Collider path at the full Radius-8 production window with non-zero real Transition Edge and Corner Cap resources. Earlier Radius-8 measurements contained 2,023 production patches and 833 descriptors but zero transition colliders, so they could not prove collider preservation or retirement at scale.

## Benchmark-only fixture

The benchmark wrapper injects four SurfaceTerrainPatch nodes into the center chunk returned by the real SurfaceChunkFactory. It uses the production PATCH_SIZE and a 2x2 checkerboard height pattern:

- NW: height 0
- NE: height 2
- SW: height 2
- SE: height 0

The four patches create four unequal-height Transition Edges around one shared Junction. The fixture seeds the production Patch script's serialized initial height/revision fields before the detached chunk root enters the tree; SurfaceTerrainPatch._ready() then creates collision nodes and builds geometry at those heights. The normal MineralChunkController load path registers the nodes; the normal SurfaceTerrainAdjacencyIndex, SurfaceTerrainAdjacencyCoordinator, scoped Patch transaction, and partial Collider transaction create the four Edge bodies and four Corner Cap bodies. No production factory or shipped world content is modified.

## Exact Radius-8 assertions

During the one-chunk eastward boundary shift:

- At least four managed Transition Edge bodies exist.
- At least four managed Corner Cap bodies exist.
- All four Edge bodies are reused.
- All four Corner Cap bodies are reused.
- No fixture Edge or Corner Cap is staged or retired.
- All four fixture Patch Node instances remain alive in the overlap.

During contraction to the shifted center chunk:

- All four fixture Edge bodies are retired.
- All four fixture Corner Cap bodies are retired.
- All four fixture Patch Node instances are released.

The existing Radius-1 real-factory seam test remains in place, including exact Collider Node identity and reciprocal endpoint-binding checks.

## Changed file

- tests/surface_chunk_production_benchmark.gd

## Dependencies and import

- Godot 4.3.
- systems/SurfaceTerrainPatch.gd.
- Existing production SurfaceChunkFactory, MineralChunkController, SurfaceTerrainAdjacencyIndex, SurfaceTerrainAdjacencyCoordinator, SurfaceTerrainTransitionColliderManager, and SurfaceTerrainCornerConflictResolver.
- No external packages, imported assets, project settings, or scene wiring.

## Validation

Required exact-head workflow:

- Production Surface Chunk Benchmark (20 JSONL records).
- Full Godot 4.3 compatibility gate.
- Existing Controller transaction and Mineral Grid streaming focused suites.

## Limitations

- The four extra patches are deterministic benchmark-only nodes in one production chunk; they are not shipped gameplay content.
- The benchmark remains headless, so GPU rendering, visible collision response, FPS, and device-specific physics performance are not measured.
- Radius-8 resource counts and reuse/retirement are measured; this fixture does not claim GPU or iPhone performance.

The fixture intentionally does not call apply_world_object_state before the root enters the scene tree: that method refreshes CollisionShape3D nodes which are created in SurfaceTerrainPatch._ready(). Initial serialized fields are set before _ready() so the production collision geometry is built from the checkerboard heights without a premature null-shape refresh.


## Exact-head log-hygiene correction — 2026-11-10

The first non-zero Radius-8 benchmark artifact (run #42805717049, artifact 13758760559) completed with 263 PASS assertions and 0 benchmark FAIL assertions, but its captured Godot log contained 20 engine ERROR lines. Each of the four fixture Patch nodes was added to the detached chunk root twice (four duplicate-parent errors at each of radii 1, 2, 3, 4, and 8). The fixture remained attached once and the measured topology/results were valid, but the log was not clean and must not be described as error-free.

Corrected in commit `9412a9a47ad7cab7dd7097a76042245ae7330608`: initialize the serialized height/revision fields before the detached root enters the scene, then add each Patch exactly once. The fixture topology and production runtime code are unchanged.

The corrected exact-head benchmark and full compatibility validation are pending. The earlier 263-PASS artifact remains the structural baseline only; it is not accepted as clean-log evidence.
