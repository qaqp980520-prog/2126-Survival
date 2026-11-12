# Production SurfaceWorld Player Group Contract — M0.1.2

## Purpose

Establish the production player-group invariant required by world-transition Area3D triggers. The Backrooms portal prototype accepts bodies in the shared `player` group, while the production `SurfaceWorld` previously created its CharacterBody3D without joining that group.

## Changes

- `world/SurfaceWorld.gd`: `_build_player()` parents the single production CharacterBody3D to SurfaceWorld, then adds it to group `player` before creating the remaining player components.
- `tests/production_surface_world_test.gd`: asserts that the production player exists and belongs to group `player` in the actual `world/SurfaceWorld.tscn` scene.
- No second player, bridge, session, portal, input binding, collision mask, scene transition, or save-schema behavior is introduced.

## Dependencies and import

- Root Godot 4.3 project; built-in SceneTree groups only.
- No third-party packages, add-ons, autoloads, or Project Settings changes.
- Import: `godot --headless --path . --import`.
- Focused test: `godot --headless --path . --script res://tests/production_surface_world_test.gd`.

## Branch and validation

- Branch: `feature/backrooms-production-player-group-contract-2026-11-12`.
- Base: `main`.
- Runtime, regression-test and version-document commits are pushed to this branch. The final runtime refinement explicitly adds the group after `add_child(player)`.
- The focused test is already part of `.github/workflows/godot-validation.yml` Full Compatibility Gate.
- Exact-head Godot 4.3 CI is pending. No test pass is claimed until the latest branch HEAD completes the workflow.

## Integration boundary

This is the first production prerequisite only. It does not yet connect BackroomsPortalDirector or BackroomsPortalVisual to SurfaceWorld. The following remain separate work: portal camera-target routing, safe ground/stream ownership, player-relative candidate generation, transition lifecycle, and atomic Backrooms state integration in WorldSessionController save/restore.

## Next step

Run the exact-head Full Compatibility Gate, inspect the production SurfaceWorld group regression, and obtain independent review. Keep the PR unmerged until CI and review succeed.
