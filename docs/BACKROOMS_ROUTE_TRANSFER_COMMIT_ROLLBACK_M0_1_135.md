# M0.1.135 — Live Ownership-Commit Rejection Rollback

## Purpose

Close a transaction boundary that the existing Hound integration suite did not isolate: the live entity has already been reparented and physically handed to the destination cell, but the ownership-ledger commit rejects the pending transfer.

The runtime must restore the entity and all ownership metadata to the source cell, cancel the pending ledger transaction, and remain able to perform a subsequent real transfer.

## Regression setup

- Godot 4.3 root project.
- Production BackroomsMazeCellRuntime prepared and activated on Level 2.
- Deterministic world seed 20261118, cell size 8.0 m, loaded window 3×3.
- Existing deterministic Hound transfer fixture and current production route snapshot.
- Actual production cell roots, Hound CharacterBody3D, collision setup, and BackroomsEntityOwnershipLedger.

## Fault injection boundary

A CommitRejectingOwnershipLedger test adapter delegates get_record, plan_transfer, and rollback_transfer to the real production ledger.

It deliberately rejects only commit_transfer with injected_commit_rejection. This places the fault after the runtime has staged the pending transaction, reparented the live Hound, and completed the destination physics handoff. The adapter does not replace the ledger's stored records or transaction state.

## Required rollback invariants

- Transfer returns the injected commit rejection.
- The Hound is reparented to its original source cell.
- The exact pre-handoff world transform is restored.
- The production owner record and owner revision remain unchanged.
- Live entity owner metadata returns to the original owner and revision.
- The production ledger has no pending transfer.
- Source and target identity-key/spawn-ID arrays are unchanged.
- Exactly one Hound identity remains under the source root and none under the target root.
- After restoring the real ledger reference, the existing three-hop/two-turn Hound pursuit test still completes, proving the runtime remains usable after rollback.

## Files

- tests/backrooms_entity_owner_runtime_integration_test.gd — adds the commit-rejection adapter, live rollback assertions, and a dedicated success marker.
- .github/workflows/godot-validation.yml — requires this version record and the dedicated marker in both headless and Xvfb/Mesa owner-runtime integration steps.
- docs/BACKROOMS_ROUTE_TRANSFER_COMMIT_ROLLBACK_M0_1_135.md — this version record.

## Dependencies and import

- Existing BackroomsMazeCellRuntime, BackroomsEntityOwnershipLedger, BackroomsEntityRuntimeState, BackroomsEntityMovementDriver, BackroomsCellRoutePlanner, and deterministic Level 2 entity fixture.
- No new scenes, external assets, plugins, autoloads, project settings, save-schema changes, or production runtime changes.
- Run from the repository root:

    godot --headless --path . --script res://tests/backrooms_entity_owner_runtime_integration_test.gd

The same script is included in the existing Godot Full Compatibility Gate. The workflow now also requires the new marker so the fault-injection branch cannot silently stop executing. The branch-prefix allowlist was extended so the existing Xvfb/Mesa Hound integration step runs on this PR branch as well.

## Validation evidence — code/test HEAD 047ad481

Exact candidate `047ad48177b3e3f3aca0e5a93a6e37b78d2511e7` passed a fresh PR-triggered matrix on 2026-11-24:

- All **20/20 workflow runs succeeded**, with 0 failed.
- Godot 4.3 Full Compatibility Gate [45424341663](https://github.com/qaqp980520-prog/2126-Survival/actions/runs/45424341663), job `138552109394`: **571/571 numbered validation steps** and 574/574 total step records succeeded.
- The required version-file guard, loaded-cell route planner step #25, and production Hound owner-runtime integration step #29 all passed. The dedicated `Backrooms live transfer commit rollback guard passed.` marker was present.
- Production integration steps #222–#227 passed: SurfaceWorld integration, combined Backrooms save envelope, SurfaceWorld file persistence, SurfaceWorld/Hound durable round-trip, keyboard/touch Save/Load, and survival test hub smoke.
- Xvfb/Mesa software-rendered Backrooms job `138552110093` passed **12/12** steps. The production cell ceiling/collision test, actual MeshInstance3D construction/frame capture, and Hound durable file round-trip with live NavigationAgent3D all passed. The dedicated live-transfer rollback marker was present in this log too.
- Full Gate log audit: 7,978,666 characters / 87,216 lines / 80,441 PASS matches; **0 actual Script/Parse/Runtime/ERROR/FAIL diagnostics**, 0 ObjectDB leaks, and 0 Orphan StringName diagnostics.
- Xvfb/Mesa log audit: 157,274 characters / 1,735 lines / 1,076 PASS matches; 0 actual engine diagnostics, 0 ObjectDB leaks, and 0 Orphan StringName diagnostics.
- **26 retained Full Gate warnings**, not claimed fixed: 19 filled `draw_rect` width warnings; 1 nested project warning for the existing `daily_games/KROLL_Salvage_Exchange` project; 1 mineral stale-unload rollback warning; 3 SurfaceWorld restore rollback warnings; and 2 synchronous mineral-registration rollback warnings.
- Xvfb/Mesa emitted 4 warnings: the same nested-project notice and 3 V-Sync limitations from the software graphics driver.
- Render artifact [14935653144](https://github.com/qaqp980520-prog/2126-Survival/actions/runs/45424341663/artifacts/14935653144) was uploaded (ZIP SHA-256 `941a5ce1d0e13f821aa4af690ac0c866ba1aefa9736b9dcbae42062ace5acc6b`). It is CI evidence, not a hardware-GPU, FPS, final-pixel-quality, or mobile-device result.
- No local Godot executable is available; no local engine run is claimed.

This document-only version-record update is a new commit after the tested code/test HEAD. The PR's latest exact-head workflow matrix must complete before the new documentation HEAD is considered validated.

## Limitations

- The test adapter rejects only the commit call; the real production ledger handles record lookup, plan creation, and rollback.
- This is deterministic fault-injection coverage, not a claim that a real disk/network failure occurred inside the ledger.
- GitHub Actions Godot 4.3 headless and Xvfb/Mesa software physics are the required engine evidence. No local Godot executable, hardware-GPU, FPS, final-pixel, or mobile-device result is claimed.
- No production runtime logic or save schema is changed.

## Next steps

1. Complete the exact-head workflow matrix, Full Compatibility Gate, and Xvfb/Mesa job.
2. Confirm the dedicated marker is present in both owner-runtime integration logs.
3. Audit the full logs for actual Script/Parse/Runtime/ERROR/FAIL diagnostics, ObjectDB leaks, Orphan StringName, and retained warnings.
4. Update PR #430, the asset index, the long-term project page, and the Run 412 work record with the final exact HEAD and evidence.
5. Obtain independent review and preserve parent-first integration. Revalidate every resulting HEAD after parent synchronization.
