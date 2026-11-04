# KROLL Orbital Foundry M0.1

A standalone Godot 4.3+ crafting-chain and production-budget puzzle.

## Play

- Select a recipe with buttons or keys 1–6.
- N advances after a completed work order.
- R restarts the current order without removing already earned campaign rewards.
- C restarts the campaign and clears its reward ledger.
- On-screen buttons support pointer and touch input.

## Work orders

1. **Sensor Calibration** — combine a circuit board and glass lens into a sensor array. Starting energy: 6; three production actions.
2. **Emergency Power Cell** — produce an alloy plate and circuit board, then assemble a power cell. Starting energy: 9; three actions.
3. **Pressure Transfer Pump** — produce one alloy plate and two circuit boards, then assemble a coolant pump. Starting energy: 13; four actions.

## Recipes

| Output | Inputs | Energy |
|---|---|---:|
| Alloy Plate | 2 iron + 1 carbon | 2 |
| Circuit Board | 1 copper + 1 silicon | 3 |
| Glass Lens | 2 silica | 1 |
| Power Cell | 1 alloy plate + 1 circuit board + 1 polymer | 4 |
| Sensor Array | 1 circuit board + 1 glass lens | 2 |
| Coolant Pump | 1 alloy plate + 2 circuit boards | 5 |

Each completed work order awards 100 points once. Replaying a completed order cannot duplicate its reward. Campaign maximum: 300.

## Import and validation

Open this folder in Godot 4.3 or newer and run main.tscn. The project uses the Compatibility renderer and has no third-party plugins, external assets, audio, network or save dependencies.

- tests/rules_test.gd checks all three recipe chains, exact energy budgets, rejected-action immutability, action limits and reward-once behavior.
- tests/game_smoke_test.gd checks scene controls, button-driven campaigns, restart behavior, scoring and a keyboard shortcut.

This is a deterministic crafting/production puzzle, not a simulation of the full survival-game crafting economy.
