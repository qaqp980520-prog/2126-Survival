# Run 96 randomized 4x4 terrain corner-cap soak

This headless regression extends production corner-cap validation from 3x3 to 4x4 patch windows.

- 12 deterministic seeded layouts.
- Six compatible checkerboards: nine adjacent junctions, 36 per-patch cap bodies and 24 shared edge ramps.
- Six mixed layouts: one seeded height perturbation; fallback must propagate through the connected junction graph.
- Reconcile every edge report against actual manager-owned ramp bodies.
- Check unique cap ownership, active collision and closed 36-vertex concave shells.
- Inject an invalid descriptor after a valid commit to prove failed preflight preserves existing cap/ramp instances.
- Verify clear_all retires generated geometry and restores every patch's base collision and shared-side ownership.

Run from repository root with Godot 4.3:

    godot --headless --path . --script res://tests/surface_terrain_randomized_corner_cap_soak_test.gd

No world-save schema migration is introduced.
