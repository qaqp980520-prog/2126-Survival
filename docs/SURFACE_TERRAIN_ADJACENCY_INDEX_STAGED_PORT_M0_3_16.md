# Surface Terrain Adjacency Index — staged port (M0.3.16)

## Purpose

Port the standalone spatial index and detached delta planner onto the current validated terrain optimization stack without importing the divergent legacy PR #352 history wholesale.

This is **Stage 1 only**: the index is not wired into `MineralChunkController`, `SurfaceTerrainAdjacencyBinder`, or `SurfaceTerrainTransitionColliderManager`. Existing production behavior remains unchanged.

## Source provenance

The staged port copies three isolated source artifacts from PR #352 HEAD `80c5e2812a0a4082ad0005fe0bce3073072047a0`:

- `systems/SurfaceTerrainAdjacencyIndex.gd` — source blob `4335060d4246e3d664d1a86572557144cf88fe04`
- `systems/SurfaceTerrainAffectedComponentPlanner.gd` — source blob `73a2f35acf42b626e3448da3d23ce40220e44b0b`
- `tests/surface_terrain_adjacency_index_test.gd` — source blob `950ccabcdeb171cf38297143488c52998d3fc056`

The old branch's `SurfaceTerrainTransitionDescriptor.gd`, `SurfaceTerrainCornerConflictResolver.gd`, and `SurfaceTerrainPatch.gd` have the same blob SHA as the current parent, so they are reused rather than copied.

## Files

New:
- `systems/SurfaceTerrainAdjacencyIndex.gd`
- `systems/SurfaceTerrainAffectedComponentPlanner.gd`
- `tests/surface_terrain_adjacency_index_test.gd`
- `docs/SURFACE_TERRAIN_ADJACENCY_INDEX_STAGED_PORT_M0_3_16.md`

Updated CI:
- `.github/workflows/godot-validation.yml`
- `.github/workflows/surface-terrain-adjacency-spatial-index-validation.yml`

## Dependencies and import

- Godot 4.3.
- Existing `SurfaceTerrainPatch.gd`, `SurfaceTerrainAdjacencyBinder.gd`, `SurfaceTerrainTransitionDescriptor.gd`, and `SurfaceTerrainCornerConflictResolver.gd`.
- No third-party packages, autoloads, scenes, Project Settings, save-schema changes, or new runtime wiring.
- Import/parse: `godot --headless --path . --editor --quit`.
- Focused test: `godot --headless --path . --script res://tests/surface_terrain_adjacency_index_test.gd`.

## Regression scope

The staged test contains 177 explicit expectation sites and compares the index's full descriptor map against the existing Binder full-rebuild oracle. It covers:

- Negative-coordinate spatial buckets and cardinal neighbor discovery.
- Stable-ID lookup, duplicate instance/Stable ID/position rejection, and mixed patch-size rejection.
- Same-Node and same-Stable-ID replacement.
- Add/remove deltas that touch only incident edges.
- Stale generation, changed patch snapshot, freed Node, and unknown-plan rejection.
- Reservation, reversible publication, rollback, finalization, and generation monotonicity.
- Corner graph closure and changed-descriptor projection parity.
- Delta profiling fields and patch-size cache behavior.

The expectation count is a source count, not a test pass count. Pass/fail is determined only by the exact-head Godot 4.3 CI run.

## Parent and PR

- Parent PR #424 exact HEAD: `f2189a144a98a0dc5dad67e05be8ff047a89c556`.
- Parent PR #424 is Open / unmerged; its exact-head Godot 4.3 Full Gate run `45330529553` completed successfully.
- This staged port is isolated on a new child branch; it does not merge or modify PR #424, PR #279, or main.

## Validation status

The exact code/test/workflow HEAD `515a51c6fb5bdc0b3bb61af3a666ec21923554db` passed:

- Focused spatial-index workflow [45573879124](https://github.com/qaqp980520-prog/2126-Survival/actions/runs/45573879124): 9/9 job steps; the new index test emitted 217 PASS, 0 FAIL, and 0 actual Godot diagnostics.
- Full Compatibility Gate [45573879369](https://github.com/qaqp980520-prog/2126-Survival/actions/runs/45573879369): 559/559 job steps successful, 78,704 PASS markers, 0 failed steps, 0 skipped steps, 0 actual Script/Parse/Runtime/ERROR/FAIL diagnostics, 0 ObjectDB leaks, and 0 Orphan StringName diagnostics.
- Full Gate log: 7,784,148 characters / 85,116 lines. The 336 raw `SCRIPT ERROR` and 336 raw `ERROR:` and 335 raw `FAIL:` matches were shell guard command echoes; after excluding command text, there were no actual diagnostics.
- 23 warnings remain: 19 filled-mode `draw_rect()` width warnings, 1 nested KROLL project warning, 1 mineral unload rollback warning, and 2 synchronous mineral registration rollback warnings. These are not claimed fixed.
- Production benchmark [45573879319](https://github.com/qaqp980520-prog/2126-Survival/actions/runs/45573879319): 21 valid JSONL records / 301 PASS / 0 FAIL / 0 engine diagnostics / 0 warning lines. Radius-8 mean adjacency batch is 213.750 ms against mean async total 391.625 ms (54.6%) on headless Intel Xeon 6975P-C / 4 visible CPUs. This is a fresh baseline, not a before/after improvement.

This document update is documentation-only and does not change the tested GDScript, test sources, or workflow definitions. The resulting PR HEAD receives its own Full Gate because the documentation path triggers validation; the final exact-HEAD result is recorded in PR #434 and the M0.3.16 Notion asset record.

No production runtime adoption or performance improvement is claimed.

## Limitations and next step

- The index is currently a standalone candidate and is not used by production chunk load/unload.
- No production benchmark is claimed from adding the index alone.
- No GPU, rendered-device, FPS, or mobile validation is included.
- After parity and delta-lifecycle tests pass, the next stage is a separate transactional coordinator/edge-delta port. Only after its commit/abort/finalize rollback tests pass should the controller and collider manager be wired to the index.
