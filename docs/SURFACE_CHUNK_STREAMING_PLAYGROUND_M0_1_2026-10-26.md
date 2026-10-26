# Surface Chunk Streaming Playground M0.1

## Purpose

This is an executable integration playground for the existing MineralVeinRegistry, MineralChunkController, and MineralGridStreamingDirector. It demonstrates a moving 3D player, a synchronous factory that creates primitive ground chunks and one finite mineral vein per chunk, stable-ID registration, chunk unload/reload, and a small versioned save envelope.

## Files

- prototypes/SurfaceChunkStreamingPlayground.tscn
- prototypes/SurfaceChunkStreamingPlayground.gd
- systems/MineralGridStreamingDirector.gd (existing)
- systems/MineralChunkController.gd (existing)
- systems/MineralVeinRegistry.gd (existing)
- systems/MineralMiningNode.gd (existing)
- tests/surface_chunk_streaming_playground_test.gd

## Run

Open the repository root project in Godot 4.3+, then open prototypes/SurfaceChunkStreamingPlayground.tscn and run the scene. WASD moves, Space jumps, right mouse button captures the cursor for look, and Esc releases it.

## Validation

The root-project CI imports the root project before running the integration test. The test checks the initial 3x3 active window, movement across chunk coordinates, unloaded vein retention, save/restore of player position and mineral stock, stable-ID re-registration, and invalid schema rejection.

## Limits

This is a playable integration playground, not the production M1.3 world generator. Chunk generation is synchronous and uses primitive geometry. It has no asynchronous scene loading, biome/terrain generation, network replication, or iPhone touch controls. GUI play and iPhone device testing are still separate acceptance tasks.
