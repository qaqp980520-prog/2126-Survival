# Underground Mining Playground M0.1

## Purpose
Provide the first playable cave-only mining entry point while keeping the surface exploration prototype non-mineable. This is an integration prototype, not the missing production M1.3 world controller.

## Files and dependencies
- Scene: prototypes/UndergroundMiningPlayground.tscn
- Controller: prototypes/UndergroundMiningPlayground.gd
- Test: tests/underground_mining_playground_test.gd
- Dependencies: Godot 4.3, MineralVeinRegistry, MineralChunkController, MineralMiningNode, SurvivalWorldBridge, MineralCatalog and the existing surface prototype scene for negative regression coverage.
- No external assets or add-ons; meshes and cave geometry are generated procedurally.

## Gameplay and integration
- The cave floor is at world Y=-8.0; three registered veins sit below the surface plane.
- The stable chunk ID is underground/cave_0_0.
- F mines the nearest vein within 3.5 world units; the existing MineralMiningNode transfers accepted ore through SurvivalWorldBridge.
- G drops one unit of the most recently mined ore. The HUD reports shared inventory weight, carry limit, movement multiplier and jump permission.
- The chunk controller serializes/restores the mineral registry snapshot.

## Import and tests
Open the repository root project in Godot 4.3+ and choose Underground Mining in the development test hub. The CI integration test verifies stable chunk registration, below-surface placement, mining-to-inventory transfer, vein stock change, save snapshot restore, immediate weight recalculation after drop, and that the surface scene exposes no mining action.

## Limits and next step
- Cave geometry is a single fixed chunk; no procedural cave generation, mining tool durability, animation or multiplayer is included.
- The prototype has a separate inventory instance; it is not yet a persistent production-world session.
- Next: integrate this lifecycle into the actual production world controller and save envelope when that controller is introduced.
