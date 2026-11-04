# Run 112 Closeout — KROLL Salvage Auction and bridge metric sanitization

Date: 2026-11-04  
Engine target: Godot 4.3+  
Feature PR: [#256](https://github.com/qaqp980520-prog/2126-Survival/pull/256)  
Merge commit: `56ee0038ccc229b9c1c0533c54bfa86d97f0d962`  
Validated feature head: `6241fc5f814f5fbe209f727cd3d00ff0aba77f22`

## Delivered game — KROLL Salvage Auction M0.1

Path: `daily_games/KROLL_Salvage_Auction/`

- Three markets and nine deterministic salvage lots.
- One inspection token per market; inspection reveals true resale value.
- Low/standard/aggressive bid tiers; a bid at or above the rival offer wins.
- Winning pays the bid and adds true resale value; losing/passing spends no credits.
- Contract: finish with at least 160 credits and three won lots.
- Keyboard and pointer/touch controls; standalone Godot 4.3+ project without external dependencies.

## Existing-system change

Updated `systems/SurvivalWorldBridge.gd`.

- Read-only custom inventory metrics are normalized before movement/UI callers receive them.
- Weight must be finite and >= 0; invalid values fall back to 0.
- Carry limit must be finite and > 0; invalid values fall back to 65 kg.
- Overweight/super-heavy/jump flags are trusted only when actual Booleans; otherwise derived from validated weight/limit.
- Movement multiplier must be finite in [0,1]; invalid values fall back to 1.0/0.68/0.42 according to load state.
- Public method signatures and world-save schema 1 remain unchanged.

## Validation

- Exact-head full Godot 4.3 [#41764490939](https://github.com/qaqp980520-prog/2126-Survival/actions/runs/41764490939): 510/510 job steps successful, including Run 112 gates #503–507 and final cleanup.
- Focused Run 112 [#41764490988](https://github.com/qaqp980520-prog/2126-Survival/actions/runs/41764490988): 13/13; nine historical focused suites: 131/131 (144/144 combined).
- The immediate merge-triggered full main workflow #41776207214 was cancelled before Run 112 final gates and is not post-merge evidence. Subsequent exact-main full validation [#41776646151](https://github.com/qaqp980520-prog/2126-Survival/actions/runs/41776646151) passed 510/510 on main `f0280132d74942cc87992075ab6e5164b998d272`, which includes the Run 112 state and the first Run 113 bridge commit.

## Limitations

Local rendered GUI/GPU and physical iPhone QA were not performed. Main branch protection remains tracked under issue #236.
