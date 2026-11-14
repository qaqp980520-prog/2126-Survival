# Backrooms Production Entity Visual Factory — M0.1.18

## Purpose

Attach renderer-side geometry to the deterministic entity identity roots already created by the production Backrooms maze-cell runtime. Spawn selection, position, level whitelist, window ownership, cell staging, rollback, unload and restore remain owned by the existing Director and Runtime.

## Runtime changes

- Add `systems/BackroomsEntityVisualFactory.gd` as the production visual builder.
- Support all eight current entity IDs: Window, Smiler, Hound, Skin-Stealer, Clump, Faceling, Duller and Deathmoth.
- Keep geometry as renderer-independent specs, validate the complete spec list and material roles before building any node, then publish one complete `Visuals` subtree.
- Orient Window visuals from the existing owned-wall metadata: north-facing remains unrotated; west-facing rotates 90 degrees.
- Mark successful roots with `backrooms_entity_visual_version` and `backrooms_entity_visual_state=attached`.
- Integrate the factory into `BackroomsMazeCellRuntime._build_cell_entity_roots()` only when the runtime is not metadata-only. Headless runtime roots remain renderer-independent and child-free.

## Files

- `systems/BackroomsEntityVisualFactory.gd` — production geometry specs, material construction, validation and visual attachment.
- `systems/BackroomsMazeCellRuntime.gd` — invoke the visual factory during detached cell staging in graphical mode.
- `tests/backrooms_entity_visual_factory_test.gd` — all eight entity part counts, mesh/material validity, unique names, Window wall orientation, invalid geometry rejection and headless guard.
- `.github/workflows/godot-validation.yml` — add the focused visual-factory regression to the full compatibility workflow.

## Dependencies and import

- Parent PR #364 — persisted spawn-algorithm version in the production maze save contract.
- Grandparent PR #363 — deterministic production entity roots in Backrooms maze cells.
- Existing `BackroomsEntityDirector`, schema-2 spawn-version persistence and spawn algorithm version 1.
- Existing cell-root detached staging and rollback contract.
- Godot 4.3; no external packages, new autoloads, Project Settings or save-schema changes.

Import from repository root:

```bash
godot --headless --path . --editor --import --quit
```

Focused test:

```bash
godot --headless --path . --script res://tests/backrooms_entity_visual_factory_test.gd
```

## Validation

- Initial PR #365 exact-head Full Gate [Run #43654591016](https://github.com/qaqp980520-prog/2126-Survival/actions/runs/43654591016) and the first cleanup retry [Run #43654764143](https://github.com/qaqp980520-prog/2126-Survival/actions/runs/43654764143) both failed at the visual-factory test (step #25). The assertions printed PASS, but Godot's headless dummy renderer emitted repeated `ERROR: Parameter "m" is null.` messages while MeshInstance3D resources were destroyed. Adding test roots to the SceneTree and awaiting a frame did not eliminate the dummy-renderer error; that attempted fix is not counted as successful.
- The headless test contract is now deliberately renderer-independent: it validates all eight entities' geometry specs, finite transforms/dimensions, material-role construction, unique names, Window north/west orientation, invalid geometry rejection, duplicate-Visuals rejection, and the production headless guard. It no longer instantiates MeshInstance3D under the dummy renderer.
- The production `attach_visuals()` entry point still refuses to build renderer nodes in headless mode. MeshInstance3D construction occurs only in graphical runtime mode and requires a separate graphical QA pass.
- Current code changes: factory contract refactor `175890637c7b96571b6138998e099c0ba04281ac`; renderer-independent tests `5f297280ad18b29a9ffe4bfdc25c6375794120b2`.
- A fresh exact-HEAD Godot 4.3 Full Compatibility Gate is required for the new branch HEAD; no pass is claimed yet.
- Existing metadata-only maze-runtime tests must continue to see zero visual children.
- No graphical-mode visual inspection is claimed in this version.

## Scope limits

- This version adds visible procedural geometry only. It does not add collision shapes, navigation, AI, animation, perception, combat, damage or audio.
- The spawn algorithm and save payload remain unchanged; visuals are derived from existing entity IDs and metadata.
- Transparency, lighting, Z-fighting, silhouette readability, GPU cost and iPhone rendering still require graphical/device QA.
- Duller/Deathmoth geometry dimensions are ported from the validated prototype contract; the production factory is now the production source for runtime visuals.

## Next step

Run the focused visual-factory test and the exact-HEAD Full Gate. If both pass, request independent review of the parent/child Backrooms stack and perform graphical inspection before integrating into the parent branch.


## Run 266 — parent save-version contract reconciliation

- The visual-factory child is now based on PR #364's corrected exact HEAD `16af0fae0cb646b25344af2b7fd0df79074d2b01`, preserving schema-2 spawn-version persistence and legacy schema-1 migration.
- The visual factory does not change the save schema or spawn algorithm; it consumes the versioned entity identity roots already staged by the parent runtime.
- The visual factory's publication is failure-atomic: all geometry/material contracts are validated and the detached visual subtree is built before the root transform/children are changed.
- Exact-head Godot 4.3 validation for the combined parent/child tree is required; no pass is claimed yet.
