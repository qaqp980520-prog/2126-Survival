# KROLL Moonbase Courier M0.1

A standalone Godot 4.3+ side-view delivery platformer.

## Objective

Collect one parcel on each moonbase route, then reach the marked airlock before the oxygen window expires. Jump over heated surface vents. Each route has three suit charges; a vent hit consumes one charge, returns the courier to the start pad and drops the parcel back at its pickup point.

## Controls

- A / D or Left / Right: move.
- Space: jump.
- E: pick up a parcel or deliver it at the airlock.
- R: restart the current route.
- N: advance after a successful delivery.
- C: restart the campaign.
- On-screen LEFT / RIGHT / JUMP / INTERACT controls support pointer and touch.
- On-screen RESTART / NEXT controls provide touch navigation.

## Campaign

Three authored routes: Dustline Depot, Crater Relay and Polar Antenna Run. Each route awards 100 points when delivered within its par time, otherwise 75. A route can award only once per campaign; maximum score is 300.

## Import

Open this folder in Godot 4.3 or newer and run main.tscn. The project uses the Compatibility renderer and has no external assets, plugins, audio, network or save dependencies.

## Validation

- tests/rules_test.gd checks route geometry, hazard separation, one-way landing and campaign state.
- tests/game_smoke_test.gd instantiates the scene, completes all three routes, checks one-time scoring, touch hit-testing and movement/jump simulation.
- Full repository CI also runs the SurvivalWorldBridge restore reentrancy regression.

The game uses a deterministic lightweight 2D movement model and rectangular collision checks. Headless CI does not establish local rendered GUI polish, GPU performance or physical iPhone behavior.
