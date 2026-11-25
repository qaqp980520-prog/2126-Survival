# M0.1.138 — Backrooms Root PR Current-Main Ancestry Sync

## Purpose

Record the ancestry-only synchronization of the Backrooms production root integration PR (#334) with the current repository main branch and its exact-head validation before the parent-first review/integration cycle.

This is a release/integration asset, not a gameplay feature. It does not change production code, scenes, project settings, save formats, or runtime behavior.

## Exact Git state

- Repository: `qaqp980520-prog/2126-Survival`.
- Root PR: [#334 — production Backrooms world and transition integration](https://github.com/qaqp980520-prog/2126-Survival/pull/334).
- Root branch: `integration/backrooms-production-world-and-transition-2026-11-12`.
- Previous root HEAD: `0d4c7ee8cc8ce53c05d48c04a80cfa0c82f0e668`.
- Current main: `7e0eedd2d8ef126ee38f30350fe115814da7c313`.
- Ancestry synchronization commit: `6b5678f34a4a8937111dabe520f19d7c88955fcc`.
- Merge parents, in order: previous root HEAD, then current main.
- Feature tree immediately before and after the ancestry-only merge: `5652ce37589bd71d452cef5a0dad33ee25ff6edf` (unchanged).
- Main tree SHA: `ab260a195db23943b0adf3cd46702c30c0cf9a39`; the previous main baseline `65b2cabc751637729d58f64c9633f888d3c8b74c` has the same tree SHA.
- Pre-closeout safety backup: `backup/pr334-before-current-main-sync-2026-11-25-run416`, pointing to `0d4c7ee8cc8ce53c05d48c04a80cfa0c82f0e668`.
- Second safety backup before this documentation closeout: `backup/pr334-before-m0138-doc-closeout-2026-11-25-run417`, pointing to `7859d9db78648c7d657f8aab91c97592a00228b3`.

The two newer main commits changed ancestry but returned the tree to the former baseline. The ancestry-only synchronization therefore added main ancestry without changing the root PR feature tree.

## Live comparison after synchronization

- Current root HEAD: `7859d9db78648c7d657f8aab91c97592a00228b3`.
- main to root HEAD: **111 commits ahead / 0 behind**.
- Merge base: current main `7e0eedd2d8ef126ee38f30350fe115814da7c313`.
- Changed files: **27**.
- PR #334: Open / Ready for Review / Mergeable / Unmerged.
- No main merge was performed.

## Exact-head validation — completed

- Exact root HEAD: `7859d9db78648c7d657f8aab91d3` (full SHA: `7859d9db78648c7d657f8aab91c97592a00228b3`).
- Exact-head GitHub Actions run: [45515736442](https://github.com/qaqp980520-prog/2126-Survival/actions/runs/45515736442).
- Full Compatibility Gate job ID: `138874586192`; **555/555 steps successful**, 0 failures, 0 skipped.
- The exact commit has **19/19** associated focused/full validation workflows completed successfully.
- Full Gate log audit: 7,703,099 characters / 84,264 lines / 77,885 PASS markers; 0 actual `SCRIPT ERROR:`, `ERROR:`, or `FAIL:` diagnostics after excluding literal workflow guard commands; 0 ObjectDB leaks; 0 Orphan StringName.
- 23 warnings remain: 19 filled `draw_rect()` width warnings, 1 nested KROLL project notice, 1 mineral stale-unload rollback warning, and 2 synchronous mineral-registration rollback warnings. None is claimed fixed.
- No dedicated Xvfb/Mesa job ran on this root branch; no hardware GPU, FPS, mobile, or final visual QA is claimed.
- The root Full Gate was headless Godot 4.3. No local Godot executable is available.

## Verified direct Backrooms/Hound ancestry

The current direct chain contains **36 PRs**. PR #381 is the required link between #380 and #384:

`#334 → #335 → #336 → #337 → #376 → #377 → #378 → #380 → #381 → #384 → #385 → #386 → #387 → #388 → #389 → #390 → #391 → #392 → #393 → #394 → #395 → #396 → #397 → #398 → #399 → #400 → #402 → #404 → #405 → #406 → #407 → #409 → #428 → #429 → #430 → #431`.

Fresh review-submission queries on all 36 PRs returned **0 independent reviews**. Inline review threads on the checked root/leaf PRs also remain 0. This is a human-review blocker, not a CI failure.

## Dependencies and import

- Parent: repository `main` at `7e0eedd2d8ef126ee38f30350fe115814da7c313`.
- Root feature tree: previous PR #334 HEAD `0d4c7ee8cc8ce53c05d48c04a80cfa0c82f0e668`.
- No third-party dependencies or import steps.
- Documentation-only asset; no Godot resource import is required.

## Release governance and limitations

- Live main branch endpoint reports `protected: false`; required status checks are off.
- Repository rulesets endpoint returns an empty list.
- The branch-protection detail endpoint returns 403 to the connected GitHub App, and no branch-protection write action is exposed. No protection change is claimed.
- Do not merge the root or any child to main until an authorized administrator enables required pull-request review/status checks and an independent review is submitted.
- PR #335 was synchronized to this root in Run 417 and passed its own exact-head Godot 4.3 Full Gate 555/555 at HEAD `3c59d117d1b0912c902529dbb800d01e662f91ef`. This root-document closeout creates a new root HEAD; PR #335 must be synchronized to that new root and rerun before moving to #336.
- Next: run exact-head Godot 4.3 Full Gate and full-log audit on the updated root document commit; then propagate the new root HEAD into #335, rerun #335 exact-head validation, and continue one direct child at a time, parent-first.
