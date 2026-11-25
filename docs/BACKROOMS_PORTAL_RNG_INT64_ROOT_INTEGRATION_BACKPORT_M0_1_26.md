# M0.1.26 — Backrooms Portal RNG Int64 Guard on Root Integration Stack

## Purpose

Backport the already-validated signed-64-bit RNG save-state parser and strict portal-director CI diagnostic guard to the root Backrooms production integration PR #334. This closes a real false-green validation gap found in the root integration branch.

## Evidence that triggered the fix

- Root integration PR #334 exact HEAD: `7aa0abecea19d562897c4b4cd52cb11aaeb23258`.
- Historical Godot Full Compatibility run: [#43200651446](https://github.com/qaqp980520-prog/2126-Survival/actions/runs/43200651446).
- Job: `131122884727` (Godot Full Compatibility Gate), which completed successfully at the workflow level.
- The portal-director test step on that exact HEAD ran the raw command `godot --headless --path . --script res://tests/backrooms_portal_director_test.gd` without capturing output or rejecting engine diagnostics.
- The job log nevertheless contains two real Godot 4.3 engine errors from oversized RNG strings:
  - `Cannot represent 999999999999999999999999999999999999999999 as a 64-bit signed integer`.
  - `Cannot represent -999999999999999999999999999999999999999999 as a 64-bit signed integer`.
- The test printed its success banner after those diagnostics, so the old workflow reported green despite engine errors.

## Implementation

- Validate canonical decimal spelling and signed-64-bit bounds lexically before converting the saved RNG state to `int`.
- Accept the exact signed-64-bit minimum and maximum.
- Reject positive overflow, negative underflow, oversized values, malformed strings, non-canonical forms (`+1`, leading zero, `-0`) and non-String values without invoking an overflowing conversion.
- Preserve load atomicity: every rejected payload leaves the live director save dictionary unchanged.
- Replace the raw portal-director CI command with a 45-second bounded Bash step that captures output, rejects `SCRIPT ERROR`, `ERROR:` and `FAIL:`, and requires the exact success marker.

## Files

- `systems/BackroomsPortalDirector.gd`
- `tests/backrooms_portal_director_test.gd`
- `.github/workflows/godot-validation.yml`
- This version record.

## Dependencies and integration

- Child of root integration PR #334.
- Base branch: `integration/backrooms-production-world-and-transition-2026-11-12`.
- Base exact HEAD at branch creation: `7aa0abecea19d562897c4b4cd52cb11aaeb23258`.
- The same parser helper and strict portal-director CI contract already exist on the later save and entity/visual child stacks (PR #372 and PR #371). This root backport aligns the ancestor so the known diagnostic is not present in the root candidate and the descendant stacks converge on identical source behavior.
- No new dependency, autoload, Project Settings, input mapping, RNG algorithm, portal spawn policy, save schema, or save migration is introduced.

## Validation status

Pending exact-head Godot 4.3 Full Compatibility Gate. The historical run above is not accepted as a clean pass because its log contains the two engine errors. No new pass is claimed until the focused portal-director step and full gate complete on this branch's exact HEAD.

## Limits and next step

- This is a defensive parser, regression-test and CI-diagnostic fix only; it does not change gameplay or the serialized RNG field format.
- Local Godot executable is unavailable in this environment; engine validation must run in GitHub Actions Godot 4.3.
- After the exact-head focused and full gates pass, obtain independent review and merge this child into PR #334's integration branch only. Then reconcile downstream PR #335–#350 and #363–#368 base chains; do not merge directly to main.
