# 每日手搓遊戲計畫｜2026-10-26 Run 4

## 本輪工作目標

- 新增與近期玩法不同的小遊戲：KROLL Gravity Lander。
- 將後室入口 director、3D portal visual、共用背包橋接與世界存檔轉接器接到一個可啟動的 3D 測試場景。
- 確認保留原本垂直環姿態，修正入口中心高度，並處理世界切換的碰撞隔離。
- 更新 Godot CI，讓新遊戲和端到端場景一起測試。
- 不在 CI 未通過前合併 MAIN。

## 產物

- daily_games/KROLL_Gravity_Lander/
- project.godot
- prototypes/BackroomsPortalPlayground.tscn
- prototypes/BackroomsPortalPlayground.gd
- prototypes/BackroomsPlayerController.gd
- tests/backrooms_portal_playground_test.gd
- systems/BackroomsPortalVisual.gd / .tscn
- tests/backrooms_portal_scene_test.gd
- docs/BACKROOMS_PORTAL_PLAYGROUND_M0_1.md

## 測試計畫

Godot 4.3 CI 應執行 Gravity Lander 匯入、規則測試與場景 smoke test；後室端到端測試應驗證入口生成、單次消耗、Level 切換、共用背包物品變化、存檔往返，以及無效 portal schema 的原子拒絕。CI 完成前一律標記待驗證。

## 狀態規則

- 本機沒有 Godot 執行檔，不能宣稱本機引擎測試通過。
- 只在 PR head 的 Godot 4.3 CI 完成且成功後，才將引擎測試狀態更新為通過。
- 手動遊玩、實際視覺、碰撞與 iPhone 測試仍需另外確認。
