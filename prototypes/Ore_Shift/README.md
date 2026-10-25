# Ore Shift — KROLL Mine (Godot 4)

A small 2D mining game prototype for the daily hand-built game project.

## Run
1. Install Godot 4.2 or newer.
2. Open `project.godot` in Godot.
3. Press **F6** (or run the project with **F5**).

## Controls
- **WASD / Arrow keys**: move one tile; trying to walk into a block turns you toward it.
- **Hold Space**: continuously mine the block in front of you.
- **1**: select pickaxe.
- **2**: select KROLL drill.
- **R**: repair the selected tool at the surface (top two rows).
- **Enter**: restart after completing the contract.

## Prototype mechanics
- Randomly generated 12×12 mining grid with a two-row surface zone.
- Rock, iron, copper, and crystal blocks have different hardness and remaining quantities.
- Ore amounts are finite. Each successful mining cycle yields a fixed amount, capped by the remaining quantity in the block.
- Tool and mineral hardness jointly determine mining time.
- An actual mining attempt against a block consumes durability even if the selected tool is too weak to extract it. Releasing Space or aiming at empty space consumes no durability.
- Different tools have different power, speed, durability, and wear values.
- Goal: collect at least 18 units and return to the surface.

## Status and limitations
- The gameplay numbers, free surface repair station, and one-screen 2D presentation are prototype-only simplifications, not final decisions for `2126 Survival`.
- Exact durability values, repair materials/costs, regeneration timing, and mining-machine details remain open in the broader design.
- Keyboard input only; touch controls have not been implemented.
- The original ZIP is not stored in this repository; the source files are committed individually.

## Validation status
Files were reviewed statically. A Godot executable is not available in the current environment, so the project has **not** been launched or runtime-tested here. Open it in Godot 4.2+ to validate parsing, rendering, and input behavior.
