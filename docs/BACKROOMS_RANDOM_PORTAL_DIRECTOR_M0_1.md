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

## Dependencies and import

- Godot 4.3+; no add-ons or external assets.
- Script: systems/BackroomsPortalDirector.gd.
- In a Godot project, preload as: const PortalDirector = preload("res://systems/BackroomsPortalDirector.gd").
- Construct with a reproducible seed and bounds for tests, or -1 for randomized seed: PortalDirector.new(-1, Rect2(-500, -500, 1000, 1000), 24.0).
- Call tick(delta_seconds, player_position) from the world controller. On event == spawned, instantiate the visual/physics portal at result.portal.position. When the player interacts, call consume_portal(portal_id) and switch to destination_level only if ok is true.
- Save/restore through to_save_dict() and load_save_dict(); the caller must merge this payload into the existing world-save envelope rather than replacing unrelated M1.3 fields.

## Test status

Godot 4.3 headless CI run #15 passed on 2026-10-25T23:01:53Z (UTC), including the portal-director regression script. The local environment still has no Godot executable. The test covers scheduling, safe bounds/distance, retry, one-time consumption, save round-trip, and atomic rejection of invalid saves; it does not cover 3D scene integration or iPhone behavior.

## Compatibility and limitations

- The class is independent of SurvivalInventory and does not mutate inventory, weight, hotbar, or player state.
- The active portal remains until consumed; no automatic despawn timer is invented because portal lifetime is not yet a confirmed world rule.
- Destination pool is a small prototype list (Level 0–3), not a complete Backrooms catalogue.
- Spawn coordinates use a Rect2 world-plane abstraction; 3D mapping, portal mesh, trigger collision, audio, effects, multiplayer authority, and iPhone UI remain integration work.
- The random generator state itself is not serialized, so post-load future random outcomes are not guaranteed to reproduce the pre-save sequence.

## Next step

Wire the director into the M1.3 world controller only after confirming the controller source and adding an integration smoke test for world entry/return, inventory preservation, and world-save round-trip.
