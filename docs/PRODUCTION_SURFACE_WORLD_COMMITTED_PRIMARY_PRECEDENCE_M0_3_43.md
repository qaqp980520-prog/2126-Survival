# M0.3.43 — Committed Primary Precedence over Valid Uncommitted Temp

## Purpose

Lock down the highest-priority recovery invariant: a fully valid committed primary save must remain authoritative when a different fully valid but uncommitted `.tmp` sidecar is present.

This covers the inverse of first-write temp recovery. The recovery implementation must not promote a newer-looking temp over a committed primary merely because the temp also passes checksum and payload validation.

## Regression behavior

The production SurfaceWorld save/load regression now:

1. Creates a valid committed primary from the current world snapshot.
2. Creates a different, fully valid uncommitted temp envelope with a distinct world seed.
3. Calls the production `load_game()` entry point.
4. Verifies the primary remains byte-for-byte unchanged.
5. Verifies the temp remains byte-for-byte unchanged and is not consumed.
6. Verifies the restored world seed and reported source come from the committed primary.

This exercises the actual load/recovery entry point, not only the storage helper.

## Versioned files

- `tests/production_surface_world_test.gd` — committed-primary precedence regression.
- `docs/PRODUCTION_SURFACE_WORLD_COMMITTED_PRIMARY_PRECEDENCE_M0_3_43.md` — this version record.

No production GDScript, scene, project setting, Autoload, save schema, or external dependency changes.

## Dependencies

- Parent feature: [PR #452 — Production SurfaceWorld durable save/load](https://github.com/qaqp980520-prog/2126-Survival/pull/452).
- Child branch: [PR #459 — Verified first-write temp recovery](https://github.com/qaqp980520-prog/2126-Survival/pull/459).
- Parent HEAD at child creation: `aa113f37b4c84a3c34e54e968a815f877789134e`.
- Prior child HEAD: `7beeb6bddfb7ee4540be5f5ed6c0374a68943a71`.

## Import and test

No separate import step. The regression runs through the existing production save validation workflow and root Godot 4.3 Full Compatibility Gate.

Required commands in CI:

```bash
godot --headless --path . --editor --quit
godot --headless --path . --script res://tests/production_surface_world_test.gd
```

Exact-head Dedicated Production SurfaceWorld Save Validation and Full Godot 4.3 Compatibility Gate are required before integration.

## Validation status — code/test HEAD passed

The code/test HEAD `b85a23a51e259a99654a4679ee0f5c0c297360b7` passed both required exact-head workflows:

- [Full Godot 4.3 Compatibility Gate #45979252773](https://github.com/qaqp980520-prog/2126-Survival/actions/runs/45979252773): success, 553/553 reported job steps.
- [Dedicated Production SurfaceWorld Save Validation #45979252790](https://github.com/qaqp980520-prog/2126-Survival/actions/runs/45979252790): success, 10/10 steps.

Full Gate log: 84,566 lines / 7,738,604 characters / 78,221 PASS markers; 0 actual Script/Parse/Runtime/ERROR/FAIL diagnostics after excluding echoed shell-guard commands; 0 ObjectDB leak reports; 0 Orphan StringName reports. All six new committed-primary precedence assertions passed in both workflows.

26 Godot warnings remain: 19 filled-rect width warnings, 1 nested KROLL project warning, and 6 lifecycle/rollback fault-injection diagnostics. A separate GitHub Actions Node.js 20 deprecation warning remains.

The following commit updates documentation only; it does not change runtime code or tests. The new PR HEAD will still be checked by its triggered workflows before this version record is considered final for that HEAD.

## Limitations

- This is an in-process recovery precedence regression; it does not claim OS-level power-loss durability or filesystem `fsync` guarantees.
- It adds no autosave or disk-persisted rollback journal.
- Local Godot is unavailable in the working container; no local engine pass is claimed.
- GPU/rendering, Xvfb/Mesa, mobile, and target-device QA remain outside headless CI.

## Next step

Wait for exact-head Dedicated Save Validation and Full Godot 4.3 Gate. If both pass, update the PR with exact evidence, keep it Draft pending parent-first independent review, and only then integrate into #452 with an expected-SHA fast-forward and rerun parent CI. Do not merge to main.
