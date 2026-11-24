# Scoped World-Object Snapshot Self-Recovery — M0.3.15

## Purpose

Extend M0.3.14's four-prop failure-atomicity coverage to exercise the recovery branch inside `_restore_world_object_registry_snapshot` itself. The requested target snapshot is deliberately made to fail partway through application; the helper must then restore the exact pre-attempt scoped records without serializing the full registry.

## Files

- `tests/world_object_multi_prop_rollback_test.gd` — adds two one-shot fault-injection cases to the existing rollback suite.
- `docs/WORLD_OBJECT_MULTI_PROP_ROLLBACK_M0_3_14.md` — corrects the prior pending validation text with PR #423's verified exact-head evidence.
- `docs/WORLD_OBJECT_SCOPED_ROLLBACK_SELF_RECOVERY_M0_3_15.md` — this version record.

No production runtime code, workflow definition, scene, save schema, Project Settings, input mapping, or third-party dependency changes.

## Dependencies and import

- Parent PR #423 exact HEAD at branch creation: `60b0bb4a0cbb6d81c557dc33740d8303ce1c7691`.
- Godot 4.3 root project.
- `systems/MineralChunkController.gd`
- `systems/WorldObjectStateRegistry.gd`
- `systems/MineralVeinRegistry.gd`
- `systems/WorldObjectStatefulProp.gd`

Run from the repository root:

```bash
godot --headless --path . --script res://tests/world_object_multi_prop_rollback_test.gd
```

The existing Godot 4.3 Full Compatibility Gate already invokes this test script, so the new cases run in the same required step; no workflow change is needed.

## New recovery regressions

1. **Partial target-record rewrite:** seed four current records, capture a distinct target snapshot, then make the third target `set_object_state` call fail once. The helper must return false for the failed target restore but recover all four exact pre-attempt current records. The unrelated unloaded record must remain unchanged.
2. **Partial target-record removal:** repeat with the third `forget_object_state` call failing once after two records have been removed. The helper must recover all four exact pre-attempt current records and preserve the unrelated record.

Both cases assert zero calls to the full-registry serializer and verify the registry's total-property and total-string-character accounting counters return to their exact pre-attempt values. The fault is one-shot so the recovery attempt can succeed and its contract can be tested deterministically.

## Validation status

- Exact-head Godot 4.3 Full Compatibility Gate: pending for this child PR.
- PR #423 parent evidence is recorded in M0.3.14 above; that evidence does not validate this new child HEAD.
- Local Godot executable is unavailable in the authoring environment; no local engine pass is claimed.
- No GPU, rendered FPS, or target-device performance claim is made.

## Limitations and next steps

- These tests cover transient, one-shot failures during scoped record application/removal. They do not claim recovery from a persistent registry failure that also prevents the fallback restore.
- The tests invoke the scoped snapshot helper directly for this recovery branch; the existing M0.3.14 suite separately covers load, saved-state application, capture, and unload integration paths.
- Keep this PR stacked on #423. Require exact-head Godot 4.3 CI and independent review before integrating into #423, then rerun validation on the resulting parent HEAD. Do not merge into #422 or main as part of this change.
