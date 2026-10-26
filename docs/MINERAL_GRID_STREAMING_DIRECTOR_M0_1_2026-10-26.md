# Mineral Grid Streaming Director M0.1 — 2026-10-26

## Purpose
Add a spatial coordination layer that selects a square set of chunk coordinates around a world position and asks the existing MineralChunkController to own the corresponding chunk roots.

## API
- `bind_controller(controller)`: connect to the mineral chunk controller.
- `bind_chunk_factory(callable)`: supply a synchronous generator callback taking a `Vector2i` coordinate and returning a new, unparented `Node3D` chunk root (or null on failure).
- `sync_to_world_position(position, now_unix)`: load the desired grid before unloading stale managed chunks.
- `get_managed_chunk_ids()`: sorted IDs currently managed by the director.

Chunk IDs are deterministic: `surface/chunk_<x>_<z>`. Coordinates use `floor(world_x / chunk_size_x)` and `floor(world_z / chunk_size_z)`, including negative coordinates.

## Failure behavior
If any desired chunk cannot be generated or registered, newly loaded chunks from that sync attempt are rolled back and the previous active set is retained. Stale chunks are unloaded only after every desired chunk has loaded successfully. A stale-chunk unload failure returns false and retains its management record for retry.

## Validation
The Godot 4.3 CI test covers a radius-one 3x3 neighborhood, movement to another grid cell, stale chunk unload, and a generator failure that must preserve the previous active set.

## Limits
This is a synchronous streaming director prototype, not a terrain generator. It does not create terrain, load PackedScenes asynchronously, select biomes, or wire itself to a player/world scene. A production world generator must provide the chunk factory and call this director as the player moves. No local GUI or iPhone test is claimed.
