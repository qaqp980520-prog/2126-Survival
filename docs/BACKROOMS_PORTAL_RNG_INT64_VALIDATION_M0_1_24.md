# M0.1.24 — Backrooms Portal RNG State Int64 Validation (save-stack backport)

## Purpose

Backport the signed-64-bit RNG save-state guard to the separate SurfaceWorld file-persistence stack so that integrating the save branch cannot reintroduce the Godot integer-conversion diagnostic fixed on the entity/visual branch.

## Problem

`String.is_valid_int()` checks integer syntax but does not guarantee signed 64-bit representability. Calling `int()` on an oversized positive or negative decimal string can emit a Godot engine `ERROR:` before the save is rejected. The original save-stack portal-director workflow did not inspect captured output, so this diagnostic could be hidden behind a successful test banner.

## Implementation

- Require `rng_state` to remain a String.
- Validate canonical decimal spelling and the full signed-64-bit range lexically before conversion.
- Accept `-9223372036854775808` through `9223372036854775807`.
- Reject immediate overflow/underflow, oversized values, malformed strings, `+1`, leading zeros, `-0`, and non-String variants.
- Keep save-load mutation atomic.
- Harden the Backrooms portal-director CI step to fail on `SCRIPT ERROR`, `ERROR:` or `FAIL:`.

## Files

- `systems/BackroomsPortalDirector.gd`
- `tests/backrooms_portal_director_test.gd`
- `.github/workflows/godot-validation.yml`
- `docs/BACKROOMS_PORTAL_RNG_INT64_VALIDATION_M0_1_24.md`

## Dependencies and integration

- Parent PR #350 exact HEAD: `efb532e7dc8ce6898ea2c1eb221a5851e14c8ead`.
- Parent branch: `fix/world-envelope-file-store-create-parent-dirs-2026-11-13`.
- Child branch: `fix/backrooms-portal-rng-int64-save-stack-2026-11-15`.
- Godot 4.3 headless validation.
- No new project import, autoload, input mapping, dependency, save-schema migration, or public API.

## Validation

Pending exact-head Godot 4.3 Full Compatibility Gate and portal-director test step for PR #372. No pass is claimed until the corrected child HEAD completes.

## Limits and next step

This is a defensive parser and CI-diagnostic backport only. It does not change the RNG algorithm, portal spawn policy, save schema, or gameplay. After exact-head validation, merge into PR #350's feature branch only, then rerun PR #350's exact-head Full Compatibility Gate and focused file-persistence workflow. Never merge this stack directly to main.
