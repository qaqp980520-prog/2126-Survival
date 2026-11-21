# Backrooms Cell-local NavigationAgent3D — M0.1.75

## Scope

Adds a NavigationRegion3D and NavigationAgent3D foundation for mobile Backrooms entities. Each loaded cell receives a bounded rectangular navigation surface inset from the physical cell boundary. Mobile entities receive a NavigationAgent3D child; the existing central movement driver follows its next waypoint while retaining CharacterBody3D collision and the existing 12-entity / 10 Hz scheduling budget.

This is a cell-local navigation layer only. It does not change the loaded-cell route planner, transfer ownership, or allow an agent to cross cell boundaries automatically.

## Files

- `systems/BackroomsCellNavigationFactory.gd`
  - Creates a deterministic rectangular NavigationMesh with a 0.65 m inset.
  - Disables NavigationRegion3D edge connections so adjacent cell regions cannot silently become one cross-cell navigation surface.
  - Attaches NavigationAgent3D only to the six supported mobile entity types.
  - Uses a 0.2 m path waypoint tolerance and at least 0.5 m target tolerance to match the central 10 Hz movement cadence and avoid sub-step target thresholds.
- `systems/BackroomsMazeCellRuntime.gd`
  - Adds the cell navigation region before entity roots are staged.
  - Enables/disables navigation regions together with the existing runtime collision lifecycle.
  - Attaches a navigation agent when creating a mobile entity root.
- `systems/BackroomsEntityMovementDriver.gd`
  - Uses NavigationAgent3D waypoints for ground movement.
  - Keeps Deathmoth aerial patrol on its existing direct vertical movement path.
  - Keeps physical movement through CharacterBody3D.move_and_collide() and retains cell-bound checks.
- `tests/backrooms_cell_navigation_factory_test.gd`
  - Validates region bounds, disabled-by-default lifecycle, no automatic edge connections, supported agent creation, and a live headless navigation query.
- `tests/backrooms_entity_movement_driver_test.gd`
  - Adds a rectangular-hole navigation mesh fixture and verifies Hound follows a detour around a wall rather than colliding through it.
- `.github/workflows/godot-validation.yml`
  - Requires the new factory/test/design files and executes the focused navigation factory test in the Full Compatibility Gate.

## Dependencies and import

- Godot 4.3 built-in NavigationRegion3D, NavigationMesh, NavigationAgent3D and NavigationServer3D.
- Existing Backrooms cell runtime, CharacterBody3D collision factory, perception-driven EntityBrain and movement scheduler.
- No third-party plugins, binaries, autoloads, input maps or manual import steps.
- Root import: `godot --headless --path . --import`.

## Navigation contract

- A cell region is enabled only while the Backrooms runtime is active.
- Region edge connections are disabled; cross-cell routing remains controlled by the deterministic loaded-cell route planner and transactional owner transfer.
- The navigation polygon is inset by 0.65 m to preserve the same safe cell boundary used by movement and ownership transfer.
- The current production cell geometry has a flat floor and perimeter walls. Each NavigationAgent3D is parented under a Node3D NavigationAnchor offset to the cell floor plane while its CharacterBody3D remains at the entity collision height. The production mesh therefore describes the current traversable interior; future interior props/obstacles must contribute to a baked or explicitly cut-out navigation mesh before they can be treated as pathfinding obstacles.
- NavigationAgent3D avoidance is disabled in this version. Physical collision remains authoritative.
- The central movement driver samples navigation waypoints at its existing 10 Hz cadence; it does not create per-entity process loops. This is a deliberate first integration step and must be profiled before increasing entity counts or moving path updates to a separate central physics-frame cache.

## Validation

- Exact-head Godot 4.3 CI is required for this PR.
- Focused navigation factory and movement-driver tests are included in the Full Compatibility Gate.
- No local Godot executable is assumed; GitHub Actions is the engine execution source.
- No graphical/GPU or iPhone performance result is claimed.

## Limitations and next steps

- No cross-cell NavigationAgent3D links or autonomous multi-hop pursuit.
- No dynamic obstacle baking, avoidance, combat, animation or audio.
- Next: integrate NavigationAgent3D with the existing loaded-cell route snapshot and one-hop owner transfer, then add an end-to-end Hound pursuit regression across at least two loaded cells.


## Parent integration retarget — 2026-11-21

- PR #402 has been retargeted from the closed/merged PR #401 head branch to the validated PR #400 feature branch `integration/backrooms-entity-live-owner-transfer-2026-11-18`.
- New parent exact HEAD: `e142854471526923342e685bc86010344acddcaa`; PR #400 Full Gate completed 570/570 step records and all 19/19 associated workflows succeeded. Complete log audit found no actual Godot diagnostics; 26 existing warnings remain classified.
- PR #402 implementation head before this documentation-only update: `1eb70d3c96966237f627e560b45f1e00b3d8259d`. The retargeted comparison contains the intended eight NavigationAgent3D files; compare reports 8 head commits, with PR #400's two parent-side commits relative to the common merge base.
- This documentation-only update is intended to trigger a fresh exact-head CI matrix against the new parent. Prior #402 CI validates the old base only and must not be reused as new-base evidence.
- PR #402 remains Draft until the new exact-head Full Compatibility Gate, focused workflows, and complete logs pass.
- No NavigationAgent3D production behavior changed in this addendum. Local Godot executable remains unavailable; no local runtime pass is claimed.


## Exact parent merge synchronization — 2026-11-21

- Live comparison before synchronization exposed a real ancestry gap: this PR branch was 9 commits ahead / 2 behind its retargeted PR #400 base; merge base was the old PR #401 HEAD `72b194557549ee4569f2992a537d6fd742fa975d`. The PR base field already named #400, but the child Git history had not absorbed the two parent-side commits.
- Validated parent PR #400 exact HEAD: `e142854471526923342e685bc86010344acddcaa`; Full Compatibility Gate run [44760499038](https://github.com/qaqp980520-prog/2126-Survival/actions/runs/44760499038), job `136371493256`: 570/570 steps successful, 0 failed, 0 skipped. The separate Xvfb/Mesa job was skipped by the branch-prefix allowlist and is not claimed as a parent-side rendered pass.
- Parent-only delta from the merge base was one documentation file, `docs/BACKROOMS_LIVE_ENTITY_OWNER_TRANSFER_M0_1_73.md` (11 additions, 1 deletion); it did not overlap any of the eight NavigationAgent3D child files.
- Created safety ref `backup/pr402-before-parent-sync-2026-11-21` at the previous child HEAD `a1312fdc246578105cfd2d7f461b4741b86f3966`.
- Integrated the exact parent into the existing child branch with merge commit `427862db9dfcfc1dee2d5d6cff9838596ed4b126`; first parent is the prior child HEAD `a1312fdc246578105cfd2d7f461b4741b86f3966`, second parent is validated PR #400 HEAD `e142854471526923342e685bc86010344acddcaa`.
- New live compare: 10 commits ahead / 0 behind; merge base equals the exact PR #400 HEAD. The eight-file NavigationAgent3D diff is unchanged.
- PR #402 remains Open / Draft / Unmerged. Historical green checks on the old head are not reused. A fresh exact-head Godot 4.3 Full Compatibility Gate and focused workflow matrix must pass, followed by complete log review, before marking Ready for Review.
- No production source beyond the existing eight child files was changed by this synchronization; no main merge and no `daily_games/` changes. Local Godot is unavailable, so no local runtime pass is claimed.
