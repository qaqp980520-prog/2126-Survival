# Surface Terrain Overlay Nested Container Copy-on-Write — M0.3.21

## Purpose

Close the M0.3.19/M0.3.20 prototype's nested-container isolation gap. A sealed overlay previously protected only its top-level write/tombstone maps: callers could still mutate nested Array/Dictionary values through the source Dictionary, get_value(), materialize(), or internal snapshot accessors.

M0.3.21 adds explicit nested Array/Dictionary copy-on-write semantics without wiring the prototype into the production Index, Binder, MineralChunkController, or Collider Manager.

## Files

- systems/SurfaceTerrainOverlayMap.gd — deep-copy nested containers at root construction and set; defensive copies on read/materialize/accessors; callback-based mutate_value() commits a detached copy.
- tests/surface_terrain_adjacency_index_test.gd — source isolation, detached reads, parent/child/grandchild COW, Array and Dictionary mutation, retained callback reference isolation, caller-owned input isolation, materialize/accessor isolation, compaction isolation.
- tests/surface_terrain_adjacency_delta_benchmark.gd — four nested-container fixtures (225/576/2,048/8,192 entries), five samples, nine transactions, eight nested updates, four removals, four insertions; Dictionary deep-copy oracle versus overlay fork/COW path including depth-eight compaction.
- .github/workflows/surface-terrain-adjacency-spatial-index-validation.yml — watches the overlay implementation path and requires four COW JSONL records with the existing six adjacency records.
- docs/SURFACE_TERRAIN_OVERLAY_MAP_NESTED_COW_M0_3_21.md — this version record.

## API contract

- Root construction deep-copies nested Array/Dictionary values.
- get_value() returns detached deep copies for Array/Dictionary values; scalar/value types remain direct values.
- mutate_value(key, callable) gives the callback a detached Array/Dictionary copy and commits a second deep copy. A retained callback reference cannot mutate the committed snapshot. A callback returning false aborts the mutation.
- set_value() deep-copies caller-owned Array/Dictionary inputs.
- materialize(), _get_base_dictionary(), and _get_overlay_changes() return detached nested containers.
- Compaction takes ownership of the detached materialized Dictionary without a second root copy.
- get_stats() reports nested-container clone calls.

The supported mutable-container contract is limited to built-in Array and Dictionary values. Object/Resource references are not duplicated; callers must keep them immutable while stored or represent them by stable IDs and manage them outside the overlay.

## Benchmark protocol

For each of 225, 576, 2,048, and 8,192 entries, five samples execute nine sequential transactions. Each transaction updates eight nested records, removes four keys, inserts four keys, and verifies touched-key checksums and cached size. The Dictionary path deep-copies the complete snapshot per transaction. The overlay path forks and clones only accessed nested containers, with the ninth fork including depth-eight compaction. Final materialized Dictionary parity is checked outside the timed interval.

This is a synthetic headless data-structure benchmark. It is not production SurfaceWorld, GPU, rendered FPS, mobile, or target-device evidence. Results must be interpreted alongside the depth-eight compaction cost; no speedup is claimed until exact-head artifacts are downloaded and independently parsed.

## Dependencies and execution

- Godot 4.3 root project; no third-party packages, autoloads, scenes, Project Settings, production controller wiring, or save-schema changes.
- Focused workflow: Surface Terrain Adjacency Spatial Index Validation.
- Focused contract command:

~~~sh
godot --headless --path . --script res://tests/surface_terrain_adjacency_index_test.gd
~~~

- Combined adjacency, depth-one, depth-eight, and nested-COW benchmark command:

~~~sh
godot --headless --path . --script res://tests/surface_terrain_adjacency_delta_benchmark.gd
~~~

## Validation status at creation

Pending exact-head GitHub Actions Godot 4.3 focused, production benchmark, and Full Compatibility Gate workflows. No local Godot executable is available in this run. Do not claim the code or benchmark passes until all exact-head workflows finish and the full logs/artifact are checked.

## Limitations and next step

- This remains an isolated prototype; no production Index/Controller/Binder/Collider adoption.
- Root construction, defensive read copies, materialization, and depth-eight compaction remain O(N) at their explicit boundaries.
- The overlay does not yet provide an atomic multi-map transaction or clone-on-write for arbitrary Object/Resource values.
- The current production radius-8 path remains dominated by the full Binder rebuild. After parent review, adapt the existing current-API transaction pattern and preserve the full Binder rebuild as the correctness/recovery oracle.
