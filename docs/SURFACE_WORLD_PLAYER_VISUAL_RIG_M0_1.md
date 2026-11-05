# Production SurfaceWorld Player Visual Rig M0.1.2 — Touch Look Integration

## Purpose

Replace the single capsule visual placeholder with a lightweight procedural low-poly KROLL field-suit character rig. Keep the player physics and camera contract unchanged.

## Implementation

- `world/SurfaceWorld.gd` builds a `PlayerVisualRoot` under the existing `CharacterBody3D`.
- The visual rig contains a torso/chest plate, helmet/visor, backpack, separately pivoted arms and legs, knee guards, boots and small safety accents.
- Reusable primitive mesh helpers create capsules, spheres and boxes with shared `StandardMaterial3D` materials.
- Procedural locomotion resolves five states from existing physics values: idle, walk, sprint, jump and fall.
- Walk/sprint use opposing arm/leg swing, body bob and a forward sprint lean; jump/fall use distinct arm and leg poses with smoothed transitions.
- Animation reads the existing `CharacterBody3D.velocity`, `is_on_floor()` and `_sprint_active`; it does not alter movement, stamina, carry penalties or streaming.

## Compatibility contract

- Player root remains `CharacterBody3D`.
- `CollisionShape3D` remains `CapsuleShape3D`, radius 0.35 and height 1.8.
- First-person `Camera3D` remains at local position `(0, 1.48, 0)` with its existing FOV. Desktop look remains right-mouse capture plus mouse motion. Touchscreen look uses an unhandled screen drag on the 3D viewport; UI buttons continue to consume their own touch input. Both paths share the same yaw/pitch sensitivity and pitch clamp. Helmet, visor and beacon geometry use dedicated visual layer 20, excluded from the first-person camera to prevent head/visor occlusion; external cameras can include that layer.
- No world-save schema, chunk ID, inventory, stamina, underground, input or interaction behavior changes.
- Non-headless runtime creates the actual MeshInstance3D meshes. The headless regression invokes the same builder but uses metadata-only Node3D descriptors, avoiding dummy-renderer mesh creation while verifying the hierarchy and primitive geometry types.

## Files

- `world/SurfaceWorld.gd`
- `tests/production_surface_world_player_visual_test.gd`
- `tests/production_surface_world_touch_look_test.gd`
- `.github/workflows/godot-validation.yml`
- `.github/workflows/surface-world-player-visual-validation.yml`
- `docs/SURFACE_WORLD_PLAYER_VISUAL_RIG_M0_1.md`

## Dependencies and import

- Root Godot 4.3 project and existing `world/SurfaceWorld.tscn`.
- No external model, texture, plugin, import step or third-party asset is required; all meshes/materials are generated at runtime.
- Import and test from repository root:

```bash
godot --headless --path . --editor --quit
godot --headless --path . --script res://tests/production_surface_world_player_visual_test.gd
godot --headless --path . --script res://tests/production_surface_world_touch_look_test.gd
```

## Validation and limitations

- The focused player-visual regression checks player root/collision/camera invariants, confirms the first-person camera excludes helmet layer 20, verifies head-geometry layer assignments, rig node structure, all five state-resolution cases and representative pose transitions.
- The touch-look regression dispatches synthetic `InputEventScreenDrag` input through the production unhandled-input path, verifies yaw/pitch updates, both pitch limits and unchanged mouse-look behavior.
- Full Godot 4.3 compatibility CI also runs the existing SurfaceWorld integration, carry movement, stamina, streaming, save/restore and interaction suites.
- Headless CI verifies structure and deterministic pose logic, not rendered materials, silhouette, shadows, camera clipping or mobile GPU appearance. A visual check in a non-headless renderer remains required before treating the character art as final.
- This is an in-engine procedural placeholder rig, not a final authored/rigged character asset. It can later be replaced by an imported model while preserving the pivot/state interface.
