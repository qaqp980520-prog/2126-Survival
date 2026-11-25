## Run 421 — authoritative live-state reconciliation (2026-11-25)

This section is the current checkpoint and supersedes earlier status statements below where they conflict. Historical sections are retained for auditability.

### Repository and root PR #334

- Repository: `qaqp980520-prog/2126-Survival`; current `main`: `7e0eedd2d8ef126ee38f30350fe115814da7c313`.
- Root branch: `integration/backrooms-production-world-and-transition-2026-11-12`; live branch HEAD at the start of Run 421: `8efb5303e95929b16335a31e5e168e444ac52817`.
- PR #334 is Open / Ready for Review / Mergeable / Unmerged; base is `main`; compare is 113 ahead / 0 behind / 27 changed paths.
- Exact-head Godot 4.3 Full Compatibility Gate: [run #45528695970](https://github.com/qaqp980520-prog/2126-Survival/actions/runs/45528695970), job `138918318106`: 555/555 steps successful, 0 failed, 0 skipped.
- Exact-commit PR-triggered workflow matrix: 19/19 successful.
- Full Gate log audited: 7,703,107 characters / 84,264 lines / 77,885 PASS markers. After excluding echoed workflow shell guards: 0 actual Godot Script / Parse / Runtime / ERROR / FAIL diagnostics; 0 ObjectDB leaks; 0 Orphan StringName diagnostics.
- 23 Godot warnings remain and are not claimed fixed: 19 filled `draw_rect()` width warnings, 1 nested KROLL project notice, 1 mineral stale-unload rollback warning, and 2 synchronous mineral-registration rollback warnings. The runner also emitted a Node.js 20 deprecation notice; it is not a Godot runtime warning.
- This root validation is headless Godot 4.3. No dedicated Xvfb/Mesa render, hardware GPU, FPS, mobile-device, or final visual QA is claimed.
- Independent review submissions / inline review threads on #334: 0 / 0. Ready for Review is not approval.

### Child PR #335 and synchronization PR #432

- PR #335 branch: `fix/backrooms-return-session-rollback-2026-11-12`, live branch HEAD `3c59d117d1b0912c902529dbb800d01e662f91ef`; Open / Draft / Unmerged.
- PR #335 metadata currently reports base SHA `7859d9db78648c7d657f8aab91c97592a00228b3`, while the live base branch endpoint for the same base ref reports root HEAD `8efb5303e95929b16335a31e5e168e444ac52817`. This API-level base-SHA discrepancy is recorded rather than silently reconciled. Do not merge #335 until it is resolved by a fresh compare and exact-head validation.
- Sync PR [#432](https://github.com/qaqp980520-prog/2126-Survival/pull/432) targets the #335 feature branch, not main. Its live HEAD is `1121e7ef9b532e849dde005ccf3bcc901aefdc90`; its ordered parents are current root #334 HEAD `8efb5303e95929b16335a31e5e168e444ac52817` followed by #335 child HEAD `3c59d117d1b0912c902529dbb800d01e662f91ef`.
- PR #432 is Open / Ready for Review / Mergeable / Unmerged; compare #335 branch → #432 branch is 3 ahead / 0 behind with exactly one changed path, the inherited root integration document.
- Exact-head Godot 4.3 Full Gate: [run #45532705664](https://github.com/qaqp980520-prog/2126-Survival/actions/runs/45532705664), job `138931688791`: 555/555 steps successful, 0 failed, 0 skipped. This synchronization PR produced one Full Gate workflow; no 19/19 workflow-matrix claim is made.
- Full Gate log audited: 7,703,106 characters / 84,264 lines / 77,885 PASS markers. After excluding echoed workflow shell guards: 0 actual Godot Script / Parse / Runtime / ERROR / FAIL diagnostics; 0 ObjectDB leaks; 0 Orphan StringName diagnostics.
- The same 23 Godot warnings remain; none is claimed fixed.
- The three child #335 blobs are preserved exactly: transition-manager doc `5d864e74c5845360f8b57723d370bd115f3c1e64`, runtime `187ad64d1c5cbc7f1132c58ff3c17c9e3deb0357`, and tests `adc6693288b027f8af99915de5159cd7fd6fa3a6`.
- Independent review submissions / inline threads on #335 and #432: 0 / 0. #335 remains Draft. #432's Ready status is not approval.

### Release boundary and next gate

- The live `main` branch endpoint reports `protected: false`. The branch-protection detail endpoint returns HTTP 403 to this GitHub App; no branch-protection write operation is available. No protection change is claimed.
- No PR or main merge occurred in this checkpoint.
- Before #432 is integrated into #335, require independent review and resolve the #335 base-SHA discrepancy. After integration, rerun #335's exact new HEAD and full-log audit before advancing to #336.
- Do not merge the root or any descendant to `main` until an authorized repository administrator enables required reviews and status checks.

---

# M0.1.138 — Backrooms Root PR Current-Main Ancestry Sync

## Purpose

Record the current-main ancestry synchronization and exact-head validation of the production Backrooms root PR (#334), then define the parent-first child synchronization gate. This is a release/integration asset, not a gameplay feature.

No production code, scene, project setting, save schema, or runtime behavior is changed by this document update.

## Exact Git state before this document closeout

- Repository: `qaqp980520-prog/2126-Survival`.
- Root PR: [#334 — production Backrooms world and transition integration](https://github.com/qaqp980520-prog/2126-Survival/pull/334).
- Root branch: `integration/backrooms-production-world-and-transition-2026-11-12`.
- Root HEAD validated in Run 418: `e5a69d001dc71b0fcee20be7e59bba72da7a15ab`.
- Current main: `7e0eedd2d8ef126ee38f30350fe115814da7c313`.
- Ancestry synchronization commit: `6b5678f34a4a8937111dabe520f19d7c88955fcc`.
- Main-to-root compare at the validated HEAD: **112 ahead / 0 behind / 27 changed files**; merge base is current main.
- Pre-document-closeout backup: `backup/pr334-before-run419-root-doc-reconcile-2026-11-25`, pointing to the validated root HEAD above.

The ancestry-only synchronization added the current main history without changing the root feature tree. The subsequent M0.1.138 documentation closeout is a separate documentation-only commit.

## Exact-head validation already completed on the predecessor

- Tested root HEAD: `e5a69d001dc71b0fcee20be7e59bba72da7a15ab`.
- Exact-head Godot 4.3 Full Compatibility Gate: [run #45524292726](https://github.com/qaqp980520-prog/2126-Survival/actions/runs/45524292726), job `138903656236`.
- Full Gate: **555/555 steps successful**, 0 failures, 0 skipped.
- Associated PR-triggered workflow matrix: **19/19 successful**.
- Full log audit: 7,703,109 characters / 84,264 lines / 77,885 PASS matches. The 334 raw keyword matches were workflow shell-guard command text; after excluding those, there were **0 actual Script / Parse / Runtime / ERROR / FAIL diagnostics**, 0 ObjectDB leaks, and 0 Orphan StringName diagnostics.
- 23 warnings remain and are not claimed fixed: 19 filled `draw_rect()` width warnings, 1 nested KROLL project notice, 1 mineral stale-unload rollback warning, and 2 synchronous mineral-registration rollback warnings.
- This validation was headless Godot 4.3. No dedicated Xvfb/Mesa job, hardware GPU, FPS, mobile-device, or final visual QA is claimed.
- The current document-closeout commit is a new root HEAD and is **not covered by the predecessor's run**. A fresh exact-head Full Gate and full-log audit are required for the resulting commit before any child is advanced.

## Verified direct Backrooms/Hound ancestry

The current direct chain contains **36 PRs**, with PR #381 between #380 and #384:

`#334 → #335 → #336 → #337 → #376 → #377 → #378 → #380 → #381 → #384 → #385 → #386 → #387 → #388 → #389 → #390 → #391 → #392 → #393 → #394 → #395 → #396 → #397 → #398 → #399 → #400 → #402 → #404 → #405 → #406 → #407 → #409 → #428 → #429 → #430 → #431`.

The latest recorded review-submission audit across these 36 PRs returned 0 independent reviews. The root and current child-sync PR review submissions / inline threads were separately read as 0 / 0. Ready for Review is not approval.

## Current child synchronization state — PR #335 and PR #432

- PR #335 branch: `fix/backrooms-return-session-rollback-2026-11-12`, HEAD `3c59d117d1b0912c902529dbb800d01e662f91ef`.
- PR #335's previous exact-head Full Gate [#45522241654](https://github.com/qaqp980520-prog/2126-Survival/actions/runs/45522241654) passed 555/555, but that evidence applies to the old parent/root document state and does not validate a future synchronized HEAD.
- Sync PR [#432](https://github.com/qaqp980520-prog/2126-Survival/pull/432) targets the #335 feature branch, not main. Its exact HEAD is `af09b27b0464965f5d65db668e6ea90770338d06`.
- PR #432 exact-head Godot 4.3 Full Gate [#45525903154](https://github.com/qaqp980520-prog/2126-Survival/actions/runs/45525903154), job `138909023548`: **555/555 steps successful**, 0 failures, 0 skipped. This sync PR produced one Full Gate workflow; no 19/19 workflow-matrix claim is made.
- PR #432 full-log audit: 7,703,106 characters / 84,264 lines / 77,885 PASS matches; 0 actual Script / Parse / Runtime / ERROR / FAIL diagnostics after excluding shell guards; 0 ObjectDB leaks; 0 Orphan StringName.
- 23 warnings remain: 19 filled `draw_rect()` width warnings, 1 nested KROLL project notice, 1 mineral stale-unload rollback warning, and 2 synchronous mineral-registration rollback warnings.
- A fresh compare of the #335 base branch to the #432 sync branch reports **diverged: 4 ahead / 8 behind**, merge base `7859d9db78648c7d657f8aab91c97592a00228b3`, with four paths in the merge-base diff. This is not a fast-forward; GitHub currently reports the PR mergeable, but integration must preserve both histories and be followed by a new #335 exact-head gate.
- The three intended #335 child file blobs match exactly between the #335 base and #432 head:
  - `docs/BACKROOMS_TRANSITION_MANAGER_M0_0_8.md`: `5d864e74c5845360f8b57723d370bd115f3c1e64`
  - `systems/BackroomsTransitionManager.gd`: `187ad64d1c5cbc7f1132c58ff3c17c9e3deb0357`
  - `tests/backrooms_transition_manager_test.gd`: `adc6693288b027f8af99915de5159cd7fd6fa3a6`
- The fourth changed path is this inherited root integration document. Its blob on #432 currently matches the root predecessor document, but this document-closeout update must also be propagated into #432 and validated before #432 is integrated into #335.
- PR #432 review submissions / inline threads: 0 / 0. PR #335 remains Draft until the root document update is propagated and its new exact HEAD passes.

## Dependencies and import

- Parent: PR #334 root branch, itself based on repository main `7e0eedd2d8ef126ee38f30350fe115814da7c313`.
- Child: PR #335 return-session rollback; sync PR #432 targets its feature branch.
- No third-party dependencies, autoloads, scenes, project settings, or import steps.
- Documentation-only asset; no Godot resource import is required.

## Release governance and limitations

- main protection was last live-verified disabled: `protected: false`, required status checks off, repository rulesets empty.
- The branch-protection detail endpoint returned 403 to the connected GitHub App; the connected GitHub tools expose no branch-protection/ruleset write action. No protection change is claimed.
- Do not merge the root or any child to main until an authorized administrator enables required pull-request review/status checks and an independent review is submitted.
- Do not merge PR #432 into #335 before independent review. After the root document closeout is validated, propagate the exact new root document blob and ancestry into #432 while preserving the three child blobs, rerun #432's exact-head gate, then integrate it into #335 only after review. Rerun #335's exact new HEAD before advancing to #336.
- No PR or main merge is included in this document update.
