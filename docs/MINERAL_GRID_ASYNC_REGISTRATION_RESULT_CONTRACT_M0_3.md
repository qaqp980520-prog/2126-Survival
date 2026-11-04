# Mineral Grid Async Registration Result Contract M0.3

## Finding

The synchronous registration path already verifies both the Controller callback result and the Controller's actual loaded-chunk registry. The async commit path did not: it trusted a `true` return value and immediately recorded Director ownership. The stale-root restoration helper also accepted a successful return without verifying that the old chunk was registered.

These gaps allowed two inconsistent callback outcomes to corrupt the async ownership mirror:

- `false` after the candidate was attached and registered could leave a live Controller chunk behind while the Director reported a failed commit without rolling it back.
- `true` without registration could be accepted as a committed chunk even though `is_chunk_loaded()` returned false.

## M0.3 changes

- Async commit now revalidates Controller lifecycle immediately after `load_chunk`.
- It checks the requested ID through `is_chunk_loaded()` before recording ownership.
- A registered candidate is added to the rollback set before any rollback attempt, preserving the ownership mirror if unload fails.
- A candidate attached to the Controller but absent from its registry is detached and queued for release; a candidate owned by an unrelated parent is not mutated and causes cleanup to be reported incomplete.
- Async stale-root restoration now applies the same actual-registration check and refuses to report a successful restoration when the Controller did not register the requested ID.
- Existing public Director APIs, chunk IDs, save schema and async staging/commit ordering remain unchanged.

## Files

- `systems/MineralGridStreamingDirector.gd`
- `tests/mineral_grid_streaming_async_registration_contract_test.gd`
- `.github/workflows/mineral-grid-streaming-lifecycle-validation.yml`
- `.github/workflows/godot-validation.yml`
- `docs/MINERAL_GRID_ASYNC_REGISTRATION_RESULT_CONTRACT_M0_3.md`

## Dependencies and import

- Root Godot 4.3 project.
- Uses `systems/MineralChunkController.gd` contract and `tests/helpers/FakeMineralChunkController.gd`.
- No external assets, plugins, services or save migration.
- Run from the repository root:

```bash
godot --headless --path . --editor --quit
godot --headless --path . --script res://tests/mineral_grid_streaming_async_registration_contract_test.gd
```

## Regression coverage

1. Async commit: Controller registers a chunk and then returns `false`; the candidate must be rolled back and no stale ownership/root may remain.
2. Async rollback failure: when that candidate cannot be unloaded, the Director must retain the actual chunk ID in its ownership mirror and allow a later sync to reconcile it.
3. Async commit: Controller attaches a candidate and returns `true` without registering it; the request must fail, remove the unregistered root and preserve matching Controller/Director IDs.
4. Stale-root restoration: after a partial stale-unload failure, a restoration callback returns `true` without registering its candidate; the helper must return failure, report incomplete rollback and avoid retaining an orphan root.
5. Controller detachment during async commit: the request must report `dependency_unavailable`, identify the live detached Controller, roll back the newly registered candidate, and preserve the original empty window.
6. Factory loss after an async request is accepted: the request must remain `dependency_unavailable` and preserve the `factory_unavailable` diagnostic reason rather than being mislabeled as Controller loss.

## Validation and limitations

- Static diff review is required before merge.
- Exact-head focused and full Godot 4.3 CI must pass, including cleanup and container shutdown. The full compatibility gate also runs the existing production async streaming regression suite, which covers Controller detachment during commit.
- The local runtime has no Godot executable; no local engine pass is claimed.
- Headless CI does not validate rendered GUI/GPU behavior or physical iPhone behavior.
- Do not merge until exact-head focused/full gates and all cleanup steps succeed.
