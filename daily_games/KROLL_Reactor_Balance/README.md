# KROLL Reactor Balance M0.1

A standalone Godot 4.3+ arcade management game. Keep the combined output of three reactors in the 135–165 band for 18 consecutive seconds without allowing any reactor to reach 100 heat.

## Controls

- 1 / 2 / 3: vent the matching reactor (output -12, heat -18).
- Q / W / E: boost the matching reactor (output +10, heat +12).
- Mouse/touch: tap the visible VENT panel to vent; tap the visible BOOST panel to boost.
- R: restart after a round ends.

The simulation ticks once per second. Output drifts slightly each tick. A grid tick outside the target band resets the stability streak. Any reactor at 100 heat triggers a meltdown; 60 seconds without a stable 18-second streak ends the round.

## Import

Open this folder's project.godot in Godot Project Manager. No external assets or third-party addons are required.

## Tests

- godot --headless --path daily_games/KROLL_Reactor_Balance --editor --quit
- godot --headless --path daily_games/KROLL_Reactor_Balance --script res://tests/rules_test.gd
- godot --headless --path daily_games/KROLL_Reactor_Balance --script res://tests/game_smoke_test.gd

CI status must be checked on the exact PR head before merge. Graphical manual play and iPhone device testing are separate, not implied by headless test success.
