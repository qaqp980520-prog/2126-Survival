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


## Run 270 — visual framing and contrast regression hardening

The previously inspected 4-by-2 montage showed that the silhouettes were technically visible but occupied too little of each 320×180 tile. Pixel analysis of the downloaded PNG measured the following bounding boxes (width × height): Window 64×63, Smiler 36×36, Hound 36×37, Skin-Stealer 30×71, Clump 44×44, Faceling 30×70, Duller 30×71, Deathmoth 68×25. The previous >3 sampled-pixel assertion was therefore too weak to act as a useful framing regression.

The child revision adds test-only, geometry-derived camera framing and stronger image assertions:

- Merge each generated MeshInstance3D world-space AABB to calculate the actual visual bounds.
- Aim at the combined AABB center instead of per-entity hand-authored target heights.
- Calculate orthographic camera size from the vertical and projected horizontal extents with a 1.45 framing margin; preserve the Window's north/west wall-facing camera direction.
- Use a neutral mid-gray smoke background so black/dark entities remain distinguishable without changing their production materials.
- Require at least 25 sampled visible pixels, a silhouette bounding box at least 10% of viewport width and 20% of viewport height, a 1.5% edge margin, and centering within 18% of viewport center on both axes.
- Disable test-stage directional shadows so shadow pixels do not inflate silhouette bounds.

Only the graphical smoke harness and this document change. Production entity geometry, material definitions, runtime spawn placement, save schema and gameplay behavior are unchanged.

The exact-head graphical and Full Compatibility jobs for this child PR must complete before this revision can be considered accepted. This is software-renderer smoke coverage only; hardware GPU and iPhone QA remain separate.


## Run 271 — directional facial-feature graphical regression

- Child validation branch: `test/backrooms-entity-eye-facing-smoke-2026-11-15`, based on PR #367 exact HEAD `888ef4899004279c720369acc679630f2372ae80`.
- Test commit: `bf583f57409b53400c9f7a2e6adb45134a11f926`.
- Changed test: `tests/backrooms_entity_visual_factory_render_smoke_test.gd`.
- Smiler and Hound smoke cameras now face local -Z, where their production eye geometry is authored; other entity framing and Window wall-facing behavior remain unchanged.
- For each of the two eyes on each entity, the test projects the actual Eye MeshInstance3D world position into the viewport and counts expected material-color pixels in a bounded neighborhood. Smiler expects warm yellow/amber pixels; Hound expects red pixels. Each eye requires at least three matching pixels.
- This is a test-only change. Production entity geometry, materials, spawn selection, runtime placement and save schema are unchanged.
- Dependencies: PR #367 smoke harness; `BackroomsMazeCellRuntime.gd`, `BackroomsEntityDirector.gd`, `BackroomsEntityVisualFactory.gd`; Godot 4.3, Xvfb and Mesa llvmpipe.
- No project import or save migration is required. The graphical job runs through the existing Godot validation workflow.
- Validation status at commit creation: pending exact-head graphical smoke and Full Compatibility Gate. No pass is claimed until both jobs complete.
- Limitations: software rendering only; hardware GPU, iPhone, transparency quality, collision, navigation, AI and animation remain outside this test.
- Next: inspect the eye-color assertions on exact HEAD, correct any camera/color-threshold issues based on CI logs, then update the PR's validation record. Keep the parent-first chain and main unchanged.


## Run 271 — graphical job routing guard

The workflow's `backrooms-visual-render-smoke` job runs on pull requests only when the PR title contains the exact phrase `graphical entity visual factory smoke` (or on workflow_dispatch). PR #368 retains this phrase in its title so the graphical eye-color regression cannot be silently skipped by the workflow condition.


## Run 271.1 — calibrate Smiler eye pixel expectation from actual render

- Exact-head graphical run #43688566014 reached the facial-feature assertions. Hound Eye_0 and Eye_1 each passed with 289 red pixels in the 17×17 sample neighborhood.
- Smiler Eye_0 and Eye_1 each returned zero pixels for the initial yellow/amber threshold. The uploaded montage was downloaded and inspected; both Smiler eyes are clearly visible but the high-emission material clips to bright neutral white under Mesa llvmpipe.
- Corrected the test-only Smiler pixel expectation to require all RGB channels >= 0.78. Hound remains red-specific. No production material or geometry changed.
- Test calibration commit: `730310e63463edda5d12e4f07f2e7cf1b1cf2db1`.
- A new exact-head graphical and Full Gate run is required; the previous graphical run is recorded as a failed threshold calibration, not a product defect. The Hound eye checks passed; Smiler eye checks are pending re-run.


## Run 271.3 — graphical workflow trigger hardening

The graphical job previously depended on the PR title phrase `graphical entity visual factory smoke`. A child PR with a different title could therefore show the graphical job as Skipped even when the changed file was the graphical smoke harness. The workflow condition now also runs the job for relevant branch families:

- `test/backrooms-*`
- `feat/backrooms-production-entity-visual-factory*`

The explicit workflow_dispatch and title-based routes remain supported. This removes the accidental title-only skip for the current Backrooms test chain while avoiding the graphical job on unrelated PRs. Workflow change commit: `47d6d56f6781c453feb46a6f0de7562fec2f93b0`.

A new exact-head run is required to validate the workflow change itself. No new pass is claimed for the updated workflow HEAD until its Full Gate and graphical job complete.


## Run 272 — eye-pixel window and camera-depth guard

- Parent PR #368 exact HEAD: `043132532e725b3a7827e6e23993a820cf2c5d12`; its exact-head workflow #43689642040 completed successfully: 559/559 repository validation steps, 560/560 GitHub job steps including setup/cleanup, 0 failures and 0 skipped.
- Parent graphical job #132737375133 passed 9/9. Smiler Eye_0/Eye_1 each produced 289 near-white samples; Hound Eye_0/Eye_1 each produced 289 red samples. All eight production entities and 58 MeshInstance3D parts rendered. All 18 focused workflows passed.
- New child PR #369 adds three guards for each of the four directional eye checks: the actual eye point must be in front of the diagnostic camera; the entire 17×17 sample window must fit inside the viewport (no edge-clamped partial windows); at least 25 of 289 pixels must match the expected eye color (raised from 3 based on the observed 289/289 exact-head result).
- Files: `tests/backrooms_entity_visual_factory_render_smoke_test.gd` and this version record. No production geometry, material, runtime, spawn algorithm, save schema or gameplay code changes.
- Dependencies/import: parent PR #368; Godot 4.3, Xvfb, Mesa llvmpipe; no asset import or save migration.
- New exact-head graphical and Full Compatibility validation is pending. Do not claim the new threshold until the child workflow completes.
- Limitations: software renderer only; hardware GPU, iPhone, transparency, collision, navigation, AI and animation remain untested.


## Run 274 — exact window-boundary contract

- PR #369 was merged into parent PR #368's feature branch at merge commit `b7b3798904766a0f7b5dd61ea12609b8cd19bb5e`. This is a feature-branch integration only; main was not modified.
- The parent PR #368 head is now `b7b3798904766a0f7b5dd61ea12609b8cd19bb5e`. The prior green checks belonged to the pre-merge head `043132532e725b3a7827e6e23993a820cf2c5d12`; revalidation is required for the new tree.
- New child work extracts the complete-window predicate into `_has_complete_eye_sample_window()` and adds ten boundary assertions: exact inclusive top-left and bottom-right positions, one-pixel overflow on each of four edges, negative coordinates, empty viewport, negative radius, and a viewport one pixel too small.
- Runtime graphical smoke still checks the four production eyes and requires a complete 17×17 viewport window before sampling. The helper prevents off-screen partial windows from being treated as valid.
- Scope: test and documentation only. No production runtime, geometry, material, spawn, save schema, or gameplay behavior changes.
- Dependencies/import: parent PR #368; Godot 4.3, Xvfb, Mesa llvmpipe; no project import, autoload, input mapping, or save migration.
- Validation at branch creation: pending exact-head Full Compatibility Gate and graphical smoke. Do not claim a pass until both complete.
- Limits: software renderer only; hardware GPU, iPhone, transparency quality, collision, navigation, AI, animation, and gameplay readability remain untested.
