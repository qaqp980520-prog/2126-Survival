# Run 97 — Extended randomized 4×4 terrain corner-cap soak

Godot 4.3 root-project test command:

    godot --headless --path . --script res://tests/surface_terrain_randomized_corner_cap_run97_60_layout_soak_test.gd

## Deterministic coverage

- Five fixed seeds: 0x970001 through 0x970005.
- Twelve 4×4 layouts per seed: six compatible checkerboards and six mixed layouts.
- Total: 60 layouts, 30 compatible and 30 mixed.
- Each mixed layout perturbs 2–4 distinct cells, not just one, forcing the resolver to handle multiple incompatible patches across the connected 3×3 junction graph.
- Compatible layouts retain the nine-junction / 36 unique cap / 24 shared ramp contract.
- All layouts reconcile active/blocked required transitions, cap ownership, collision shells, fallback propagation and clear_all restoration.
- Equal-height flush joins are deliberately excluded from transition candidates and active/blocked ramp counts; the test asserts they create no redundant ramp body.
- The first layout injects an invalid descriptor after a valid commit and verifies the previous geometry and ramp instance survive failed preflight.

This is an expanded deterministic regression harness for existing production geometry. It does not change terrain geometry, collision ownership or world-save schema 1. The fixed seed batch is repeatable; renderer/GPU seam inspection remains separate.


## Historical baseline note — Run 99

The original 60-layout Run 97 script is preserved as `tests/surface_terrain_randomized_corner_cap_run97_60_layout_soak_test.gd`. The extended file `tests/surface_terrain_randomized_corner_cap_extended_soak_test.gd` now represents the Run 99 120-layout version with 2–8 mixed-cell perturbations.
