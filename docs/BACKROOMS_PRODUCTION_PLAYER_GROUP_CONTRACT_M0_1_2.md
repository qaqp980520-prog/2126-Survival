# Production SurfaceWorld Player Group Contract — M0.1.2

## Purpose

Establish the production player-group invariant required by world-transition Area3D triggers. The Backrooms portal prototype accepts bodies in the shared `player` group, while the production `SurfaceWorld` previously created its CharacterBody3D without joining that group.

## Changes

- `world/SurfaceWorld.gd`: the single production CharacterBody3D is parented to SurfaceWorld and then added to group `player` exactly once.
- `tests/production_surface_world_test.gd`: asserts that the production player exists and belongs to group `player` in the actual `world/SurfaceWorld.tscn` scene.
- No second player, bridge, session, input binding, collision mask, scene transition, or save-schema behavior is introduced by M0.1.2.

## Dependencies and import

- Root Godot 4.3 project; built-in SceneTree groups only.
- No third-party packages, add-ons, autoloads, or Project Settings changes.
- Import: `godot --headless --path . --import`.
- Focused test: `godot --headless --path . --script res://tests/production_surface_world_test.gd`.

## Branch and validation

- Branch: `feature/backrooms-production-player-group-contract-2026-11-12`.
- Base: `main`.
- The original M0.1.2 HEAD `ee914d6b68e2689eedbe6463361608af556df7aa` completed exact-head Godot 4.3 Full Compatibility Gate [Run #43135100823](https://github.com/qaqp980520-prog/2126-Survival/actions/runs/43135100823): 553/553, 0 failures, 0 skipped.
- M0.1.3 subsequently removed an earlier redundant pre-parent `add_to_group` call; the surviving registration is after `add_child(player)`.
- The current PR HEAD has additional M0.1.3 changes and requires its own exact-head gate; the earlier pass does not certify the newer HEAD.

## Integration boundary

M0.1.2 only establishes the production player-group invariant. Portal camera targeting, portal interaction dispatch, safe ground/stream ownership, transition lifecycle, and atomic Backrooms state integration are separate milestones.

## Next step

Complete the M0.1.3 exact-head Full Compatibility Gate and obtain independent review. Keep PR #328 unmerged until both succeed.
