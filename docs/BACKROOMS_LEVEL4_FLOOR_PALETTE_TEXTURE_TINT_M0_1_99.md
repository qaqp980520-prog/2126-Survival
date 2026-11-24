# M0.1.99 — Apply Level Palette to Textured Backrooms Floors

## Purpose

Correct a visual-material integration defect found while reviewing the Level 4 office feature in PR #427. The production cell builder first assigned the per-level floor color, then replaced the floor mesh material with a textured carpet material whose `albedo_color` was always white. As a result, the configured Level 4 charcoal floor palette (and the existing per-level floor tints) did not reach the visible textured floor.

## Change

- In `prototypes/BackroomsPortalPlayground.gd`, the floor branch of `_make_surface_material` now copies `_cell_material_floor.albedo_color` into the carpet texture material when the palette source exists.
- The existing `backrooms_carpet.svg` texture, UV scale, filtering and floor geometry remain unchanged.
- This makes the Level 4 muted charcoal palette visible as a tint over the carpet texture and also restores the configured floor tints for Levels 1–3.
- No entity spawn rules, save payload, collision, navigation, or AI behavior changes.

## Regression coverage

- `tests/backrooms_entity_factory_geometry_test.gd` now checks each of Levels 1–4:
  - the production floor mesh and palette material both exist;
  - the textured floor still uses `backrooms_carpet.svg`;
  - the textured floor material's albedo tint exactly matches the level palette.
- A separate assertion verifies Level 4's source palette is exactly `Color(0.28, 0.31, 0.33)`.
- Existing eight-factory mesh geometry and Level 4 office-wall texture checks remain in the same Xvfb/Mesa production geometry test.

## Files

- `prototypes/BackroomsPortalPlayground.gd`
- `tests/backrooms_entity_factory_geometry_test.gd`
- `docs/BACKROOMS_LEVEL4_FLOOR_PALETTE_TEXTURE_TINT_M0_1_99.md`
- Historical feature context: `docs/BACKROOMS_LEVEL4_DULLER_DEATHMOTH_M0_1_98.md`

## Dependencies and import

- Godot 4.3 root project and existing `BackroomsPortalPlayground.tscn`.
- Existing `_prepare_maze_materials`, `_create_maze_cell`, and `_make_surface_material` code paths.
- Existing `assets/textures/backrooms_carpet.svg` and `assets/textures/backrooms_level4_office_wallpaper.svg`.
- No new external dependencies or imported asset formats. The root project's existing Godot import step handles the SVG texture.
- No new project settings or save-schema migration.

## Validation status

Exact-head GitHub Actions validation is required after the final documentation commit. The production geometry test runs with Xvfb/Mesa llvmpipe because it instantiates real MeshInstance3D nodes. Do not mark this asset accepted until the updated exact HEAD passes the full Godot 4.3 Compatibility Gate and the focused Backrooms geometry validation, and the full log is audited.

## Limitations

- The regression checks material resources and tint values, not rendered pixel color or color-management output.
- Xvfb/Mesa software rendering is not hardware-GPU, target-device, FPS, or iPhone validation.
- Duller and Deathmoth remain static visual prototypes in the legacy portal playground; their AI, collision proxies, navigation, attacks, pursuit, and entity-specific persistence are outside this version.

## Next steps

1. Complete exact-head Godot 4.3 validation and inspect the production geometry test output.
2. Update PR #427 and the Notion version/work records with the final commit and CI evidence.
3. Obtain independent review, then integrate parent-first through #425 → #426 → #427, synchronizing each parent and rerunning exact-head validation before any integration.
