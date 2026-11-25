# M0.1.138 — Backrooms Root PR Current-Main Ancestry Sync

## Purpose

Record the ancestry-only synchronization of the Backrooms production root integration PR (#334) with the current repository main branch before the next parent-first validation cycle.

This is a release/integration asset, not a gameplay feature. It does not change production code, scenes, project settings, save formats, or runtime behavior.

## Exact Git state

- Repository: `qaqp980520-prog/2126-Survival`.
- Root PR: [#334 — production Backrooms world and transition integration](https://github.com/qaqp980520-prog/2126-Survival/pull/334).
- Root branch: `integration/backrooms-production-world-and-transition-2026-11-12`.
- Previous root HEAD: `0d4c7ee8cc8ce53c05d48c04a80cfa0c82f0e668`.
- Current main before synchronization: `7e0eedd2d8ef126ee38f30350fe115814da7c313`.
- Ancestry synchronization commit: `6b5678f34a4a8937111dabe520f19d7c88955fcc`.
- Merge parents, in order: previous root HEAD, then current main.
- Tree SHA before and after synchronization: `5652ce37589bd71d452cef5a0dad33ee25ff6edf` (unchanged).
- Safety backup: `backup/pr334-before-current-main-sync-2026-11-25-run416`, pointing to the previous root HEAD.

The previous main baseline `65b2cabc751637729d58f64c9633f888d3c8b74c` and current main have the same tree SHA `ab260a195db23943b0adf3cd46702c30c0cf9a39`. The two newer main commits changed ancestry but returned the tree to the former baseline. The synchronization therefore adds main ancestry without changing the root PR's file tree.

## Live comparison after synchronization

- main to root HEAD: 111 commits ahead / 0 behind.
- Merge base: current main `7e0eedd2d8ef126ee38f30350fe115814da7c313`.
- Changed files: 27 (including this root-sync record).
- PR #334: Open / Ready for Review / Mergeable / Unmerged.
- No main merge was performed.

## Validation

- The ancestry merge commit preserves the original feature tree SHA; the subsequent commit adds only this documentation record.
- Exact-head GitHub Actions validation for `7859d9db78648c7d657f8aab91c97592a00228b3` passed: 19/19 workflows and Full Gate 555/555.
- Full Gate log audit: 7,703,099 characters / 84,264 lines / 77,885 PASS markers; 0 actual Godot Script/Parse/Runtime/ERROR/FAIL diagnostics; 0 ObjectDB leaks; 0 Orphan StringName.
- 23 unsuppressed warnings remain: 19 filled `draw_rect()` width warnings, 1 nested KROLL project notice, 1 mineral stale-unload rollback warning, and 2 synchronous mineral-registration rollback warnings.
- No dedicated Xvfb/Mesa job ran on the root branch; no hardware GPU, FPS, mobile, or final visual QA is claimed.

## Dependencies and import

- Parent: repository `main` at `7e0eedd2d8ef126ee38f30350fe115814da7c313`.
- Root feature tree: previous PR #334 HEAD `0d4c7ee8cc8ce53c05d48c04a80cfa0c82f0e668`.
- No third-party dependencies or import steps.
- Documentation-only asset; no Godot resource import is required.

## Limitations and next steps

- PR #334 is the root of a 36-PR Backrooms/Hound ancestry chain; descendants must be synchronized and revalidated parent-first after the root is reviewed.
- Independent review submissions on the checked root were zero at the last audit.
- main currently reports `protected: false`; repository rulesets are empty. The connected GitHub integration cannot write branch-protection settings.
- Do not merge the root or any child to main until an authorized maintainer enables required review/status-check protection and the root has independent review.
- Run exact-head Godot 4.3 Full Gate and focused workflows, audit logs, then update the PR, asset catalog, and daily work record with final evidence.
