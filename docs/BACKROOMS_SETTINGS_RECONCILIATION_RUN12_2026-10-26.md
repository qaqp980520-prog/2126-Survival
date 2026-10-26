# Backrooms settings reconciliation — Run 12

Date: 2026-10-26

## External-state discrepancy

The latest GitHub main (commit c66d436900b6156cd335996ee099f8b71809f6ff) no longer matched the Run 11 settings integration test assumptions. The actual playground used a ShadowsButton and a transient shadows_enabled field, while BackroomsSettingsProfile persists high_graphics. The integration test expected GraphicsButton and _toggle_graphics_quality, and cast the current SVG-backed StandardMaterial3D to ShaderMaterial. This mismatch would make the full validation fail even though the previous Run 11 closeout had reported the older state.

## Fix in PR #53 candidate

- Unify the UI toggle around the persisted high_graphics setting and _toggle_graphics_quality.
- Update GraphicsButton label and status text from the same persisted value.
- Rebuild the currently streamed maze after changing quality so reduced detail, light density and deterministic local shadow selection are actually applied to newly created cells.
- Set each non-headless ceiling light's shadow_enabled using _should_enable_light_shadows(cell), rather than forcing all lights to have shadows disabled.
- Keep fluorescent flicker automatic; no user-facing flicker toggle is added.
- Update the integration test to validate the actual SVG-backed StandardMaterial3D textures and UV mapping (uv1_triplanar=false), matching the latest main wallpaper UV fix.

## Validation

The changes are included in PR #53's Godot 4.3 workflow. Exact-head CI must complete successfully before merge. No local Godot binary or graphical playtest is available in this environment.

## Limits

The UI toggle and material properties are covered by headless integration tests, but real GPU shader/texture appearance and iPhone performance still require graphical/device validation.
