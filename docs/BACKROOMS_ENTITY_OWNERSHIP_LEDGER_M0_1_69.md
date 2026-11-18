# Backrooms Entity Ownership Ledger — M0.1.69

## Purpose

Add a renderer-independent transaction core for the next Backrooms roaming stage. It separates immutable deterministic spawn identity from mutable runtime owner-cell identity.

This is a foundational ownership contract, not yet live Node migration. It does not reparent CharacterBody3D nodes, change the current movement driver, or enable cross-cell roaming.

## Files

- `systems/BackroomsEntityOwnershipLedger.gd` — bounded identity/owner registry, one-hop transfer planning, commit/rollback, and versioned serialization.
- `tests/backrooms_entity_ownership_ledger_test.gd` — deterministic spawn fixture, route-bound transfer, revision checks, stale-token rejection, rollback, save/load and tamper regressions.
- `.github/workflows/godot-validation.yml` — required-file guards and Godot 4.3 focused test step.

## Contract

- Stable key: `spawn_cell_key|entity_id`; the spawn cell never changes.
- Mutable `owner_cell_key` changes only after an exact pending plan is committed.
- Transfers advance exactly one adjacent hop from the first edge of a current route snapshot.
- Both current and target owner cells must be in the committed loaded window.
- Route snapshots must match level, world seed, layout algorithm, stream generation, configuration revision, loaded-cell count, canonical keys and reciprocal deterministic edges.
- A stream-generation/configuration change invalidates every pending transfer.
- Commit checks the original owner and owner revision to prevent stale or replayed transactions.
- Pending transactions are not serialized; save returns an empty payload until they are committed or rolled back.
- Records are capped at 4,096 and sorted by immutable spawn identity.
- Pruning is based on mutable owner-cell retention, not immutable spawn-cell location. The accepted retention set is capped at 361 cells (radius-8 loaded window plus one-cell halo); pending transfers block pruning. An empty committed retention set intentionally evicts all records.
- Restore validates every record into a candidate map before replacing the existing ledger.

## Dependencies / import

Godot 4.3; existing `BackroomsMazeLayout.gd`, `BackroomsEntityDirector.gd` and `BackroomsCellRoutePlanner.gd`. No external plugins or binary assets. Tests run with:

```bash
godot --headless --path . --script res://tests/backrooms_entity_ownership_ledger_test.gd
```

No manual import is required beyond the root project import gate.

## Validation

Pending exact-head GitHub Actions Godot 4.3 validation on PR #398. Local Godot executable is unavailable in this environment; no local engine pass is claimed.

## Limitations

- This ledger is not yet wired into `BackroomsMazeCellRuntime` or `BackroomsEntityMovementDriver`.
- It records logical owner-cell transitions only; it does not move live Nodes.
- The retention-prune API only updates ledger records. The future runtime integration must free or archive the corresponding live Node when an owner record is evicted.
- It does not yet merge owner-cell records into the existing maze stream save schema.
- Cross-cell roaming remains disabled until the runtime reparent transaction, unload/reload reconstruction, movement scheduling, and combined-world save integration are implemented together.

## Next

Integrate the ledger with the runtime in a separate tested step: preserve spawn identity, reparent the live entity only after a validated transfer commit, archive it when its owner cell unloads, reconstruct it when the owner cell returns, and round-trip the owner-cell state through the combined world save.
