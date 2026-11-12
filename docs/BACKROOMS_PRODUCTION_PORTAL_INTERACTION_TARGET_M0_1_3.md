# Production Backrooms Portal Interaction Target Contract — M0.1.3

## Purpose

Route Backrooms portal selection and activation through the existing production SurfaceWorld camera interaction system. Preserve the production player's single identity and avoid a second portal-local E input handler.

## Runtime changes

- `world/SurfaceWorld.gd`
  - Registers the `production_surface_world` group in `_enter_tree()`, before dynamically parented portal children enter the tree.
  - Resolves a `backrooms_portal` group member as target kind `portal` without requiring MineralChunkController ownership; the existing ancestor, proxy lifetime, and queued-for-deletion checks still apply.
  - Uses the target's `get_interaction_range()` contract, preserving the common camera ray and solid-world occlusion test.
  - Shows `E ACTIVATE BACKROOMS PORTAL`; keyboard E and the existing mobile interaction button share `_interact_current_target()`.
  - The mobile button changes from CROP to PORTAL only while a portal is the validated current target.
  - Removes the redundant pre-parent player group registration; the production player joins `player` exactly once after `add_child(player)`.
- `systems/BackroomsPortalVisual.gd`
  - Joins `backrooms_portal`.
  - Exposes `interact(body)` and `get_interaction_range()`.
  - Rejects non-player bodies, invalid portal IDs, out-of-tree nodes, and activation outside 3.25 m.
  - Disables its own E handler when parented under a `production_surface_world`; the standalone playground retains its existing local E fallback.
- `systems/BackroomsPortalVisual.tscn`
  - Places the root Area3D on collision layer 2 while retaining its player body collision mask.
- `tests/production_surface_world_interaction_prompt_test.gd`
  - Attaches a headless-safe script-backed Area3D fixture (no MeshInstance3D instantiation) before the production SurfaceWorld enters the tree, proving its `_enter_tree()` ownership group is visible to the portal's `_ready()`. It then exercises target resolution outside chunk registries, prompt and touch-button state, keyboard/mobile dispatch, exactly-once signal emission, external-router suppression, range rejection, and queued-node invalidation.
- `tests/backrooms_portal_scene_test.gd`
  - In headless mode, reads the PackedScene source to verify interaction collision layer 2 and player body mask 1 without instantiating the mesh scene in Godot 4.3's dummy renderer.
  - In graphical mode, also asserts the portal group, interaction range, and standalone playground's local-router fallback.

## Dependencies and import

- Godot 4.3 root project.
- Existing SurfaceWorld camera interaction ray: interaction proxy layer 2, world-body occlusion layer 1, 5 m ray length.
- Existing portal scene and signal `portal_entered(body, portal_id)`.
- No third-party packages, new autoloads, or Project Settings changes.
- Import: `godot --headless --path . --import`.
- Focused regression: `godot --headless --path . --script res://tests/production_surface_world_interaction_prompt_test.gd`.

## Validation

- M0.1.2 prior HEAD `ee914d6b68e2689eedbe6463361608af556df7aa` passed exact-head Full Compatibility Gate [Run #43135100823](https://github.com/qaqp980520-prog/2126-Survival/actions/runs/43135100823): 553/553, 0 failures, 0 skipped.
- M0.1.3 changes are committed on the same PR branch. A new exact-head Full Compatibility Gate is required; no pass is claimed for the new HEAD until that workflow completes.
- Local Godot executable is unavailable; no local engine test is claimed.

## Deliberate scope boundary

This milestone routes the interaction and emits the existing `portal_entered` signal. It does not yet consume the portal ID in a production transition manager, spawn portals in SurfaceWorld, transfer the player into a Backrooms level, own portal/stream lifecycle, or persist Backrooms state in the WorldSession save/restore transaction. The standalone playground remains the only current signal consumer.

## Next steps

1. Run the exact-head Full Compatibility Gate and inspect the production portal interaction regression.
2. Obtain independent review; keep PR #328 Draft and unmerged until CI and review succeed.
3. Add a SurfaceWorld-owned portal lifecycle/Director that validates loaded ground and stream ownership.
4. Connect `portal_entered` to a reversible transition transaction that preserves the same player, inventory bridge, WorldSessionController, and surface return position.
5. Add save/restore and rollback regressions before enabling production portal spawning.
