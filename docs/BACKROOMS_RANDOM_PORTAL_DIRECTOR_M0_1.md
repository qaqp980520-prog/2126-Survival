# Backrooms Random Portal Director M0.1 — 2026-10-26

## Purpose

Provide a testable, isolated rules module for the confirmed world rule: natural Backrooms portals appear randomly in the surface world, and the destination is not selected by a fixed exit door. This is a director/model, not yet a node wired into the M1.3 world controller.

## Implemented

- Random spawn countdown of 45–75 seconds (seconds supplied by the caller; production should pass real elapsed time).
- Spawn candidate constrained to configured world bounds with a 16-unit edge margin and a configurable minimum distance from the player.
- If no safe point can be found after 64 attempts, schedule a 5-second retry rather than placing an invalid portal.
- One active portal at a time; consuming the active ID is single-use and chooses a destination from Level 0–3.
- Versioned JSON-compatible save payload for the countdown, serial, and active portal position.
- Strict atomic save validation: unsupported schema, fractional/invalid IDs, non-finite values, invalid position arrays, and positions outside the configured bounds are rejected without mutating live state.

## 3D visual shell and test status

A separate reusable scene now exists at systems/BackroomsPortalVisual.tscn with BackroomsPortalVisual.gd: emissive torus, translucent front/back field quads, Area3D trigger, E interaction prompt, and a configure_from_director() coordinate adapter. It emits portal_entered(body, portal_id); the world controller still owns director consumption and level switching.

Godot 4.3 headless CI run #15 passed the director logic tests on 2026-10-25T23:01:53Z (UTC). A new scene smoke test has been added after that run and is awaiting the next CI run. The local environment still has no Godot executable. The scene test checks resource parsing, required nodes, coordinate mapping, and invalid configuration rejection; it does not prove the visual is polished or the world transition is integrated.

## Dependencies and import

- Godot 4.3+; no add-ons or external assets.
- Logic script: systems/BackroomsPortalDirector.gd.
- Visual scene: systems/BackroomsPortalVisual.tscn; visual script: systems/BackroomsPortalVisual.gd.
- In a Godot project, preload as: const PortalDirector = preload("res://systems/BackroomsPortalDirector.gd"); instantiate the visual scene when the director returns event == spawned.
- Call tick(delta_seconds, player_position) from the world controller. On event == spawned, call configure_from_director(result.portal, ground_y) on the visual scene. Connect portal_entered and call consume_portal(portal_id), then switch to destination_level only if ok is true.
- Save/restore through to_save_dict() and load_save_dict(); the caller must merge this payload into the existing world-save envelope rather than replacing unrelated M1.3 fields.

## Compatibility and limitations

- The class is independent of SurvivalInventory and does not mutate inventory, weight, hotbar, or player state.
- The active portal remains until consumed; no automatic despawn timer is invented because portal lifetime is not yet a confirmed world rule.
- Destination pool is a small prototype list (Level 0–3), not a complete Backrooms catalogue.
- Spawn coordinates use a Rect2 world-plane abstraction; the visual shell is not yet spawned by the M1.3 world controller. Audio, effects, multiplayer authority, and iPhone UI remain integration work.
- The random generator state itself is not serialized, so post-load future random outcomes are not guaranteed to reproduce the pre-save sequence.

## Next step

Wire the director and visual shell into the M1.3 world controller only after confirming the controller source and adding an integration smoke test for world entry/return, inventory preservation, and world-save round-trip.
