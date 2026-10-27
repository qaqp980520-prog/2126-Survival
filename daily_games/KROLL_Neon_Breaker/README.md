# KROLL Neon Breaker M0.1

A code-drawn Godot 4 arcade game. Keep the ball alive, steer it with the paddle, clear forty neon bricks, and beat the sixty-second timer.

## Import

Open `project.godot` in Godot Project Manager (Godot 4.3+). No addons, external art, or audio assets are required.

## Controls

- A / D or Left / Right: move the paddle.
- Mouse movement: position the paddle.
- Space / Enter: launch the ball.
- R: restart the round.
- Bottom on-screen controls: move left/right or launch; also supports touch.

## Rules

- Start with three lives and sixty seconds.
- Each brick is worth ten points.
- Paddle hit position changes the ball's reflection angle.
- Losing the ball consumes one life; the next serve returns to ready state.
- Clear all forty bricks before the timer reaches zero to win.
- No GUI, GPU performance, or iPhone hardware test is implied by headless CI.

## Tests

- `tests/rules_test.gd`: paddle bounds, reflection, steering, life/timer boundaries and win condition.
- `tests/game_smoke_test.gd`: scene startup, launch, brick collision/scoring, life loss and restart.
