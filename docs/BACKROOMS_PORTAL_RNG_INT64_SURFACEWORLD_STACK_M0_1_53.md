# M0.1.53 — Backrooms Portal RNG Int64 Guard at SurfaceWorld Persistence Branch

## Purpose

Correct the first divergent SurfaceWorld portal-persistence branch that reintroduced the overflow-prone RNG save parser after clean PR #337. This is a corrective backport for the legacy #339 persistence/runtime stack and its #340–#347 / #363–#364 descendants; the newer validated replacement chain #376–#381 already carries the canonical parser and regression coverage.

## Exact evidence

- PR #339 head: `ff690871a42846c1ae59e72e10605d01fe61bf5d`; its `BackroomsPortalDirector.gd` used the overflow-prone conversion.
- The same defect is independently confirmed in historical descendant logs:
  - PR #344 Full Gate [#43342666633](https://github.com/qaqp980520-prog/2126-Survival/actions/runs/43342666633), job `131614480477`: two real Godot errors.
  - PR #345 Full Gate [#43358973711](https://github.com/qaqp980520-prog/2126-Survival/actions/runs/43358973711), job `131667707101`: two real Godot errors.
  - PR #346 Full Gate [#43363044551](https://github.com/qaqp980520-prog/2126-Survival/actions/runs/43363044551), job `131680843434`: two real Godot errors.
  - PR #347 Full Gate [#43372327505](https://github.com/qaqp980520-prog/2126-Survival/actions/runs/43372327505), job `131710737640`: two real Godot errors.
  - PR #363 Full Gate [#43652330458](https://github.com/qaqp980520-prog/2126-Survival/actions/runs/43652330458), job `132623330611`: two real Godot errors.
  - PR #364 Full Gate [#43654319161](https://github.com/qaqp980520-prog/2126-Survival/actions/runs/43654319161), job `132629413357`: two real Godot errors.
- PR #335–#337 exact-head logs were independently scanned and contained zero actual Godot diagnostics; #337 already carries the corrected parser and boundary tests.
- The clean replacement PR #376 also contains the canonical parser, signed-64-bit boundary/overflow tests, retirement behavior, and captured-output portal-director guard. Its exact-head Full Gate [#43905579163](https://github.com/qaqp980520-prog/2126-Survival/actions/runs/43905579163) passed 555/555 with zero actual Godot diagnostics.
- PR #348 carries the corrected parser; its exact-head Full Gate [#43784730281](https://github.com/qaqp980520-prog/2126-Survival/actions/runs/43784730281) and focused file-persistence gate passed with zero actual Godot diagnostics.

## Implementation

- Validate canonical signed-64-bit decimal strings lexically before calling `int()`.
- Accept exact signed-64-bit minimum/maximum; reject overflow, underflow, malformed and non-canonical values before conversion.
- Add exact boundary and overflow/underflow regression coverage while preserving rejected-load atomicity.
- Capture portal-director Godot output, use a 45-second timeout with 5-second hard-kill grace, reject `SCRIPT ERROR`, `ERROR:` and `FAIL:`, and require the exact success marker.

## Files

- `systems/BackroomsPortalDirector.gd`
- `tests/backrooms_portal_director_test.gd`
- `.github/workflows/godot-validation.yml`
- `docs/BACKROOMS_PORTAL_RNG_INT64_SURFACEWORLD_STACK_M0_1_53.md`

## Dependencies and import

- Corrective child PR #383 targets the legacy PR #339 feature branch.
- PR #339 is the first divergent child of the corrected #337 SurfaceWorld spawn-window branch.
- Descendants: #340 → #341 → #342 → #343 → #344 → #345 → #346 → #347 → #348; the #363/#364 entity-spawn descendants branch from #345.
- Godot 4.3; no third-party dependencies, autoloads, Project Settings, scenes or external assets changed.
- Import: `godot --headless --path . --editor --quit`.
- Focused test: `godot --headless --path . --script res://tests/backrooms_portal_director_test.gd`.

## Validation — exact PR #383 HEAD

- Exact branch: `fix/backrooms-portal-rng-int64-surfaceworld-stack-2026-11-17`.
- Tested HEAD: `b4b66a8dcb72dd7cd501464fdd6d20c2f8a6029b`.
- Godot 4.3 Full Gate [#44022569098](https://github.com/qaqp980520-prog/2126-Survival/actions/runs/44022569098), job `133835202631`: 555/555 job-step records successful, 0 failures, 0 skipped.
- Associated PR-triggered workflows: 19/19 successful.
- Portal-director step #22 printed `BackroomsPortalDirector tests passed.` and passed the captured-output diagnostic guard.
- Production SurfaceWorld underground mining integration #213 and randomized terrain soak #443 passed on the same exact HEAD.
- Complete job log: 7,708,465 characters / 84,317 lines. There were 334 raw diagnostic-keyword matches, all from literal CI shell-guard command text; actual timestamped Godot Runtime diagnostics: 0.
- Static patch assertions: parser call-site replaced once; canonical helper inserted once; signed-64-bit min/max and overflow/underflow cases present; raw portal-director workflow command replaced once.
- Local Godot executable unavailable; engine validation ran in GitHub Actions Godot 4.3.

## Branch reconciliation status

- PR #383 is Open / Ready for Review / Mergeable / Unmerged; independent review submissions 0; inline review threads 0.
- PR #339 remains Open / Draft / Unmerged and is not mergeable into #337: 12 commits ahead / 23 behind, diverged from merge base `736a77d2a4243bf9d874922fdbe1eabd59946b44`.
- Integrating #383 into #339 alone does not resolve the #337/#339 ancestry divergence. Any surviving legacy descendants require explicit parent reconciliation and fresh exact-head validation.
- The active replacement PR #376 is already based on the validated #337 head and includes the same canonical parser/boundary tests; #376's own exact-head Full Gate is clean. Therefore #383 is a validated backport for the legacy branch, not a missing fix in the active #376–#381 chain.
- No main merge.

## Scope and limitations

- No gameplay RNG algorithm, portal spawn policy, serialized RNG field format, save schema or entity-spawn behavior changes.
- No `daily_games/` files or commands changed.
- No GPU, graphical Portal Activation, iPhone or target-device performance claim.
- The self-contained portal correction does not reconcile the old #339 branch with #337 or automatically repair downstream branches.

## Next steps

1. Keep #383 available as a validated corrective patch for the legacy #339 stack; obtain independent review before any feature-branch merge.
2. If the legacy #339–#347 stack remains a porting source, propagate the correction only to surviving descendants that still contain the old parser, then rerun each exact-head Full Gate and complete-log scan.
3. Prefer the validated #376–#381 replacement chain for active portal-runtime work; do not duplicate the parser fix there.
4. Reconcile the maze/runtime/save descendants onto the validated replacement chain with file-level conflict review and exact-head tests.
5. Do not merge directly to main.
