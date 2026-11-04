# KROLL Tidal Lock Operator M0.1

A standalone Godot 4.3+ hydraulic logic puzzle. Move a vessel from a lower basin to an upper basin by matching chamber water levels, operating one gate at a time, and respecting the action budget.

## Gameplay

- Three authored locks: Service Lock, Pressure Exchange and High Reservoir.
- Water levels range from 0 to 5.
- The chamber can only be pumped while both gates are closed.
- A gate can open only when its chamber level matches the adjacent basin.
- Both gates can never be open simultaneously.
- The ship can move only through an open, level-matched gate.
- Each accepted pump, gate or ship action consumes one action.
- Invalid operations do not consume an action.
- Each lock has a par and a hard action limit.
- A clear awards 100 campaign points at or under par, otherwise 75; each lock reward is claimed only once.
- Campaign maximum is 300 points.

## Controls

- Up / Down: pump chamber water up or down.
- L: toggle lower gate.
- U: toggle upper gate.
- Enter: move the ship through the open gate.
- R: reset the current lock.
- N: advance after clearing a lock.
- C: restart the campaign.
- Pointer/touch: use the on-screen pump, gate and ship controls.

## Import

Open project.godot in Godot 4.3+ and run main.tscn. The project uses the Compatibility renderer and has no external assets, plugins, audio or network dependencies.

## Tests

- tests/rules_test.gd: gate interlocks, water bounds, ship movement, action budgets, shortest-path uniqueness and all three authored solutions.
- tests/game_smoke_test.gd: scene import, visible touch controls, full campaign completion, one-time rewards and restart behavior.

The project is standalone and is not registered in the Survival Test Hub in M0.1.
