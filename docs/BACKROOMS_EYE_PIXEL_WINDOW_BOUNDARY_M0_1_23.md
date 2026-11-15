# Backrooms Eye Pixel Window Boundary Contract — M0.1.23

## Purpose

Make the 17×17 directional-eye sampling window a separately testable boundary contract. The production graphical smoke already rejects eyes behind the diagnostic camera and rejects incomplete viewport windows. This version extracts that predicate and tests exact edge behavior so future edits cannot reintroduce off-by-one acceptance or partial-window sampling.

## Files

- `tests/backrooms_entity_visual_factory_render_smoke_test.gd`
- This version record.

## Implementation

- `_has_complete_eye_sample_window(center, image_size, radius)` rejects negative radii and empty viewports.
- A radius of 8 means a complete 17×17 window, including both endpoints.
- The graphical smoke calls the helper before sampling any expected eye-color pixels.
- Ten deterministic assertions cover:
  - exact inclusive top-left boundary;
  - exact inclusive bottom-right boundary;
  - one-pixel overflow at left, right, top and bottom;
  - negative viewport coordinates;
  - empty viewport;
  - negative radius;
  - a viewport one pixel too small for the requested window.

## Dependency and import

- Parent PR #368 branch: `test/backrooms-entity-eye-facing-smoke-2026-11-15`.
- Parent exact HEAD at branch creation: `b7b3798904766a0f7b5dd61ea12609b8cd19bb5e`, which includes validated PR #369 merged into the parent feature branch.
- Godot 4.3, Xvfb and Mesa llvmpipe for the graphical smoke.
- No project import, autoload, input mapping, asset migration or save migration is required.

## Scope

Test and documentation only. No production runtime, geometry, materials, spawn algorithm, save schema or gameplay behavior changes.

## Validation status

Pending exact-head Full Compatibility Gate and graphical smoke for this child PR. No pass is claimed until both complete.

## Limitations and next step

Software rendering only. Hardware GPU, iPhone, production transparency quality, collision, navigation, AI, animation and gameplay readability remain untested. After exact-head validation, integrate this child into PR #368 and rerun validation on the resulting parent tree before considering the next ancestor.
