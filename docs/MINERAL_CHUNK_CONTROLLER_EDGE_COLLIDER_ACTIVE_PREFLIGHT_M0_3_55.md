# M0.3.55 — Shared edge collider active-state preservation after Binder preflight rejection

Date: 2026-11-28

## Purpose

Close a remaining assertion gap in the M0.3.54 2×2 checkerboard corner-cap regression. The test already compared the exact shared edge-collider instances after a non-mutating Binder preflight rejection, but did not prove that those same instances remained inside the physics tree with collision enabled. An object reference can remain comparable while a collider has been disabled or detached, so identity alone is insufficient.

## Changed files

- `tests/mineral_chunk_controller_test.gd` — after the rejected unload, resolve each current edge collider through the production Controller API, assert exact instance identity, then assert the collider is still valid, inside the physics tree, and on collision layer 1.
- `docs/MINERAL_CHUNK_CONTROLLER_EDGE_COLLIDER_ACTIVE_PREFLIGHT_M0_3_55.md` — this version record.

## Dependencies and import

- PR #442 / M0.3.29: atomic mineral chunk registration.
- PR #443 / M0.3.30 and M0.3.54: shared lifecycle recovery barrier and adapted corner-cap preflight regression.
- PR #440 / M0.3.53: production 2×2 checkerboard corner-cap preservation regression.
- Existing Godot 4.3 project, `MineralChunkController`, `SurfaceTerrainAdjacencyBinder`, `SurfaceTerrainTransitionColliderManager`, and `tests/mineral_chunk_controller_test.gd`.

No new plugins, Autoloads, Project Settings, external packages, scene changes, or save-schema changes. No manual import is required; the added assertions execute through the existing Controller test runner.

## Regression contract

For each of the four pre-existing shared seam colliders, after Binder rejects unload during non-mutating preflight:

1. The Controller lookup returns the exact same StaticBody3D instance.
2. The returned instance is still valid.
3. The instance remains inside the physics tree.
4. Its collision layer remains 1 (the production manager's active collision layer).

This complements the existing exact corner-cap identity, cap collision-layer, cap count, descriptor, blocked-corner report, chunk ownership, and object-registry snapshot assertions.

## Git history

- Base PR #443 HEAD: `bdd54944611d4e828a8abc99cdf28578ca063a77`.
- Test assertion commit: `af72bcbdcd1fba1446f9fee7b0e201ac01824d6d`.
- This version document is committed immediately after the implementation commit on the same PR #443 branch.

## Validation status

- Static source update: committed and pushed to the existing PR #443 branch.
- Exact-head Godot 4.3 focused and Full Compatibility Gate: pending the final documentation commit. Do not infer success from earlier #442 or #443 heads.
- Local Godot executable and GDScript linter are unavailable in the authoring container; no local engine test is claimed.

## Limitations and next steps

- Headless CI does not validate GPU rendering, platform physics differences, mobile devices, or target-hardware performance.
- Keep PR #443 Draft and unmerged until the exact final HEAD has focused and Full Gate success and independent parent-first review.
- Reconcile the #443 ancestry with #442 separately; this content/test update is not an ancestry merge.
- Do not merge main.
