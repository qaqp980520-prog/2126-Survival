# KROLL Salvage Exchange M0.1

A deterministic, single-player commodity trading game for Godot 4.3+.

## Goal

Start with 100 credits, trade Copper, Polymer, Circuit and Alloy, and finish the contract with net worth at least 150. The market closes after day 8. Each trade charges a 5% fee rounded up; cargo capacity is 10 units. Prices are deterministic from the selected market seed and day.

## Controls

- Keys 1–4 select a commodity.
- B buys one unit; S sells one unit.
- Enter closes the day / advances the market.
- R restarts the current seed; N opens the next seed.
- All actions are also available through on-screen buttons.

## Import

Open `project.godot` in Godot 4.3 or newer. No external assets or add-ons are required.

## Tests

- `tests/rules_test.gd`: deterministic prices, invalid actions, transaction atomicity, fees, cargo capacity, profitable trade, win/loss and terminal lockout.
- `tests/game_smoke_test.gd`: main scene startup, UI construction, buy/day/sell flow and restart.

## Limits

M0.1 is a local single-player prototype. It does not include online trading, saved campaigns or animated market events.
