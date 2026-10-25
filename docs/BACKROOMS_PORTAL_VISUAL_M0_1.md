# Backrooms Portal Visual M0.1 — 2026-10-26

## Asset

- Scene: systems/BackroomsPortalVisual.tscn
- Script: systems/BackroomsPortalVisual.gd
- Test: tests/backrooms_portal_scene_test.gd

## Appearance and interaction

- Emissive torus ring with translucent front/back field quads, built from Godot primitive meshes and materials; no external textures or add-ons.
- Area3D with SphereShape3D trigger; watches for a Node3D in the player group.
- Shows a Label3D prompt when the player enters the area; E emits portal_entered(body, portal_id).
- configure_from_director() validates the portal ID and Vector2 world-plane position before mapping it to 3D as Vector3(x, ground_y, z).
- The visual does not select a destination or switch scenes. The world controller must call BackroomsPortalDirector.consume_portal(portal_id) and handle the returned destination.

## Dependencies and import

- Godot 4.3+, no external assets or plug-ins.
- Preload systems/BackroomsPortalVisual.tscn, instantiate it, then call configure_from_director(result.portal, ground_y).
- The scene expects player bodies to be in the player group and to use a collision layer included by the Area3D mask.

## Test status

- A headless scene smoke test checks the Area3D, torus, two portal field meshes, trigger shape, prompt, position mapping, and rejection of invalid portal data.
- The test was added after Godot CI run #16; the next CI run is pending. Local environment has no Godot executable, so no local scene-parser/runtime claim is made.

## Limitations and next step

- This is a reusable visual shell, not a finished VFX effect: no animation, particles, audio, distortion shader, or multiplayer authority.
- E input is only accepted while a body in the player group is inside the trigger.
- Not yet instantiated by the M1.3 world controller. Add a world-level integration test before wiring it into the production scene.
