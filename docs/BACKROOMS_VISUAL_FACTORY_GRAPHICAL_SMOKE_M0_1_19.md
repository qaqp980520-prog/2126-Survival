# Backrooms Visual Factory Graphical Smoke — M0.1.19

## Purpose

Add a real graphical-mode validation path for the production Backrooms entity visual factory and its production maze-runtime integration. The existing renderer-independent contract test intentionally runs with Godot's dummy/headless renderer and does not instantiate MeshInstance3D. This smoke test complements that contract test by running Godot 4.3 with an X11 display supplied by Xvfb and Mesa llvmpipe software OpenGL.

## Files

- `tests/backrooms_entity_visual_factory_render_smoke_test.gd`
- `.github/workflows/godot-validation.yml` (targeted graphical job appended to the existing workflow)
- This document.

## Dependencies

- Parent PR #365: `feat/backrooms-production-entity-visual-factory-2026-11-15`
- `systems/BackroomsMazeCellRuntime.gd`
- `systems/BackroomsEntityDirector.gd`
- `systems/BackroomsEntityVisualFactory.gd`
- Godot 4.3 project configured for `gl_compatibility`
- GitHub Actions runner with Xvfb and Mesa software rendering.

## Test behavior

The test refuses to proceed when `DisplayServer.get_name()` is `headless`. It uses a fixed world seed and the production `BackroomsEntityDirector` to locate deterministic spawn cells, then calls the real `BackroomsMazeCellRuntime.prepare_destination()` and `activate_destination()` path for all eight production IDs across Levels 1–5.

It also prepares Level 0 and verifies that its spawn list remains empty. For each target entity, the test verifies:

- the production runtime creates the deterministic entity root and preserves level, seed, spawn-algorithm and visual-factory metadata;
- the runtime attaches the expected `Visuals` subtree through the production factory;
- the expected number of MeshInstance3D children is present (58 target parts total across eight entities);
- every target child has a non-null mesh, at least one renderable surface, a Material override, and non-zero local bounds;
- the production cell runtime can activate the staged cell;
- the root viewport produces a non-empty rendered image with non-background pixel samples;
- each of the eight entities is isolated from the other seven and rendered separately; every isolated frame must contain its own non-background samples, preventing one visible model from masking an off-screen or invisible model;
- each isolated test root is placed at a deterministic world-space target after the production runtime has generated it; this is test-stage positioning only and does not alter production spawn data; the camera aims at an entity-specific vertical center, faces the Window's actual north/west wall normal, and zooms for full-silhouette inspection;
- the eight isolated frames are downsampled into a 4-by-2 PNG montage artifact for direct visual review;
- a PNG frame is saved to `/tmp/backrooms-visual-factory-render-smoke.png` and uploaded as a workflow artifact.

The test hides the production floor and wall meshes only in the smoke scene so the eight target entity silhouettes can be sampled without overlapping cell architecture. Production runtime and factory code are not modified by the test.

## Import and execution

No project import or asset migration is required. The existing `godot-validation.yml` workflow includes a title-gated graphical job for this PR. The job installs Xvfb and Mesa packages in the Godot 4.3 CI container, then runs:

```bash
LIBGL_ALWAYS_SOFTWARE=1 GALLIUM_DRIVER=llvmpipe \
xvfb-run -a -s '-screen 0 1280x720x24' \
godot --audio-driver Dummy --path . --rendering-method gl_compatibility \
--script res://tests/backrooms_entity_visual_factory_render_smoke_test.gd
```

The existing workflow's pull-request path filter includes `.github/workflows/godot-validation.yml`, and the graphical job is title-gated to avoid running for unrelated PRs. The job can also be run with workflow_dispatch.

## Validation status

- Source branch starts at PR #365 exact HEAD `50f878a1afc6371ec3bf0311dbbb04b4d5562111`.
- The branch contains the production-runtime graphical smoke script, targeted workflow job, and this version record.
- The exact-head graphical workflow has not completed; no graphical pass is claimed.
- The parent PR #365 headless contract gate remains independently successful at 559/559.

## Limits

This is a CI software-renderer smoke test, not a hardware GPU or mobile-device benchmark. It does not validate iPhone rendering, frame-time performance, transparency quality, production-scene Z-fighting, collision response, navigation, AI, animation, or gameplay readability. The captured image is evidence of a rendered frame, not a substitute for human visual review.

## Next steps

1. Complete the graphical smoke job on the exact PR head.
2. Inspect the uploaded PNG artifact and any renderer warnings.
3. If successful, retain this as a targeted regression gate for future production visual-factory changes.
4. Arrange hardware/device QA before integrating PR #365 through its parent-first chain (#345 → #363 → #364 → #365).
5. Keep main unchanged until independent review and required validation are complete.
