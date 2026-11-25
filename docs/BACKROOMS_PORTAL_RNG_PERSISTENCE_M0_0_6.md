# Backrooms Portal RNG Persistence — M0.0.6

## Purpose

Make portal save/load preserve the deterministic RandomNumberGenerator stream. The previous schema-1 payload stored the countdown, serial and active portal position, but omitted RNG state. A restored director created with a different seed could reproduce the visible active portal yet choose a different destination or next spawn position after loading.

## Runtime change

- Add the current Godot RandomNumberGenerator state to new portal save dictionaries as a decimal-string rng_state, preserving the full signed 64-bit value through JSON serialization.
- Restore the saved canonical decimal integer state after validating the entire candidate payload and before applying the remaining scalar/portal fields.
- Keep schema_version at 1 and accept legacy schema-1 payloads without rng_state or active-portal spawn_bounds; legacy active portals are validated against the receiving director's current world_bounds, and legacy payloads without rng_state retain the constructor RNG state.
- Save the bounds snapshot used when an active portal was created. Loading validates that portal against its saved bounds rather than the director's current candidate-spawn window, so a future player-relative spawn window can move without invalidating an already-active portal.
- Reject malformed and out-of-range rng_state strings and malformed spawn-bounds snapshots atomically; the parsed signed integer must stringify back to the exact canonical decimal text. The stored decimal string is expected to come from this director's own RandomNumberGenerator.state snapshot; Godot documents that arbitrary state values must not be supplied, so the loader cannot prove the internal PCG provenance of a manually edited integer string. The string representation also avoids losing precision when the signed 64-bit state passes through JSON.

## Files

- systems/BackroomsPortalDirector.gd
- tests/backrooms_portal_director_test.gd
- docs/BACKROOMS_PORTAL_RNG_PERSISTENCE_M0_0_6.md

## Dependencies and import

- Godot 4.3 RandomNumberGenerator.state.
- Existing BackroomsPortalDirector and portal save schema 1.
- No third-party dependencies, scene changes, Project Settings changes or new autoloads.
- Repository-root import: godot --headless --path . --import.
- Focused test: godot --headless --path . --script res://tests/backrooms_portal_director_test.gd.

## Regression coverage

- Save an active portal from a seeded director.
- Load it into a director constructed with a different seed.
- Verify the saved payload round-trips, portal consumption chooses the same destination, the next spawn countdown matches, and the next spawned portal position is identical.
- Verify a legacy schema-1 payload without rng_state or active-portal spawn_bounds still loads when its active portal is inside the receiving director's current bounds.
- Move the candidate spawn bounds after creating an active portal, then save/load into a director with the new bounds; verify the old portal remains valid while the next portal is generated inside the new bounds.
- Verify malformed non-integer rng_state strings and malformed/out-of-range spawn-bounds snapshots are rejected without mutating the director, and verify the saved state survives JSON.stringify/JSON.parse_string exactly.

## Validation status

- Requires an exact-head Godot 4.3 Full Compatibility Gate on the PR branch.
- Local Godot is unavailable in this execution environment; no local engine run is claimed.
- This is Backrooms portal persistence groundwork for the prototype; it does not integrate the Backrooms director into production SurfaceWorld or change portal placement policy.

## Next steps

1. Run the exact-head Godot 4.3 Full Compatibility Gate and focused Backrooms portal director test.
2. Keep the PR Draft and unmerged until exact-head CI and independent review complete.
3. When production Backrooms integration is designed, include portal RNG state in the existing WorldSession save/restore transaction.


## Run 217 — parser boundary and legacy-stream regression hardening

- Clarified the loader contract: a new save carries a canonical decimal representation of the RNG state; the code does not claim that zero is an invalid state.
- Extended malformed-state regression coverage to include positive and negative signed-64-bit overflow strings, non-canonical decimal forms (`+1`, `01`, `-0`), and a non-string numeric JSON value.
- Every rejected payload is checked against the complete pre-load save dictionary to prove that the director's RNG and portal state remain unchanged.
- Strengthened schema-1 legacy compatibility: a payload without `rng_state` must load while retaining the receiving director's constructor RNG stream, rather than silently adopting the source director's state.
- Dependencies and import remain unchanged: Godot 4.3; `godot --headless --path . --import`; focused test `godot --headless --path . --script res://tests/backrooms_portal_director_test.gd`.
- These are test and documentation hardening changes; exact-head Full Compatibility Gate must be rerun after the commits. No local Godot executable is available.
