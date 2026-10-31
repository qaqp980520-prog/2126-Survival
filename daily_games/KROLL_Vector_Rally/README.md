# KROLL Vector Rally M0.1

A standalone Godot 4 top-down time-trial racer. Drive the oval circuit, follow the glowing checkpoint order, stay on the track to retain speed, and use the two green boost pads to complete three laps before 90 seconds.

## Controls

- W / Up: throttle
- S / Down: brake
- A / Left: steer left
- D / Right: steer right
- R: restart at any time
- Touch controls: LEFT, RIGHT, THROTTLE, BRAKE buttons along the bottom edge

## Rules

- Checkpoints must be crossed in order: right, top, left, then start/finish.
- Three complete laps win the race.
- Wrong-order gates do not advance the lap.
- Leaving the oval track reduces speed.
- Green boost pads add forward speed when the car is moving at least 45 units/second and the boost cooldown is clear.
- The 90-second timer ends an unfinished race.

## Import

Use Godot 4.3 or newer. In Project Manager, import this folder by selecting project.godot. No external assets or third-party add-ons are required.

## Automated checks

The repository Godot 4.3 CI imports this project and runs tests/rules_test.gd plus tests/game_smoke_test.gd. Local graphical and iPhone playtesting are separate acceptance tasks and are not implied by CI success.
