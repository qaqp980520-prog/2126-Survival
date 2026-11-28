# M0.3.54 — Corner-cap preflight regression under the shared lifecycle recovery barrier

Date: 2026-11-28

## Purpose

Adapt the M0.3.53 corner-cap preservation regression to the lifecycle contract introduced by PR #443 / M0.3.30. The Binder preflight rejection preserves existing live collider state, but the Controller records terrain-adjacency recovery as pending. The test must explicitly clear that barrier before retrying unload.

## Changed files

- `tests/mineral_chunk_controller_test.gd` — extend `_test_failed_unload_preflight_preserves_corner_caps()` to assert the report and shared/terrain-specific recovery barriers, repair the invalid patch, perform a successful full adjacency refresh, verify both barriers clear, then retry unload.
- `docs/MINERAL_CHUNK_CONTROLLER_CORNER_CAP_PREFLIGHT_RECOVERY_BARRIER_M0_3_54.md` — this version record.

## Dependencies and import

- Parent PR #442 / M0.3.29: atomic mineral chunk registration.
- PR #443 / M0.3.30: Controller/Director shared lifecycle recovery barrier.
- PR #440 / M0.3.53: 2×2 checkerboard corner-cap preservation regression.
- Existing Godot 4.3 project and the existing `tests/mineral_chunk_controller_test.gd` runner.
- No plugins, Autoloads, Project Settings, external dependencies, or save-schema changes.

## Regression contract

1. Preserve the exact four shared corner-cap bodies, four edge colliders, descriptors, blocked-corner reports, active collision, departing chunk ownership, and object-registry snapshot when Binder preflight rejects unload.
2. Verify the Controller's last report and `has_pending_chunk_load_recovery()` expose the shared recovery barrier; `has_pending_terrain_adjacency_recovery()` must also remain true.
3. Repair the invalid patch and call `refresh_terrain_adjacency()` explicitly.
4. Verify both terrain-specific and shared lifecycle barriers clear.
5. Retry unload and verify the departing chunk is released and ineligible corner caps are retired.

This is a test adaptation to PR #443's lifecycle contract, not evidence of a new production defect.

## Validation

- Three-way source merge of parent #442's M0.3.53 test and child #443's existing controller tests: completed with no overlapping edit conflicts.
- Static source invariants: parent and child test registration/function each occur exactly once; no merge-conflict markers.
- Exact-head Godot 4.3 focused and Full Compatibility Gate: pending final synchronized commit; do not infer success from earlier #440 or #443 runs.
- Local Godot executable unavailable in the authoring container; no local Godot execution is claimed.

## Limitations and next steps

- Headless CI does not validate GPU rendering, physical-device behavior, mobile UI, or target-hardware performance.
- Keep PR #443 Draft and unmerged pending exact-head CI and independent parent-first review.
- Do not merge main.
