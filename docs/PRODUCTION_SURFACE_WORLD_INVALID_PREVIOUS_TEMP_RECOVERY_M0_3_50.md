# M0.3.50 — Verified Temp Recovery After Invalid Staged Previous

## Purpose

Close a recovery gap when an interrupted save leaves a `.previous` file that exists but fails validation. If the current primary, staged previous, and committed backup are all invalid, the recovery path previously returned before checking a fully validated `.tmp`. This could strand the only recoverable world snapshot behind an invalid staged file.

## Versioned files

- `systems/SurfaceWorldSaveStore.gd` — when primary, previous, and backup validation all fail, validate the temp before changing any file; archive the invalid previous; reuse the verified-temp promotion path; retain the temp and recovery evidence if promotion fails.
- `tests/production_surface_world_test.gd` — exercise the real `SurfaceWorld.load_game()` entry point with corrupt primary, corrupt `.previous`, corrupt `.bak`, and a fully valid `.tmp`.
- `docs/PRODUCTION_SURFACE_WORLD_INVALID_PREVIOUS_TEMP_RECOVERY_M0_3_50.md` — this version record.

## Dependencies and staging

- Production durable save/load parent: PR #452.
- First-write recovery and save-store recovery chain: PR #459.
- Exact staging base at branch creation: PR #459 HEAD `959b2f85328510d8c4ab36e763c3f9c363f4c995`.
- Staging branch: `fix/save-recover-temp-after-invalid-previous-2026-11-28-run12`.
- This is a staging child of PR #459. It is not a standalone release and must not be merged before parent-first independent review.

## Recovery precedence

1. A valid committed primary remains authoritative.
2. A valid staged previous remains the rollback source.
3. A valid committed backup remains preferred over an uncommitted temp.
4. Only when primary, previous, and backup are invalid may a fully validated temp be considered.
5. The invalid staged previous is archived using the collision-safe corrupt-archive allocator.
6. The existing verified-temp promotion routine separately archives an invalid primary, copies and verifies the temp, promotes it, verifies the primary, and consumes the source temp only after success.
7. If archival or promotion fails, return a recovery-required report and preserve the remaining source/evidence for retry.

An invalid or missing temp preserves the existing fail-closed error path; no invalid file is promoted.

## Regression coverage

The production test writes:
- a corrupt primary;
- a corrupt staged `.previous`;
- a corrupt committed `.bak`;
- a valid, checksum- and payload-validated `.tmp`.

The test first injects a temp-promotion failure after the invalid previous file has been archived. It requires:
- the failure returns `recovery_required` with the precise invalid-previous fallback reason;
- the original corrupt primary is rolled back byte-for-byte;
- the validated source temp remains byte-for-byte intact;
- the already archived corrupt previous remains available;
- the invalid backup remains byte-for-byte intact;
- the owned restore staging file is cleaned up.

The test then removes the injected failure and calls the real `SurfaceWorld.load_game()` entry point. It requires:
- the valid temp becomes the exact primary bytes;
- the source temp is consumed only after successful promotion;
- the corrupt primary and previous bytes survive in two distinct collision-safe archives;
- the corrupt backup remains byte-for-byte intact for diagnosis;
- the load report returns through the normal `loaded_from_primary` path.

## Import and test

No asset import, project setting, scene, Autoload, or external dependency change.

From the repository root:

~~~bash
godot --headless --path . --editor --quit
godot --headless --path . --script res://tests/production_surface_world_test.gd
~~~

The exact-head Dedicated Production SurfaceWorld Save Validation and Full Godot 4.3 Compatibility Gate must both pass before promotion.

## Validation status

The original M0.3.50 implementation at candidate HEAD `fb6cc69671640312589be760998efa6e5042527b` passed Dedicated Production SurfaceWorld Save Validation [Run 46100731313](https://github.com/qaqp980520-prog/2126-Survival/actions/runs/46100731313) and Full Godot 4.3 Compatibility Gate [Run 46100731299](https://github.com/qaqp980520-prog/2126-Survival/actions/runs/46100731299), 553/553 steps, 0 failures, 0 skipped.

The failure-atomicity regression was added in commit `d6d604ef07828a6d0aa9fadd670237a251c5e180`, and the expanded code/test candidate HEAD `491c106b3454dc9f590eb2e972f758225f528700` passed both exact-head workflows:

- Dedicated Production SurfaceWorld Save/Load Validation [Run 46110575932](https://github.com/qaqp980520-prog/2126-Survival/actions/runs/46110575932): success, 10/10 steps; 821 lines / 82,689 characters / 527 PASS markers. All new failure-atomicity assertions passed.
- Full Godot 4.3 Compatibility Gate [Run 46110576047](https://github.com/qaqp980520-prog/2126-Survival/actions/runs/46110576047): success, 553/553 steps, 0 failed, 0 skipped.
- Full log: 84,645 lines / 7,748,856 characters / 78,300 PASS markers. The 331 raw `SCRIPT ERROR|ERROR:|FAIL:` keyword matches are echoed CI grep-guard commands; no actual Script, Parse, Runtime, ERROR or FAIL diagnostic was found.
- Critical steps 205/206/211/212/300/310/315/550 all passed: Production SurfaceWorld, updated test hub, surface underground mining, UndergroundMineDirector, all mine-layers lift lifecycle, terrain patch persistence, all-chunk reload, and clean validation workspace.
- 26 Godot warnings remain: 19 `draw_rect()` filled-width warnings, 1 nested KROLL project warning, and 6 intentional mineral/underground fault-injection warnings (4 mineral rollback, 1 compensation barrier, 1 underground rollback). One separate GitHub Actions Node.js 20 deprecation warning remains.
- No ObjectDB leak or Orphan StringName report.

The authoring container has no local Godot executable; the engine passes above are from GitHub Actions, not local execution. This closeout changes documentation only; it does not change the tested runtime or regression code. Exact-head CI will be rerun for the documentation closeout commit before promotion.
## Limitations

- This is a recovery fallback for the specific state where no committed candidate validates. It does not claim power-loss durability beyond the existing filesystem flush/rename protocol.
- Windows filesystem behavior and symlink permissions remain subject to the existing platform-specific test skips.
- No GPU, rendered-frame, iPhone, iPad, or target-device QA is implied by headless CI.

## Next step

Run exact-head Dedicated Save Validation and Full Godot 4.3 Compatibility Gate for the failure-atomicity candidate. Preserve any failed candidate evidence. If both pass, keep this PR Draft pending independent review; after parent-first approval, integrate into PR #459 with expected-SHA fast-forward and rerun the updated parent gates. Do not merge main.
