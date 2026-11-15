# Backrooms Portal RNG State Int64 Validation — M0.1.24

## Problem

The portal director persists `RandomNumberGenerator.state` as a canonical decimal string. Godot's `String.is_valid_int()` checks integer syntax but does not guarantee that the value fits a signed 64-bit integer. Calling `int()` on an oversized or undersized string emits an engine `ERROR` during save loading, even though the test's boolean assertion can still pass.

## Implementation

- Add `_is_canonical_int64_string(value)` to validate canonical decimal spelling and signed 64-bit bounds before conversion.
- Compare digit lengths and equal-length decimal strings against the positive and negative limits before calling `int()`.
- Preserve canonical-string checks: reject `+1`, leading-zero forms and `-0`.
- Restore the RNG state only after the complete payload has passed validation, preserving atomic load behavior.
- Harden the portal-director CI step to capture output and fail on `SCRIPT ERROR`, `ERROR:` or `FAIL:` instead of accepting a success banner alongside engine errors.

## Regression coverage

- Accept `9223372036854775807` and `-9223372036854775808`.
- Reject positive overflow `9223372036854775808` and negative underflow `-9223372036854775809`.
- Reject much larger positive/negative values, non-numeric strings, `+1`, `01` and `-0`.
- Verify rejected saves leave the complete live save dictionary unchanged.

## Files

- `systems/BackroomsPortalDirector.gd`
- `tests/backrooms_portal_director_test.gd`
- `.github/workflows/godot-validation.yml`
- This version record.

## Dependencies and import

- Parent PR #368 exact HEAD at branch creation: `9a5315d9b45ecfa85c5d3d64a536ae5eb91f38ee`.
- Godot 4.3 headless validation.
- No project import, autoload, input mapping, asset migration or save-schema migration.

## Validation status

A fresh exact-head Full Compatibility Gate and focused portal-director test are required. No pass is claimed until they complete.

## Limitations and next step

This is a defensive save-parser and CI-diagnostic fix; it does not change the save schema or RNG algorithm. After exact-head validation, merge this child into PR #368's feature branch only, then rerun the parent exact-head gate. Do not merge to main.