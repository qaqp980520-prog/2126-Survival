# M0.1.36 — SurfaceWorld Portal Runtime Reconciled on Validated Spawn Window

## Purpose

Reconcile the SurfaceWorld-owned Backrooms portal runtime/persistence work from PR #339 onto the exact-head validated PR #337 spawn-window parent, while retaining all parent RNG/CI hardening and fixing portal retirement ordering when the loaded window is incomplete.

## GitHub delivery

- Branch: integration/backrooms-portal-runtime-on-validated-parent-2026-11-16.
- Parent PR #337 exact HEAD: d513ba43429aa0aa831e5ecd1334a12f6eaae275.
- Ported PR #339 source head: ff690871a42846c1ae59e72e10605d01fe61bf5d.
- The existing PR #339 branch is retained for audit; this integration branch is based on the validated parent and ports the six PR #339 changed paths plus the owner-chunk lifecycle regression.
- PR #376 targets PR #337's feature branch only. No main merge.

## Runtime and persistence

- SurfaceWorld owns a world-seed-bound BackroomsPortalDirector and ticks it only on the surface while streaming is stable.
- Spawned portals use a production Area3D visual/interaction anchor; headless tests retain the script-backed physics proxy without renderer-only meshes.
- Portal activation remains explicitly locked until a real Backrooms destination runtime can be staged and activated atomically.
- Save envelope remains optional schema v1, bound to exact world seed and Director state; no outer WorldSession schema change.
- Save fails closed during pending streaming, with any required surface chunk missing, with stale director seed identity, or when an active portal lies outside the loaded window.
- Restore validates a detached Director candidate and commits it only after base world/mine/inventory/stamina/quick-use restoration and actual loaded-window configuration succeed. Failure rolls back the full prior world snapshot.

## Loaded-window and retirement contract

- Inherit PR #375's exact validated implementation: reject pending streaming, invalid/freed dependencies, non-finite coordinates, unsafe grid coordinates, invalid/non-positive chunk dimensions, load radius outside 0–8, and any absent expected surface/chunk_x_z ID.
- Failed reconfiguration leaves the existing Director spawn policy unchanged.
- Runtime refresh checks an active portal's owning chunk before attempting to configure the full replacement spawn window. If the owner chunk is absent, retire/remove the visual first, preserve portal serial, and schedule the normal next interval. If the owner chunk remains loaded but another window chunk is missing, keep the existing portal while blocking tick/spawn/reconfiguration.
- Production regression unloads the active portal's owner chunk while the surrounding window is incomplete, verifies visual/state retirement and serial stability, then reloads the chunk and verifies bounds/runtime recovery.

## Files

- world/SurfaceWorld.gd
- tests/production_surface_world_test.gd
- systems/BackroomsPortalDirector.gd
- systems/BackroomsPortalVisual.gd
- tests/backrooms_portal_director_test.gd
- docs/BACKROOMS_SURFACEWORLD_PORTAL_RUNTIME_PERSISTENCE_M0_1_9.md
- docs/BACKROOMS_SURFACEWORLD_PORTAL_RUNTIME_RECONCILIATION_M0_1_36.md

## Dependencies and import

- Godot 4.3; validated PR #337 parent.
- Existing SurfaceWorld streaming director/chunk controller, WorldSessionController, camera interaction router, and PR #331–#332 transaction foundation.
- No third-party packages, new autoloads, input mappings, or new scenes.
- Import: godot --headless --path . --import.
- Focused tests:
  - godot --headless --path . --script res://tests/production_surface_world_test.gd
  - godot --headless --path . --script res://tests/backrooms_portal_director_test.gd

## Validation and limitations

- Parent PR #337 exact HEAD passed Godot 4.3 Full Gate: 554/554, 0 failures, 0 skipped; full 7.67 MB job-log scan found zero timestamped runtime Godot diagnostics.
- This reconciled branch requires its own exact-head focused and Full Compatibility Gate; no pass is claimed before CI completes.
- Historical PR #339/#340 green workflows contained signed-64-bit Godot errors and are not accepted as clean evidence; the strict parent parser and CI guard now apply.
- Local Godot executable unavailable; engine tests run through GitHub Actions.
- GPU visuals, final portal appearance/Z-fighting, iPhone, chunk pin/retire stress, target-device performance, and actual Backrooms destination activation remain unverified.

## Next steps

1. Complete PR #376 exact-head focused and Full Gate CI, then scan the complete job log.
2. Only after #376 passes, close PR #339 as superseded and synchronize the underground surface-return save/restore fix from PR #340 onto this validated branch.
3. Preserve all #340 failure-atomic rollback and one-shot chunk-factory failure tests; rerun exact-head validation.
4. Keep main unchanged until independent review and parent-first integration are complete.
