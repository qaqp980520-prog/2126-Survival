# Run 99 — Four-way corner-cap rebind lifecycle regression

This test reuses one SurfaceTerrainTransitionColliderManager across two patch generations with identical stable IDs.

## Coverage

1. Build a 2×2 checkerboard patch set and commit four shared corner caps plus four shared edge ramps.
2. Capture weak references and instance IDs for all committed bodies and patch nodes.
3. Call clear_all(), wait for deferred frees, and verify every old cap/ramp is released.
4. Queue-free the original patches and verify their weak references clear.
5. Recreate the same stable IDs with new Node3D instances and identical height states.
6. Submit a malformed side descriptor and verify rejection leaves base collision intact and creates no partial caps/ramps.
7. Rebind the valid descriptors through the same manager and verify four new caps/four new ramps, unique instance IDs, active collision and exactly two active incident sides per patch.
8. Call clear_all() again and verify base collision and side ownership are restored.

## Run

From the root Godot 4.3 project:

godot --headless --path . --script res://tests/surface_terrain_corner_cap_rebind_lifecycle_test.gd

No production geometry or world-save schema changes are made. This is a lifecycle regression for stable-ID reuse after streamed patch replacement.
