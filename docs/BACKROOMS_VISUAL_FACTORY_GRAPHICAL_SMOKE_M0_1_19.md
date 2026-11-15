# Backrooms Visual Factory Graphical Smoke — M0.1.19

## Purpose

Add a real graphical-mode validation path for the production Backrooms entity visual factory. The existing renderer-independent contract test intentionally runs with Godot's dummy/headless renderer and does not instantiate MeshInstance3D. This smoke test complements that contract test by running Godot 4.3 with an X11 display supplied by Xvfb and Mesa llvmpipe software OpenGL.

## Files

- `tests/backrooms_entity_visual_factory_render_smoke_test.gd`
- `.github/workflows/backrooms-visual-factory-render-smoke.yml`
- This document.

## Dependencies

- Parent PR #365: `feat/backrooms-production-entity-visual-factory-2026-11-15`
- `systems/BackroomsEntityVisualFactory.gd`
- Godot 4.3 project configured for `gl_compatibility`
- GitHub Actions runner with Xvfb and Mesa software rendering.

## Test behavior

The test refuses to proceed when `DisplayServer.get_name()` is `headless`. It creates a lit 3D stage, attaches all eight production entity IDs through `BackroomsEntityVisualFactory.attach_visuals()`, and verifies:

- every production entity publishes its `Visuals` subtree;
- the expected number of MeshInstance3D children is present (58 total across eight entities);
- every child has a non-null mesh, at least one renderable surface, a Material override, and non-zero local bounds;
- the north-owned Window uses the expected orientation;
- the root viewport produces a non-empty rendered image with non-background pixel samples;
- a PNG frame is saved to `/tmp/backrooms-visual-factory-render-smoke.png` and uploaded as a workflow artifact.

## Import and execution

No project import or asset migration is required. The workflow checks out the PR candidate, installs Xvfb and Mesa packages in the Godot 4.3 CI container, and runs:

```bash
LIBGL_ALWAYS_SOFTWARE=1 GALLIUM_DRIVER=llvmpipe \
xvfb-run -a -s '-screen 0 1280x720x24' \
godot --path . --rendering-method gl_compatibility \
--script res://tests/backrooms_entity_visual_factory_render_smoke_test.gd
```

The workflow is path-filtered to the visual factory, its graphical smoke test, project renderer settings, and its own workflow file. It can also be started manually after the workflow exists on the repository's default branch.

## Validation status

- Source branch starts at PR #365 exact HEAD `50f878a1afc6371ec3bf0311dbbb04b4d5562111`.
- The branch currently contains the graphical smoke script, workflow, and this version record.
- No graphical test result is claimed until the new PR's exact-head workflow completes successfully.
- The existing PR #365 headless contract gate remains separate and continues to validate geometry/material semantics without creating MeshInstance3D under the dummy renderer.

## Limits

This is a CI software-renderer smoke test, not a hardware GPU or mobile-device benchmark. It does not validate iPhone rendering, frame-time performance, transparency quality, Z-fighting across production scenes, collision, navigation, AI, animation, or gameplay readability. The captured image is evidence of a rendered frame, not a substitute for visual review.

## Next steps

1. Complete the graphical smoke workflow on the exact PR head.
2. Inspect the uploaded PNG artifact and any renderer warnings.
3. If successful, keep this workflow as a targeted regression gate for future visual-factory changes.
4. Arrange graphical/device QA before integrating PR #365 through its parent-first chain (#345 → #363 → #364 → #365).
5. Keep main unchanged until independent review and required validation are complete.
