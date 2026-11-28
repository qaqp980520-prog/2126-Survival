# M0.3.56 — Shared transition and corner-cap collision-shape preservation

Date: 2026-11-28

## Purpose

Extend the M0.3.55 active-state regression from StaticBody3D identity/layer checks to the actual CollisionShape3D nodes and Shape3D resources. A body can remain registered and on collision layer 1 while its child collision shape is detached, disabled, replaced, or left without usable geometry. The rejected Binder preflight must preserve the complete live physics representation.

## Changed files

- \`tests/mineral_chunk_controller_test.gd\` — strengthen the existing 2×2 checkerboard preflight-rejection regression. Snapshot all four shared corner-cap collision nodes/resources and all four edge collision nodes/resources before rejection; after rejection verify exact identity, tree membership, enabled state, resource identity, and valid geometry.
- \`docs/MINERAL_CHUNK_CONTROLLER_COLLISION_SHAPE_PREFLIGHT_M0_3_56.md\` — this version record.

## Dependencies

- PR #440 / M0.3.53: production checkerboard corner-cap regression.
- PR #443 / M0.3.54–M0.3.55: shared lifecycle recovery barrier and edge-body active-state assertions.
- PR #442: atomic mineral chunk registration parent.
- Godot 4.3 built-in \`StaticBody3D\`, \`CollisionShape3D\`, \`ConcavePolygonShape3D\`, and \`BoxShape3D\`.

No new plugins, Autoloads, Project Settings, scenes, external packages, or save-schema changes.

## Regression contract

After a non-mutating Binder preflight rejection:

1. Each of the four corner-cap StaticBody3D instances remains the same valid object, inside the physics tree, on collision layer 1.
2. Each corner cap retains the exact same \`CornerCapCollision\` child, still inside the tree and not disabled.
3. Each corner cap retains the exact same \`ConcavePolygonShape3D\` resource with at least 36 face vertices.
4. Each of the four edge StaticBody3D instances remains the same valid object, inside the physics tree, on collision layer 1.
5. Each edge retains the exact same \`SharedTransitionCollision\` child, still inside the tree and not disabled.
6. Each edge retains the exact same \`BoxShape3D\` resource with strictly positive dimensions.
7. Existing descriptor, blocked-corner report, chunk ownership, object-registry snapshot, and recovery-barrier assertions remain in place.

The test exercises the existing production Controller and collider-manager objects. It does not alter runtime behavior.

## Import and test

No manual import or project-setting change. The regression runs through the existing \`tests/mineral_chunk_controller_test.gd\` runner and the repository's Godot 4.3 Full Compatibility Gate.

## Validation status

- Branch-based source edit and exact-anchor checks: completed.
- GitHub read-back, diff review, assertion-count checks, and whitespace/conflict-marker checks: pending final commit readback.
- Local Godot executable and GDScript parser/linter are unavailable in the authoring container; no local engine test is claimed.
- Exact-head GitHub Actions result must be checked after updating PR #443. Parent #442 or prior #443 runs do not validate the new HEAD.

## Limitations and next step

Headless tests do not validate GPU rendering, platform-specific physics differences, mobile devices, or target-hardware performance. Keep PR #443 Draft and unmerged until focused Controller CI and Full Godot 4.3 Gate pass on the exact final HEAD and parent-first independent review is completed.
