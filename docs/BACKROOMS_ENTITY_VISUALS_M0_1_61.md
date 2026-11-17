# Backrooms Production Entity Visuals and Graphical Smoke — M0.1.61

## Purpose

Attach renderer-side procedural geometry to the deterministic, level-scoped entity identity roots introduced by M0.1.60. Validate both the renderer-independent geometry contract and the actual Godot 4.3 software-rendered result.

Spawn selection, level whitelist, placement, wall ownership, cell staging, rollback, unload, save schema and spawn algorithm version remain owned by the existing Director, MazeCellRuntime and MazeStreamState.

## Implementation

- Add `systems/BackroomsEntityVisualFactory.gd` as the production geometry/material builder for Window, Smiler, Hound, Skin-Stealer, Clump, Faceling, Duller and Deathmoth.
- Keep entity geometry as validated primitive specifications; reject unknown entities, duplicate part names, unsupported primitive kinds, non-finite transforms, non-positive dimensions and invalid material roles before constructing a scene subtree.
- Build the complete `Visuals` subtree detached, then publish it as one child of the entity root. A failed build returns false without publishing a partial subtree.
- Orient Window visuals only from the owned north/west wall metadata.
- Integrate the factory into `BackroomsMazeCellRuntime._build_cell_entity_roots()` only when the runtime is not metadata-only. Visual construction occurs before the entity root is published to the detached cell root; a failed visual build aborts cell staging.
- Preserve renderer-independent, child-free entity roots in headless mode.
- Add a headless contract test for all eight entity specifications, part counts, material roles, finite geometry, unique names, defensive-copy isolation, Window orientation, invalid specs, duplicate attachment and the production headless guard.
- Add a graphical smoke test that constructs real MeshInstance3D resources through the production Runtime, renders all eight entities, checks silhouette bounds/centering and checks both Smiler and Hound eyes against rendered pixel samples.
- Add a dedicated graphical GitHub Actions job using Godot 4.3, Xvfb and Mesa llvmpipe. The graphical process has a 120-second GNU timeout with a 5-second hard-kill grace and uploads the rendered montage artifact.

## Files

- `systems/BackroomsEntityVisualFactory.gd`
- `systems/BackroomsMazeCellRuntime.gd`
- `tests/backrooms_entity_visual_factory_test.gd`
- `tests/backrooms_entity_visual_factory_render_smoke_test.gd`
- `.github/workflows/godot-validation.yml`
- This version record.

## Provenance and dependencies

- Parent PR #389 exact HEAD: `75bf07b63bf83ebf162db942c6d614fc29f5714c`.
- Selective visual-factory source: historical PR #365; no historical branch merge.
- Graphical smoke source: validated test-only work from PR #368; no historical branch merge.
- Existing M0.1.60 entity identity roots, deterministic spawn descriptors, maze schema 2 and `entity_spawn_algorithm_version = 1`.
- Godot 4.3. No third-party runtime dependency, new autoload, Project Settings, scene asset or save-schema migration.
- No manual import; use the root project and existing `res://systems` and `res://tests` paths.

## Geometry contract

| Entity | Parts |
| --- | ---: |
| Window | 5 |
| Smiler | 3 |
| Hound | 8 |
| Skin-Stealer | 6 |
| Clump | 7 |
| Faceling | 6 |
| Duller | 6 |
| Deathmoth | 17 |
| **Total** | **58** |

## Validation commands

Headless contract:

```bash
godot --headless --path . --script res://tests/backrooms_entity_visual_factory_test.gd
```

Graphical software-rendered smoke:

```bash
LIBGL_ALWAYS_SOFTWARE=1 GALLIUM_DRIVER=llvmpipe \
xvfb-run -a -s '-screen 0 1280x720x24' \
godot --audio-driver Dummy --path . --rendering-method gl_compatibility \
--script res://tests/backrooms_entity_visual_factory_render_smoke_test.gd
```

## Validation status

Pending exact-head Godot 4.3 Full Compatibility Gate, complete diagnostic-log scan and the new graphical smoke job. No pass is claimed until all three complete on the same PR HEAD.

## Limitations

- Geometry is procedural primitive-based blockout art, not final character art.
- Collision shapes, navigation, AI, animation, perception, combat, damage and audio are not included.
- The graphical smoke uses Mesa llvmpipe software rendering. Hardware GPU, iPhone, target-device performance, production lighting/transparency quality and gameplay readability remain separate QA.
- Existing metadata-only/headless Runtime behavior must remain unchanged.
- No merge to main is included.

## Integration order

1. Complete the exact-head Full Gate, full-log scan and graphical smoke for this child PR.
2. Obtain independent review; do not self-approve.
3. Integrate only into PR #389's feature branch after review and rerun #389's exact-head Full Gate plus graphical smoke.
4. Continue parent-first through #388, #387, #386, #385 and #384. Do not merge main as part of this asset.
