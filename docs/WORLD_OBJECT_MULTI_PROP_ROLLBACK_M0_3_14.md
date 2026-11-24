# Dense Multi-Prop Chunk Rollback Regressions — M0.3.14

## Purpose

Extend M0.3.13's successful four-stateful-props-per-chunk lifecycle coverage with failure-injection tests. The goal is to verify that a failed operation restores every affected object record and live prop, not merely the first one or two records.

## Files

- `tests/world_object_multi_prop_rollback_test.gd` — four-prop failure-atomicity regressions.
- `.github/workflows/godot-validation.yml` — required file guards and a dedicated Full Compatibility Gate step.
- `docs/WORLD_OBJECT_MULTI_PROP_ROLLBACK_M0_3_14.md` — this version record.

## Dependencies and import

- Godot 4.3 root project.
- `systems/MineralChunkController.gd`
- `systems/WorldObjectStateRegistry.gd`
- `systems/MineralVeinRegistry.gd`
- `systems/WorldObjectStatefulProp.gd`

Run from the repository root:

```bash
godot --headless --path . --script res://tests/world_object_multi_prop_rollback_test.gd
```

The script is also executed by the Godot 4.3 Full Compatibility Gate after the M0.3.13 multi-prop lifecycle benchmark.

## Regression scenarios

1. **Partial default-record insertion:** fail the third of four `set_object_state` calls during load. The chunk must remain detached and unowned; all partially created records must be removed; an unrelated unloaded record must remain unchanged.
2. **Saved-state application failure:** make the third prop reject its saved state after two earlier props have applied. The load must fail atomically; all live props must return to their initial state; all four saved registry records and unrelated records must remain exact.
3. **Partial loaded-state capture:** fail the third record update. All four registry records must return to their pre-capture values while the live props retain their interacted state; a retry must succeed.
4. **Partial unload capture:** fail the third record update during unload. The controller must retain ownership and the root must remain attached; all four registry records must return to their pre-unload values; a retry must unload successfully and persist all four current live states.

Every scenario instruments the production registry and asserts that the scoped path does not call the full-registry serializer.

## Version and dependency

- Child PR: [#423 — Cover dense multi-prop rollback failure paths](https://github.com/qaqp980520-prog/2126-Survival/pull/423).
- Branch: `test/world-object-multiprop-rollback-2026-11-24-run399`.
- Parent PR #422 exact HEAD at branch creation: `5b49eb24103d5df24dbd303c8f5a5493d83fc602`.
- No production runtime code, save schema, scenes, Project Settings, input mappings, or third-party dependencies change.

## Validation status

- Exact-head Godot 4.3 Full Compatibility Gate: pending.
- Local Godot executable is unavailable in the authoring environment; no local engine pass is claimed.
- No GPU, rendered FPS, or target-device performance claim is made.

## Limitations and next steps

- The new suite focuses on four stateful props in one chunk. It does not exhaustively test every possible object count or arbitrary custom registry implementation.
- Existing M0.3.13 success-path benchmark remains separate and continues to cover 289 chunks × four props.
- Keep this PR stacked on #422. Do not merge to #422, #421, #420, #419, #418, #279, or main before exact-head validation and independent review.
