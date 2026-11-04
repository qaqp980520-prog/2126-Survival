# KROLL Salvage Auction M0.1

A standalone Godot 4.3+ deterministic salvage-market strategy game. Inspect one lot per market, decide whether to pass or bid, and finish three markets with at least 160 credits and three won lots.

## Gameplay

- Nine fixed lots across three markets.
- Each market grants one inspection token.
- Inspection reveals the current lot's true resale value.
- Low, standard and aggressive bids use reserve, estimate midpoint and estimate ceiling.
- A bid at or above the rival offer wins; a losing bid costs nothing.
- Winning pays the bid and adds the true resale value to the player's credits.
- A lot resolves once. Insufficient-credit bids and invalid actions do not advance the market.
- Contract success requires at least 160 credits and three wins after all nine lots resolve.

## Controls

- 1: inspect the current lot.
- 2: low bid.
- 3: standard bid.
- 4: aggressive bid.
- 5: pass.
- R: restart the campaign.
- Pointer/touch: use the on-screen buttons.

## Import

Open project.godot in Godot 4.3+ and run main.tscn. The project uses the Compatibility renderer and has no external assets, plugins, audio, network or save dependencies.

## Tests

- tests/rules_test.gd covers bid pricing, inspection budgets, affordability, rival outcomes, campaign progression and one-time lot resolution.
- tests/game_smoke_test.gd imports the scene, checks UI controls, completes a deterministic campaign and verifies restart behavior.

This is a standalone prototype and is not registered in the Survival Test Hub in M0.1.
