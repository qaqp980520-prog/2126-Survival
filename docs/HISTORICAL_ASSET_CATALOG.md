# 歷史原型與資產目錄

整理日期：2026-10-25  
來源：目前工作區中實際存在的 ZIP 檔。這份目錄只記錄可確認存在的檔案，不代表 ZIP 已經逐一上傳到 GitHub，也不代表已在 Godot 執行測試。

## 使用原則
- ZIP 原包保留原始版本結構；不要把不同版本的同名檔案互相覆蓋。
- 每個專案版本以獨立資料夾或獨立 ZIP 保存。
- Godot 執行驗證狀態：目前列出的原型尚不能一概視為已在 Godot 4 實測。
- OBJ/MTL 模型還需要在 Blender 或 Godot 中實際匯入檢查。
- Daily Game Progress 套件可能包含其他專案的副本，需保留但標記為彙整包，不應當作唯一原始版本。

## A. 世界、後室與地理
- `2126_Survival_World_Geography_M1_0_Godot4_2026-10-21.zip` — 世界地理、野區生態、野生作物與交易原型
- `Backrooms_Seamless_Streaming_Godot4_2026-10-20.zip` — 後室區塊串流早期版
- `Backrooms_Seamless_Streaming_Godot4_Optimized_2026-10-20.zip` — 後室串流最佳化迭代
- `Backrooms_Large_World_Design_2026-10-20.zip` — 大型後室世界設計文件

## B. 背包、物資、收藏室與物品檢視
- `2126_Survival_Backrooms_Loot_Containers_Godot4_2026-10-20.zip`
- `2126_Survival_Collection_Room_Godot4_2026-10-20.zip`
- `2126_Survival_Collection_Room_M1_Local_Save_Godot4_2026-10-20.zip`
- `2126_Survival_Collection_Room_M1_1_Container_Persistence_Godot4_2026-10-20.zip`
- `2126_Survival_Collection_Room_M1_2_Item_Inspect_Godot4_2026-10-20.zip`
- `2126_Survival_Collection_Room_M1_3_3D_Item_Inspect_Godot4_2026-10-20.zip`
- `2126_Survival_Collection_Room_M1_4_FirstPerson_Hand_Inspect_Godot4_2026-10-20.zip`
- `2126_Survival_Rare_Item_Special_Inspect_M1_5_Godot4_2026-10-20.zip`
- `2126_Survival_Rare_Item_Special_Inspect_M1_6_Item_Action_Registry_Godot4_2026-10-21.zip`
- `2126_Survival_Infinite_Inventory_M1_1_Godot4_2026-10-22.zip`
- `2126_Survival_World_Inventory_Integration_M1_2_Godot4_2026-10-22.zip`
- `2126_Survival_World_Inventory_Persistence_M1_3_Godot4_2026-10-24.zip`
- `2126_Survival_KROLL_Hotbar_Jump_M1_1_Godot4_2026-10-21.zip`

## C. KROLL 航太基地、單位與 Boss
- `KROLL_Aerospace_Base_3D_Model_Godot4_2026-10-21.zip` — OBJ/MTL 航太基地模型
- `KROLL_Aerospace_Minister_Boss_Guards_Godot4_2026-10-21.zip` — Boss 與五名護衛靜態模型
- `KROLL_Aerospace_Boss_AI_M0_2_Godot4_2026-10-21.zip` — Boss／護衛遭遇戰原型
- `2126_Survival_KROLL_Aerospace_Director_Boss_Prototype_Godot4_2026-10-21.zip`
- `2126_Survival_KROLL_Launch_Complex_Boss_Prototype_Godot4_2026-10-21.zip`
- `2126_Survival_KROLL_Launch_Complex_Patrol_Console_Stage2_Godot4_2026-10-21.zip`
- `2126_Survival_KROLL_Units_Godot4_2026-10-20.zip`
- `2126_Survival_KROLL_Units_Design_2026-10-20.zip`

## D. 採礦與設定
- `2126_Survival_Mining_Slice_Godot4_2026-10-19.zip`
- `2126_Survival_Mining_Slice_v2_Godot4_2026-10-19.zip`
- `2126_Survival_Mining_Update_2026-10-18.zip`
- `2126_Survival_Mining_Design_Update_2026-10-19.zip`
- `2126_Survival_Graphics_Settings_Godot4_2026-10-20.zip`
- `2126_Survival_Graphics_Settings_Design_2026-10-20.zip`

## E. 每日小遊戲
- `Ore_Shift_Godot4_2026-10-18.zip`
- `KROLL_Signal_Runner_Godot4_2026-10-19.zip`
- `Portal_Courier_Godot4_2026-10-20.zip`
- `KROLL_Circuit_Relay_Godot4_2026-10-21.zip`
- `KROLL_Drone_Rescue_MiniGame_Godot4_2026-10-24.zip`

## F. 每日進度彙整包與歷史封存
- `Daily_Game_Progress_2026-10-18.zip`
- `Daily_Game_Progress_2026-10-19.zip`
- `Daily_Game_Progress_2026-10-19_Iteration.zip`
- `Daily_Game_Progress_2026-10-20.zip`
- `Daily_Game_Progress_2026-10-20_Backrooms_Streaming.zip`
- `Daily_Game_Progress_2026-10-20_Iteration2.zip`
- `Daily_Game_Progress_2026-10-20_KROLL_Units.zip`
- `Daily_Game_Progress_2026-10-21.zip`
- `2126_Survival_Historical_Assets_Archive_2026-10-21.zip`

## 下一步整理順序
1. 先把最新的獨立專案版本放入 repo，避免只留下每日彙整包。
2. 對重複內容保留各版本來源，另標註「彙整包副本」。
3. 每個專案加入 README、控制方式、匯入步驟、測試狀態與已知限制。
4. 上傳每個二進位 ZIP 或原始模型前，需確認 GitHub 中真的有該檔案；僅有此目錄不算上傳。
