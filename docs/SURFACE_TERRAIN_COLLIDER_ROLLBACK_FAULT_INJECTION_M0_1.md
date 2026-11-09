# Surface Terrain Collider Rollback Fault Injection M0.1

## Purpose

Add deterministic rollback coverage around the real SurfaceTerrainTransitionColliderManager.sync_transitions() implementation before the detached adjacency index is connected to production.

The tests use a subclass only to inject a deterministic failure at an internal staging call or at the patch activation contract. The inherited manager performs the actual candidate discovery, corner resolution, resource staging, commit decision, cleanup and managed-map preservation.

## Files

- tests/fixtures/fault_injecting_surface_terrain_transition_collider_manager.gd
- tests/fixtures/fault_injecting_surface_terrain_patch.gd
- tests/surface_terrain_transition_collider_rollback_test.gd
- .github/workflows/surface-terrain-transition-collider-rollback-validation.yml

## Coverage

1. **Edge staging failure after partial staging**: begin with two independently committed real transition bodies, change both geometries, allow the first replacement body to stage, then reject the second. Assert the manager aborts, preserves both exact old bodies and active collision layers, and releases the first staged body.
2. **Corner-cap staging failure after partial staging**: begin with a real checkerboard four-way junction and four committed cap bodies. Invert all four corner heights (0↔2), preserving the checkerboard and its midpoint while changing every cap top-height signature. Allow one replacement cap to stage, then reject the next. Assert all four old cap instances remain active and the staged replacement is released.
3. **Second-endpoint activation rejection**: begin with one committed transition body, change its geometry, make both patch transition flags inactive, allow the first endpoint to activate, then reject the second endpoint. Assert the first endpoint is rolled back, the rejecting endpoint remains inactive, the exact old managed collider remains active, and the new staged body is released.

## Test and import

Repository root, Godot 4.3:

- godot --headless --path . --editor --quit
- godot --headless --path . --script res://tests/surface_terrain_transition_collider_rollback_test.gd

The focused GitHub Actions workflow runs the same command for pull requests touching the manager, patch, binder, resolver, fixtures, test or workflow.

## Scope and limitations

- No production runtime file is changed by this test-only PR.
- The inherited real manager is exercised; only the failure point is overridden by a test fixture.
- The activation case injects rejection at SurfaceTerrainPatch.set_shared_transition_active(). It validates the manager's activation rollback path, but it is not a failure returned by Godot's internal PhysicsServer API.
- Edge/corner cases inject deterministic failure after one real resource has been staged, validating cleanup and preservation of the previously committed resource set.
- The collision_layer property assignment has no result-returning failure contract in this code path. PhysicsServer allocation/internal failure injection remains a separate engine-level limitation.
- The production full-rebuild binder remains the correctness oracle. No incremental Edge-Junction production wiring is introduced.
- No GPU, Rendered FPS, iPhone or target-device QA is claimed.

## Next

Run the focused Godot 4.3 workflow and full project compatibility gate on the exact PR HEAD. Once the parent stack is independently reviewed, use these rollback contracts when implementing the M0.2 affected-component closure and preserve-set transaction.
