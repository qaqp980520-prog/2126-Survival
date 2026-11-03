extends Control

const WORLD_SCENE := "res://world/SurfaceWorld.tscn"
const SURFACE_SCENE := "res://prototypes/SurfaceChunkStreamingPlayground.tscn"
const BACKROOMS_SCENE := "res://prototypes/BackroomsPortalPlayground.tscn"
const UNDERGROUND_SCENE := "res://prototypes/UndergroundMiningPlayground.tscn"
const PINBALL_SCENE := "res://daily_games/KROLL_Orbital_Pinball/main.tscn"
const TETHER_SCENE := "res://daily_games/KROLL_Tether_Recovery/main.tscn"
const SHADOW_SCENE := "res://daily_games/KROLL_Shadow_Courier/main.tscn"
const FLUX_HOCKEY_SCENE := "res://daily_games/KROLL_Flux_Hockey/main.tscn"
const STAR_CHART_SCENE := "res://daily_games/KROLL_Star_Chart/main.tscn"
const CORE_DRILL_SCENE := "res://daily_games/KROLL_Core_Drill/main.tscn"
const MOLECULE_FORGE_SCENE := "res://daily_games/KROLL_Molecule_Forge/main.tscn"
const HEX_FRONTIER_SCENE := "res://daily_games/KROLL_Hex_Frontier/main.tscn"
const THERMAL_GLIDER_SCENE := "res://daily_games/KROLL_Thermal_Glider/main.tscn"
const GRAVITY_FOUNDRY_SCENE := "res://daily_games/KROLL_Gravity_Foundry/main.tscn"
const ECHO_MAPPER_SCENE := "res://daily_games/KROLL_Echo_Mapper/main.tscn"
const KNIGHT_CIRCUIT_SCENE := "res://daily_games/KROLL_Knight_Circuit/main.tscn"
const ATMOSPHERE_LAB_SCENE := "res://daily_games/KROLL_Atmosphere_Lab/main.tscn"
const NEON_CLIMBER_SCENE := "res://daily_games/KROLL_Neon_Climber/main.tscn"
const ROBOTIC_ARM_OPERATOR_SCENE := "res://daily_games/KROLL_Robotic_Arm_Operator/main.tscn"
const CONVEYOR_ARCHITECT_SCENE := "res://daily_games/KROLL_Conveyor_Architect/main.tscn"
const CROSSFLOW_CONTROLLER_SCENE := "res://daily_games/KROLL_Crossflow_Controller/main.tscn"
const STRATA_MAPPER_SCENE := "res://daily_games/KROLL_Strata_Mapper/main_root.tscn"
const RASTER_SURVEY_SCENE := "res://daily_games/KROLL_Raster_Survey/main_root.tscn"
const WIND_FARM_DISPATCH_SCENE := "res://daily_games/KROLL_Wind_Farm_Dispatch/main_root.tscn"
const INERTIAL_DOCKING_SCENE := "res://daily_games/KROLL_Inertial_Docking/main_root.tscn"
const MICROBE_SCOPE_SCENE := "res://daily_games/KROLL_Microbe_Scope/main_root.tscn"
const FAULTLINE_CARTOGRAPHER_SCENE := "res://daily_games/KROLL_Faultline_Cartographer/main_root.tscn"
const PALEO_TRACK_LAB_SCENE := "res://daily_games/KROLL_Paleo_Track_Lab/main_root.tscn"
const CREW_LEDGER_SCENE := "res://daily_games/KROLL_Crew_Ledger/main_root.tscn"
const CARGO_MOSAIC_SCENE := "res://daily_games/KROLL_Cargo_Mosaic/main_root.tscn"
const PENDULUM_ARRAY_SCENE := "res://daily_games/KROLL_Pendulum_Array/main_root.tscn"
const HABITAT_PHOTOGRAPHER_SCENE := "res://daily_games/KROLL_Habitat_Photographer/main_root.tscn"
const SOLAR_SAIL_NAVIGATOR_SCENE := "res://daily_games/KROLL_Solar_Sail_Navigator/main_root.tscn"
const TITRATION_BENCH_SCENE := "res://daily_games/KROLL_Titration_Bench/main_root.tscn"
const PLANETARY_CLIMATE_LAB_SCENE := "res://daily_games/KROLL_Planetary_Climate_Lab/main_root.tscn"
const CHRONO_VAULT_SCENE := "res://daily_games/KROLL_Chrono_Vault/main_root.tscn"
const SWARM_DISPATCHER_SCENE := "res://daily_games/KROLL_Swarm_Dispatcher/main_root.tscn"
const SIGNAL_RESONATOR_SCENE := "res://daily_games/KROLL_Signal_Resonator/main_root.tscn"
const SONAR_TRIANGULATOR_SCENE := "res://daily_games/KROLL_Sonar_Triangulator/main_root.tscn"
const STRATOSPHERE_BALLOONIST_SCENE := "res://daily_games/KROLL_Stratosphere_Balloonist/main_root.tscn"
const EMBERLINE_COMMAND_SCENE := "res://daily_games/KROLL_Emberline_Command/main_root.tscn"
const MESS_HALL_RUSH_SCENE := "res://daily_games/KROLL_Mess_Hall_Rush/main_root.tscn"
const FRAGMENT_ASSEMBLY_LAB_SCENE := "res://daily_games/KROLL_Fragment_Assembly_Lab/main_root.tscn"
const TETHER_BOT_RELAY_SCENE := "res://daily_games/KROLL_Tether_Bot_Relay/main_root.tscn"
const ARCHIVE_CURATOR_SCENE := "res://daily_games/KROLL_Archive_Curator/main_root.tscn"
const ENDGAME_TACTICS_SCENE := "res://daily_games/KROLL_Endgame_Tactics/main_root.tscn"

var status_label: Label

func _ready() -> void:
	_build_ui()

func _build_ui() -> void:
	var background := ColorRect.new()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.color = Color(0.035, 0.055, 0.075)
	add_child(background)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(620.0, 0.0)
	center.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_top", 28)
	margin.add_theme_constant_override("margin_bottom", 28)
	panel.add_child(margin)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 16)
	margin.add_child(column)

	var title := Label.new()
	title.text = "2126 SURVIVAL"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", Color(0.45, 0.9, 1.0))
	column.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "DEVELOPMENT TEST HUB"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 15)
	column.add_child(subtitle)

	var note := Label.new()
	note.text = "主世界已整合地表區塊、礦物、作物、打撈箱與共用背包；下方保留獨立子系統測試入口。"
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(note)

	var scroll := ScrollContainer.new()
	scroll.name = "LaunchListScroll"
	scroll.custom_minimum_size = Vector2(0.0, 470.0)
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)

	var launch_list := VBoxContainer.new()
	launch_list.add_theme_constant_override("separation", 12)
	launch_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(launch_list)

	_add_scene_button(
		launch_list,
		"主世界／地表生存",
		"進入可遊玩的地表世界：WASD 移動、E 管理作物、F 回收打撈箱；支援鍵盤與觸控操作。",
		WORLD_SCENE
	)
	_add_scene_button(
		launch_list,
		"地表探索／區塊與礦物串流",
		"測試第一人稱移動、地表區塊載入與卸載、礦脈資料和串流存檔。",
		SURFACE_SCENE
	)
	_add_scene_button(
		launch_list,
		"地下礦坑／採礦與共用背包",
		"進入地下洞穴，開採銅、鐵與鈾礦，驗證礦脈持久化及負重即時更新。",
		UNDERGROUND_SCENE
	)
	_add_scene_button(
		launch_list,
		"KROLL Orbital Pinball",
		"三張彈珠台、三顆球、碰撞反彈與雙側擋板；支援鍵盤、滑鼠與觸控。",
		PINBALL_SCENE
	)
	_add_scene_button(
		launch_list,
		"KROLL Tether Recovery",
		"駕駛回收無人機，使用繫索拖運三件貨物返回停靠區；支援推進、煞車與觸控。",
		TETHER_SCENE
	)
	_add_scene_button(
		launch_list,
		"KROLL Shadow Courier",
		"回收三份資料、避開旋轉巡邏視線，使用誘餌穿越 KROLL 設施；支援鍵盤與觸控。",
		SHADOW_SCENE
	)
	_add_scene_button(
		launch_list,
		"KROLL Flux Hockey",
		"操控下方擋板，把能量球打進上方球門；三座競技場，支援拖曳與鍵盤。",
		FLUX_HOCKEY_SCENE
	)
	_add_scene_button(
		launch_list,
		"KROLL Star Chart",
		"操控望遠鏡方位與倍率，依序鎖定四顆恆星，完成三個星區測繪任務。",
		STAR_CHART_SCENE
	)
	_add_scene_button(
		launch_list,
		"KROLL Core Drill",
		"規劃五條鑽探軌道，採集礦物並管理能源、熱量與鑽頭完整度。",
		CORE_DRILL_SCENE
	)
	_add_scene_button(
		launch_list,
		"KROLL Molecule Forge",
		"在五乘五實驗板上組裝 H2O、NH3、CH4，遵守原子價數並完成穩定分子。",
		MOLECULE_FORGE_SCENE
	)
	_add_scene_button(
		launch_list,
		"KROLL Hex Frontier",
		"在十九格六角地圖擴張領地、升級能源格，先控制十格取得勝利。",
		HEX_FRONTIER_SCENE
	)
	_add_scene_button(
		launch_list,
		"KROLL Thermal Glider",
		"操控滑翔翼穿越三個測繪信標，利用熱氣流補充升力與電池，最後安全降落。",
		THERMAL_GLIDER_SCENE
	)
	_add_scene_button(
		launch_list,
		"KROLL Gravity Foundry",
		"移動操作員、推動核心並旋轉重力，將核心送上壓力板後抵達出口；支援鍵盤與觸控。",
		GRAVITY_FOUNDRY_SCENE
	)
	_add_scene_button(
		launch_list,
		"KROLL Echo Mapper",
		"使用聲納脈衝探索三個隱藏維修區，回收訊號信標並抵達撤離艙；支援鍵盤與觸控。",
		ECHO_MAPPER_SCENE
	)
	_add_scene_button(
		launch_list,
		"KROLL Knight Circuit",
		"以騎士的 L 形走法走遍 5×5 棋盤，每格只能踩一次；支援點擊、觸控與方向鍵選取。",
		KNIGHT_CIRCUIT_SCENE
	)
	_add_scene_button(
		launch_list,
		"KROLL Atmosphere Lab",
		"調整溫度、濕度、氣壓與風速，在有限操作次數內穩定三個氣象站。",
		ATMOSPHERE_LAB_SCENE
	)
	_add_scene_button(
		launch_list,
		"KROLL Neon Climber",
		"以雙重跳躍和短距衝刺穿越三座設施，回收資料核心並啟動出口。",
		NEON_CLIMBER_SCENE
	)
	_add_scene_button(
		launch_list,
		"KROLL Robotic Arm Operator",
		"校準雙關節機械手臂，精準夾取三件貨物並放入指定接收區；支援鍵盤與觸控。",
		ROBOTIC_ARM_OPERATOR_SCENE
	)
	_add_scene_button(
		launch_list,
		"KROLL Conveyor Architect",
		"在六乘六工廠格配置方向輸送帶，避開障礙並將貨物送達接收區；支援鍵盤與觸控。",
		CONVEYOR_ARCHITECT_SCENE
	)
	_add_scene_button(
		launch_list,
		"KROLL Crossflow Controller",
		"即時管理四向路口號誌，在全紅清空時間內切換車流，避免排隊溢出並完成三個班次。",
		CROSSFLOW_CONTROLLER_SCENE
	)
	_add_scene_button(
		launch_list,
		"KROLL Strata Mapper",
		"重排三組鑽芯地層，讓火山灰標記層在三個核心柱中對齊；每個測站有十八次相鄰交換額度。",
		STRATA_MAPPER_SCENE
	)
	_add_scene_button(
		launch_list,
		"KROLL Raster Survey",
		"依照列與欄的連續格數線索重建三幅 6×6 掃描圖；支援滑鼠、鍵盤與觸控。",
		RASTER_SURVEY_SCENE
	)
	_add_scene_button(
		launch_list,
		"KROLL Wind Farm Dispatch",
		"調整三座風機的偏航與葉片角度，平衡電網需求、電池儲備與過熱風險；支援鍵盤與觸控。",
		WIND_FARM_DISPATCH_SCENE
	)
	_add_scene_button(
		launch_list,
		"KROLL Inertial Docking",
		"使用慣性推進、反向推力與煞車，穿越碎片並以低相對速度完成三個太空泊位對接；支援鍵盤與觸控。",
		INERTIAL_DOCKING_SCENE
	)
	_add_scene_button(
		launch_list,
		"KROLL Microbe Scope",
		"調整顯微鏡焦距、倍率、照明與染色，捕捉三種微生物標本；支援滑鼠、鍵盤與觸控。",
		MICROBE_SCOPE_SCENE
	)
	_add_scene_button(
		launch_list,
		"KROLL Faultline Cartographer",
		"發射三個地震探針，利用回波距離交會定位地下礦脈；支援鍵盤與觸控。",
		FAULTLINE_CARTOGRAPHER_SCENE
	)
	_add_scene_button(
		launch_list,
		"KROLL Paleo Track Lab",
		"量測足印長寬、步幅、步道寬度與趾向，判讀三條恐龍足跡路線的造跡者與移動方式；支援鍵盤與觸控。",
		PALEO_TRACK_LAB_SCENE
	)
	_add_scene_button(
		launch_list,
		"KROLL Crew Ledger",
		"閱讀四條線索，將四名船員唯一指派到四個艙站；三份案件、鍵盤與觸控操作。",
		CREW_LEDGER_SCENE
	)
	_add_scene_button(
		launch_list,
		"KROLL Cargo Mosaic",
		"旋轉四種四格貨物模組，將三座貨艙的十六個訊號格完整填滿；支援鍵盤、滑鼠與觸控。",
		CARGO_MOSAIC_SCENE
	)
	_add_scene_button(
		launch_list,
		"KROLL Pendulum Array",
		"調整擺長並比對四週期相位漂移，完成三座共振校準站；支援鍵盤與觸控。",
		PENDULUM_ARRAY_SCENE
	)
	_add_scene_button(
		launch_list,
		"KROLL Habitat Photographer",
		"追蹤三種棲地中的移動動物，調整對焦、倍率與曝光，在目標進入取景框且視線清晰時拍攝。",
		HABITAT_PHOTOGRAPHER_SCENE
	)
	_add_scene_button(
		launch_list,
		"KROLL Solar Sail Navigator",
		"調整太陽帆角度與展開量，利用光壓轉向、控制慣性漂移並穿越碎片帶抵達三座中繼站。",
		SOLAR_SAIL_NAVIGATOR_SCENE
	)
	_add_scene_button(
		launch_list,
		"KROLL Titration Bench",
		"逐步加入標準滴定液，讀取即時 pH 曲線，在三份未知酸樣本中精準鎖定當量點。",
		TITRATION_BENCH_SCENE
	)

	_add_scene_button(
		launch_list,
		"KROLL Planetary Climate Lab",
		"調整行星反照率與溫室熱滯留比例，讓三個世界的能量平衡溫度進入目標範圍。",
		PLANETARY_CLIMATE_LAB_SCENE
	)
	_add_scene_button(
		launch_list,
		"KROLL Chrono Vault",
		"先錄下通往紫色 A 板的路線，再倒帶讓回聲重播；你必須同步站上綠色 B 板才能開啟出口。",
		CHRONO_VAULT_SCENE
	)
	_add_scene_button(
		launch_list,
		"KROLL Swarm Dispatcher",
		"分別編排三架無人機的路線，再逐 tick 同步執行；系統會拒絕同格衝突與迎面交換。",
		SWARM_DISPATCHER_SCENE
	)
	_add_scene_button(
		launch_list,
		"KROLL Signal Resonator",
		"依照節拍按下三條訊號通道，抓住 Perfect／Good 時窗，完成三段共振校準。",
		SIGNAL_RESONATOR_SCENE
	)
	_add_scene_button(
		launch_list,
		"KROLL Sonar Triangulator",
		"從四座聲納浮標讀取距離回波，在 8×8 海床上定位失聯探測器；第四次掃描可破解模糊回波。",
		SONAR_TRIANGULATOR_SCENE
	)
	_add_scene_button(
		launch_list,
		"KROLL Stratosphere Balloonist",
		"管理氣球浮力、消耗壓艙物與氣體完整度，穿越變化風層並在三個高度帶穩定採樣。",
		STRATOSPHERE_BALLOONIST_SCENE
	)
	_add_scene_button(
		launch_list,
		"KROLL Emberline Command",
		"管理三場野火防線：配置永久防火帶、投放水彈並依照風向推進火勢；保護三座中繼站。支援鍵盤與觸控。",
		EMBERLINE_COMMAND_SCENE
	)
	_add_scene_button(
		launch_list,
		"KROLL Mess Hall Rush",
		"在三個太空站班次中處理十二張餐點訂單；選擇正確工序，管理所有訂單的倒數期限。支援鍵盤、滑鼠與觸控。",
		MESS_HALL_RUSH_SCENE
	)
	_add_scene_button(
		launch_list,
		"KROLL Fragment Assembly Lab",
		"拼接三組虛構字串片段，依照至少兩個字元的重疊規則重建目標序列。",
		FRAGMENT_ASSEMBLY_LAB_SCENE
	)
	_add_scene_button(
		launch_list,
		"KROLL Tether Bot Relay",
		"操控維修無人機連接維修節點，使用推進器穿越三座太空設施；支援鍵盤、滑鼠與觸控。",
		TETHER_BOT_RELAY_SCENE
	)
	_add_scene_button(
		launch_list,
		"KROLL Archive Curator",
		"策劃三座展廳：挑選四件展品，利用主題標籤與相鄰連結達成分數目標。支援鍵盤、滑鼠與觸控。",
		ARCHIVE_CURATOR_SCENE
	)
	_add_scene_button(
		launch_list,
		"KROLL Endgame Tactics",
		"在三個八乘八殘局中找出唯一的車將死一步；支援滑鼠、觸控與方向鍵。",
		ENDGAME_TACTICS_SCENE
	)
	_add_scene_button(
		launch_list,
		"後室傳送門實驗場",
		"測試後室無限迷宮、傳送門、背包負重、設定與存檔。",
		BACKROOMS_SCENE
	)

	status_label = Label.new()
	status_label.name = "StatusLabel"
	status_label.text = "提示：在世界或原型場景按 Esc 可釋放滑鼠；按 F10 返回此選單。地表世界已整合共用系統，其他區域仍在開發中。"
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.add_theme_color_override("font_color", Color(0.72, 0.78, 0.82))
	column.add_child(status_label)

func _add_scene_button(parent: VBoxContainer, title_text: String, description: String, scene_path: String) -> void:
	var group := VBoxContainer.new()
	group.add_theme_constant_override("separation", 5)
	parent.add_child(group)

	var button := Button.new()
	button.text = title_text
	button.custom_minimum_size = Vector2(0.0, 54.0)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.pressed.connect(_open_scene.bind(scene_path))
	group.add_child(button)

	var details := Label.new()
	details.text = description
	details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	details.add_theme_color_override("font_color", Color(0.76, 0.81, 0.85))
	group.add_child(details)

func _open_scene(scene_path: String) -> void:
	var error := get_tree().change_scene_to_file(scene_path)
	if error != OK and is_instance_valid(status_label):
		status_label.text = "無法開啟場景：%s（錯誤碼 %d）" % [scene_path, error]
