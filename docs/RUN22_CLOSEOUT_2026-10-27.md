# Run 22 Closeout — 2026-10-27

## External baseline reconciliation
- Run 21 recorded main: `d2a9d8a9fef010af49eedbb5b8e231a7bec96209`.
- Actual main at Run 22 start: `7ee84c5e61a61bd5d30a9d7ebf391e1a6fe887d7`, 21 commits ahead and 0 behind. The intervening history added the Survival Test Hub, surface inventory bridge integration, and underground-only vein placement. This discrepancy was recorded in Notion and preserved in the index.

## Delivered
- `daily_games/KROLL_Command_Grid/`: standalone Godot 4.3 turn-based 8×8 tactics game, four data cores, shortest-path security bots, three EMP charges, 32-action limit, keyboard/mouse/touch input; rules and runtime smoke tests.
- `prototypes/UndergroundMiningPlayground.tscn` and `prototypes/UndergroundMiningPlayground.gd`: fixed cave at Y=-8 with three registered mineral veins under stable chunk ID `underground/cave_0_0`; integrates MineralVeinRegistry, MineralChunkController, MineralMiningNode and SurvivalWorldBridge.
- `tests/underground_mining_playground_test.gd`: validates below-surface placement, stable chunk registration, mining into shared inventory, vein snapshot restore, immediate weight decrease after drop, and no surface mining interaction.
- Survival Test Hub now offers surface, underground mine, and Backrooms entries.
- Godot CI workflow includes the new game import/rules/runtime tests and cave integration test.

## GitHub / tests
- PR #76: [Run 22: Command Grid and underground mining prototype](https://github.com/qaqp980520-prog/2126-Survival/pull/76), merged.
- Candidate HEAD: `67f2818e6269ce87f6b36054bae59d38c54abfcd`.
- Merge commit and main SHA: `0c232c540d2d479ab71a22e065384e55aea5ca54`.
- Exact-head Godot 4.3 CI Run #360: [40486271348](https://github.com/qaqp980520-prog/2126-Survival/actions/runs/40486271348), success; all 91 numbered validation steps passed, zero failures. New game steps 88–90 and underground integration step 91 passed.
- Run #354 failed at hub smoke due implicit label name; fixed with explicit StatusLabel. Run #357 failed at surface regression because workflow expected an obsolete success marker; fixed to match the test's underground-only marker.
- Post-merge GitHub compare: main identical to merge SHA. Open PR search empty at that check. No separate main-push workflow run was exposed by the connector.

## Limits
- The cave is a fixed single-chunk prototype, not the missing production M1.3 world controller.
- No procedural/asynchronous cave streaming, multiplayer, or persistent production-world save envelope yet.
- Local GUI, GPU performance, and iPhone device testing were not performed; the local environment has no Godot executable.

## Next steps
1. Introduce the real production world-session controller.
2. Connect the tested shared inventory and mineral lifecycle to it.
3. Add end-to-end production-scene tests for mine, drop, weight/encumbrance, save/reload and failure recovery.
