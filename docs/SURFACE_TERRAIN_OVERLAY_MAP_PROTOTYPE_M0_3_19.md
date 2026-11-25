# Surface Terrain Persistent Overlay Map Prototype — M0.3.19

## Purpose

Evaluate a bounded-depth persistent overlay map as a candidate replacement for the O(N)-class shallow Dictionary copies still present in the SurfaceTerrainAdjacencyIndex delta planner.

This is an isolated data-structure prototype. It is not yet used by SurfaceTerrainAdjacencyIndex, MineralChunkController, the collider manager, or the production streaming path. No production performance improvement is claimed.

## API and behavior

- `new(base)` creates a root snapshot with one shallow Dictionary copy.
- `fork()` creates a writable child without enumerating/copying the visible key set and seals the parent.
- `set_value(key, value)` writes or overrides one key in the child.
- `erase_key(key)` records a tombstone for one visible key.
- `has_key` and `get_value` resolve through at most eight overlay layers.
- `size()` uses a cached visible count.
- `keys()` and `materialize()` are explicit O(N) boundaries.
- `compact()` materializes one independent root. `fork()` automatically compacts when the current depth reaches eight, bounding lookup depth.

The base snapshot is immutable by contract after construction. A fork seals its parent; mutations against sealed snapshots are rejected. Descendants own only their local write and tombstone dictionaries. Materialization walks the chain once from root to leaf and applies each layer, rather than materializing every ancestor separately.

## Files

- `systems/SurfaceTerrainOverlayMap.gd`
- `tests/surface_terrain_overlay_map_test.gd`
- `tests/surface_terrain_overlay_map_benchmark.gd`
- `.github/workflows/surface-terrain-overlay-map-validation.yml`
- `docs/SURFACE_TERRAIN_OVERLAY_MAP_PROTOTYPE_M0_3_19.md`

## Dependencies and import

- Godot 4.3 root project.
- No third-party dependencies, autoloads, scenes, Project Settings, or save-schema changes.
- Run the contract test with `godot --headless --path . --script res://tests/surface_terrain_overlay_map_test.gd`.
- Run the matched benchmark with `godot --headless --path . --script res://tests/surface_terrain_overlay_map_benchmark.gd`.
- GitHub Actions uses `barichello/godot-ci:4.3`.

## Benchmark protocol

- Fixture sizes: 225, 576, 2,048, and 8,192 entries.
- Seven matched samples per size.
- Each sample performs eight replacements, four removals, four insertions, and 32 lookups.
- Baseline: shallow `Dictionary.duplicate(false)` plus the same edits/lookups.
- Overlay: `fork()` plus the same edits/lookups.
- Overlay `materialize()` is timed separately because a production integration would retain the persistent snapshot rather than flatten it after every transaction.
- Every sample compares the fully materialized overlay against the Dictionary oracle and checks lookup checksum and cached size.

## Complexity and safety limits

- Root construction copies the base Dictionary once: O(N).
- `fork`, single-key write, and single-key tombstone are expected O(1) average operations.
- `has_key`/`get_value` are O(depth), bounded by eight overlay layers before compaction.
- `size` is O(1).
- `keys`, `materialize`, and `compact` are O(N).
- Periodic compaction deliberately trades an occasional O(N) flatten for bounded lookup depth.
- This utility does not make the complete Index plan O(Δ). The current Index still scans candidate instance records, copies/updates other graph maps, and may traverse a broad connected corner closure.
- A caller must not mutate the base Dictionary outside the overlay after ownership is transferred. Production adoption requires a single owner for the committed snapshot and a transaction design that never exposes mutable backing maps.
- The full Binder rebuild remains the correctness and recovery oracle.

## Validation status

Pending exact-head Godot 4.3 contract, benchmark, and full compatibility workflows. No benchmark result or production adoption is claimed until the exact PR HEAD completes all required workflows and the logs are audited.

## Next step

After validation, compare the measured overlay stage and materialization costs at all four sizes. If the overlay is beneficial without excessive read/materialization cost, adapt only the `entries_by_stable_id` and bucket maps first behind a feature-local transaction candidate, preserve the existing Dictionary getters, and add failure-injection tests before migrating corner graph maps. Do not replace all seven maps in one change.