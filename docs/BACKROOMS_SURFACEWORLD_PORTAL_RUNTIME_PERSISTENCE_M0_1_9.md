# M0.1.9 — SurfaceWorld Portal Runtime and Persistence

## Purpose

Integrate the Backrooms portal director into the production SurfaceWorld lifecycle while preserving deterministic saves and safe chunk-streaming ownership. A portal can appear as a real 3D interaction anchor, but activation deliberately remains locked until the Backrooms maze runtime and destination staging are available.

## GitHub delivery

- Branch: `feat/backrooms-surfaceworld-portal-runtime-persistence-2026-11-12`.
- Parent foundation: PR #337 — SurfaceWorld loaded-window portal director factory.
- This branch includes the SurfaceWorld portal lifecycle work from the sibling lifecycle branch plus this version's persistence hardening.
- PR [#339](https://github.com/qaqp980520-prog/2126-Survival/pull/339) is Open / Draft / Unmerged, based on PR #337; exact-head Full Gate is pending.
- No project code was merged to main; the pre-run main tree content has been restored after a temporary docs-only add/revert pair.

## Runtime lifecycle

- SurfaceWorld creates and owns one BackroomsPortalDirector seeded by `world_seed`.
- SurfaceWorld's process loop ticks the director only while the player is on the surface and no asynchronous surface stream is pending.
- A spawned portal gets a reusable `BackroomsPortalVisual` Area3D anchor. The world records the owning surface chunk ID and recreates or retires the visual after streaming/restore.
- If the portal's owning chunk is no longer loaded, SurfaceWorld calls `retire_portal`. Retirement removes the visual and schedules a normal future spawn interval without consuming a destination level or incrementing the portal serial.
- In headless mode the portal anchor uses the real interaction script and a physics proxy but omits renderer-only mesh nodes.
- External camera interaction routing is enabled, but `activation_enabled=false` until a real Backrooms destination runtime can be prepared and activated. A one-use portal is not consumed by this PR.

## Persistence contract

- The outer WorldSession schema remains version 1.
- The optional `backrooms_portal_director` envelope contains `schema_version=1`, the exact `world_seed`, and the full Director `to_save_dict()` state.
- SurfaceWorld records the director's seed identity separately. Serialization fails closed if the world seed changes without replacing the director.
- Serialization also fails closed while asynchronous surface streaming is pending, if any required chunk in the current 3×3 surface window is missing, or if an active portal lies outside that actual loaded window.
- Restore validates the envelope schema, world-seed match and Director save dictionary before mutating the world.
- A detached candidate director is configured to the actual restored loaded-window bounds after the base world/mine/inventory/stamina/quick-use restore succeeds. The candidate is committed only after that check succeeds.
- On successful restore, the active portal visual is recreated only if its owning surface chunk is loaded; otherwise the portal is retired safely.
- Legacy schema-1 saves without the optional portal envelope remain loadable and create a fresh director from the restored world seed.

## Files

- `world/SurfaceWorld.gd` — director ownership, ticking, visual creation/removal, stream lifecycle refresh, loaded-window validation, save/restore and seed identity.
- `systems/BackroomsPortalDirector.gd` — deterministic portal spawn/consume/save plus non-entry retirement.
- `systems/BackroomsPortalVisual.gd` — production interaction anchor with explicit activation lock.
- `tests/production_surface_world_test.gd` — live portal, headless proxy, save/restore, streaming retirement and rollback regressions.
- `tests/backrooms_portal_director_test.gd` — retirement contract regression.
- `docs/BACKROOMS_SURFACEWORLD_PORTAL_RUNTIME_PERSISTENCE_M0_1_9.md` — this version record.

## Dependencies and import

- Godot 4.3.
- Parent PR #337 provides the loaded-window bounds and portal spawn policy.
- PR #331–#332 provide the LocationSession/TransitionManager transaction foundation.
- Existing `WorldSessionController`, SurfaceWorld streaming, chunk controller, and camera interaction router.
- No third-party packages, autoloads, new scenes, Project Settings or input mappings.
- Import: `godot --headless --path . --import`.
- Focused test: `godot --headless --path . --script res://tests/production_surface_world_test.gd`.
- Portal director test: `godot --headless --path . --script res://tests/backrooms_portal_director_test.gd`.

## Regression coverage

- The 3×3 portal spawn bounds are accepted only while all nine required surface chunks are actually loaded.
- Unloading one managed chunk makes the bounds helper fail closed; the streaming director reloads the chunk and restores the exact bounds.
- Director ownership and world-seed identity are checked.
- Portal save is rejected during pending streaming, when the seed identity is stale, or when an active portal is outside the current loaded window.
- Save envelope schema and world-seed binding are verified.
- Active portal, RNG state, serial, countdown and spawn bounds survive save/restore.
- Wrong-seed and invalid RNG envelopes are rejected without mutating the live world/director.
- Headless SurfaceWorld tick creates a script-backed Area3D anchor without renderer-only meshes; activation remains locked.
- A restored portal whose owning chunk later unloads is retired without changing the serial and receives a valid next spawn interval.
- Existing stamina/quick-use failure injection preserves the exact portal director envelope across rollback.

## Validation status

- Exact-head Full Compatibility Gate is required before marking the PR Ready for Review.
- This environment has no local Godot executable; no local engine test is claimed.
- Graphical renderer, GPU, visual alignment/Z-fighting, and iPhone touch/performance remain unverified.
- The destination runtime is not implemented here; portal activation intentionally remains disabled.

## Next step

After exact-head Full Gate succeeds, obtain independent review and integrate the parent chain in order. Then implement hidden Backrooms runtime staging/activation, collision/visibility isolation, and a fully atomic SurfaceWorld-to-Backrooms return transaction.