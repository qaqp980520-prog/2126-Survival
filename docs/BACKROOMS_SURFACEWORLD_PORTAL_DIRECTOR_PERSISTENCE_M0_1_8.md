# M0.1.8 — SurfaceWorld Backrooms Portal Director Persistence

## Purpose

Make the production SurfaceWorld the owner of one world-seeded BackroomsPortalDirector and persist its complete deterministic state as part of the existing schema-1 world-session payload. This is a persistence/restore contract; it does not yet tick the director during gameplay or spawn a portal visual.

## GitHub delivery

- PR: pending creation from branch `feat/backrooms-surfaceworld-portal-persistence-2026-11-12`.
- Base: PR #337, SurfaceWorld loaded-window director factory.
- Base HEAD: `736a77d2a4243bf9d874922fdbe1eabd59946b44`.
- Files:
  - `world/SurfaceWorld.gd`
  - `tests/production_surface_world_test.gd`
  - `docs/BACKROOMS_SURFACEWORLD_PORTAL_DIRECTOR_PERSISTENCE_M0_1_8.md`

## Runtime contract

- SurfaceWorld creates and owns a single `BackroomsPortalDirector` after its initial surface window is loaded.
- The outer WorldSession schema remains version 1. A new optional `backrooms_portal` envelope contains:
  - envelope schema version;
  - the exact SurfaceWorld `world_seed`;
  - the complete PortalDirector `to_save_dict()` payload (RNG state, spawn countdown, serial, active portal and its original spawn bounds).
- Serialization fails closed if the owned director is missing, cannot provide a non-empty save dictionary, or was created for a different world seed.
- Restore builds and validates a detached candidate director using the target player position's loaded-window bounds before mutating the current world.
- The envelope seed must match the target world seed. An active saved portal must remain inside the target loaded surface window.
- The candidate director is committed only after the existing SurfaceWorld, underground mine, inventory, stamina and quick-use restore stages all succeed. Any earlier failure leaves the live director instance and payload untouched.
- Legacy schema-1 saves without `backrooms_portal` remain loadable; they receive a fresh deterministic director derived from the restored world seed.

## Dependencies and import

- Godot 4.3.
- Parent PR #337 provides `get_loaded_surface_window_bounds()`, `create_backrooms_portal_director()`, and the validated `BackroomsPortalDirector.set_spawn_window()` API.
- Existing `WorldSessionController.serialize_stream_state()/restore_stream_state()` and SurfaceWorld rollback contract.
- No third-party packages, new autoloads, input mappings, or scenes.
- Import from repository root: `godot --headless --path . --import`.
- Focused test: `godot --headless --path . --script res://tests/production_surface_world_test.gd`.

## Regression coverage

- SurfaceWorld owns a director configured for the real loaded window and current world seed.
- Saved envelope binds the director payload to the same world seed.
- Active portal, RNG state, countdown, serial and original spawn bounds survive a world save/restore round trip.
- A mismatched envelope seed is rejected before world seed, player position or live director state changes.
- Legacy schema-1 saves without the optional envelope remain loadable and do not inherit stale active portals.
- Existing stamina/quick-use failure injection confirms the detached candidate is never committed and the exact live portal director payload remains unchanged after rollback.

## Limitations

- The director is not yet ticked by SurfaceWorld's gameplay loop.
- No live portal visual is spawned or parented to a streamed chunk.
- Portal chunk retirement/pinning, interaction-to-TransitionManager handoff, hidden Backrooms runtime staging/activation, world/collision/visibility switching, and Backrooms WorldSession return integration remain future work.
- Graphical rendering, GPU, and iPhone validation remain outstanding.
- Local Godot executable is unavailable in this environment; only exact-head GitHub Actions Godot 4.3 validation can establish engine test status.

## Next step

After exact-head Full Compatibility Gate succeeds, implement the SurfaceWorld-owned portal visual lifecycle with explicit chunk ownership/retirement and connect portal interaction to a prepare-only transition handoff. Do not consume a one-use portal until a real destination runtime can be prepared and activated.
