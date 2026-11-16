# M0.1.50 — Root Godot Test Hard-Kill Grace Coverage

## Purpose

Close the remaining hard-timeout gap in the root-project Godot 4.3 validation workflow. The preceding M0.1.45 audit established that all 117 root-project test steps had a timeout, combined stdout/stderr capture, Godot diagnostic rejection and an exact success marker. A follow-up audit found that 41 of those timeouts sent only the default termination signal and did not guarantee forced termination if a child process ignored it.

## GitHub delivery

- Repository: `qaqp980520-prog/2126-Survival`.
- Parent PR: #378 — Core Godot test output guards.
- Parent exact HEAD: `b8c15f1badf898e61410efb9cd4d1439d299af1e`.
- Branch: `ci/root-godot-test-hard-kill-grace-2026-11-17`.
- Workflow file: `.github/workflows/godot-validation.yml`.
- Version file: `docs/BACKROOMS_ROOT_GODOT_TEST_HARD_KILL_GRACE_M0_1_50.md`.
- Workflow change commit: `3a45dd7c39fba5b5a0c7aff825044817dadd1aac`.

## Change

- Added `-k 5s` to the 41 root-project test commands that previously used `timeout <duration>s` without a kill-after grace.
- Preserved each test's existing primary timeout duration.
- Existing 76 root-project test commands already used `timeout -k 5s` and were left unchanged.
- The 5-second grace allows the normal termination signal first, then sends SIGKILL if the process does not exit.

## Exact static audit

- Root-project Godot test blocks: 117.
- Blocks with `timeout -k 5s`: 117/117.
- Blocks still using TERM-only timeout: 0.
- Blocks capturing combined stdout/stderr: 117/117.
- Blocks rejecting `SCRIPT ERROR`, `ERROR:` and `FAIL:`: 117/117.
- Blocks requiring their exact success marker: 117/117.
- Replacements: exactly 41.
- Legacy standalone KROLL project invocations under `daily_games/`: 0 changed.
- No gameplay source, save schema, scenes, assets, Project Settings, input mappings or third-party dependencies changed.

## Import and validation

- Import: `godot --headless --path . --editor --quit`.
- Validation: PR #380 exact-head Godot 4.3 Full Compatibility Gate and complete job-log diagnostic scan.
- The GitHub Actions run is pending at creation; no engine-test pass is claimed yet.
- Local Godot executable is unavailable; engine validation must run through GitHub Actions.

## Limitations and next steps

1. Complete PR #380 exact-head Full Gate and confirm all 117 root tests pass with the hard-kill grace.
2. Scan the complete log for actual Godot diagnostics, excluding literal shell guard command lines.
3. Obtain independent review.
4. Merge only into PR #378's feature branch after review; rerun PR #378, then continue the parent chain through #377 and #376.
5. Never merge directly to main.
6. GPU visuals, iPhone, target-device performance and playable Portal Activation remain unverified.
