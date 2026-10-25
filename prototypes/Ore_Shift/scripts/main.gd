extends Node2D

const GRID_W := 12
const GRID_H := 12
const TILE := 42
const GRID_ORIGIN := Vector2(30, 30)
const HARVEST_PER_CYCLE := 2
const GOAL_ORE := 18

const BLOCK_DATA := {
	"rock": {"short": "R", "name": "Rock", "hardness": 1},
	"iron": {"short": "Fe", "name": "Iron", "hardness": 2},
	"copper": {"short": "Cu", "name": "Copper", "hardness": 2},
	"crystal": {"short": "X", "name": "Crystal", "hardness": 3}
}

const TOOL_DATA := {
	"pickaxe": {"name": "Pickaxe", "power": 2, "speed": 1.0, "max_durability": 36, "wear": 1},
	"drill": {"name": "KROLL Drill", "power": 3, "speed": 1.45, "max_durability": 26, "wear": 2}
}

var grid: Array = []
var player_cell := Vector2i(5, 1)
var facing := Vector2i(0, 1)
var selected_tool := "pickaxe"
var tool_durability := {"pickaxe": 36, "drill": 26}
var inventory := {"rock": 0, "iron": 0, "copper": 0, "crystal": 0}
var mine_elapsed := 0.0
var mine_target := Vector2i(-999, -999)
var status_message := "Find ore. Hold SPACE against a block to mine."
var won := false

func _ready() -> void:
	generate_world()
	queue_redraw()

func generate_world() -> void:
	grid.clear()
	randomize()
	for y in range(GRID_H):
		var row: Array = []
		for x in range(GRID_W):
			if y < 2:
				row.append(null)
			else:
				var roll := randi_range(1, 100)
				var kind := "rock"
				if roll <= 55:
					kind = "rock"
				elif roll <= 78:
					kind = "iron"
				elif roll <= 94:
					kind = "copper"
				else:
					kind = "crystal"
				row.append(make_block(kind))
		grid.append(row)
	# Keep the first mining target accessible and beginner-friendly.
	grid[2][5] = make_block("iron")
	grid[2][4] = make_block("rock")
	grid[2][6] = make_block("copper")

func make_block(kind: String) -> Dictionary:
	return {
		"kind": kind,
		"remaining": randi_range(3, 7),
		"hardness": BLOCK_DATA[kind]["hardness"]
	}

func _input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	if won:
		if event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
			get_tree().reload_current_scene()
		return

	var move_dir := Vector2i.ZERO
	match event.keycode:
		KEY_W, KEY_UP:
			move_dir = Vector2i(0, -1)
		KEY_S, KEY_DOWN:
			move_dir = Vector2i(0, 1)
		KEY_A, KEY_LEFT:
			move_dir = Vector2i(-1, 0)
		KEY_D, KEY_RIGHT:
			move_dir = Vector2i(1, 0)
		KEY_1:
			selected_tool = "pickaxe"
			mine_elapsed = 0.0
			mine_target = Vector2i(-999, -999)
			status_message = "Selected Pickaxe."
		KEY_2:
			selected_tool = "drill"
			mine_elapsed = 0.0
			mine_target = Vector2i(-999, -999)
			status_message = "Selected KROLL Drill."
		KEY_R:
			if player_cell.y <= 1:
				tool_durability[selected_tool] = TOOL_DATA[selected_tool]["max_durability"]
				status_message = selected_tool.capitalize() + " repaired at the surface station."
			else:
				status_message = "Repair station is at the surface (top two rows)."

	if move_dir != Vector2i.ZERO:
		facing = move_dir
		var next_cell := player_cell + move_dir
		if is_inside_grid(next_cell) and grid[next_cell.y][next_cell.x] == null:
			player_cell = next_cell
			status_message = "Position: %d, %d" % [player_cell.x + 1, player_cell.y + 1]
		else:
			status_message = "Block ahead. Hold SPACE to mine it."
		mine_elapsed = 0.0
		mine_target = Vector2i(-999, -999)
	_check_win()
	queue_redraw()

func _process(delta: float) -> void:
	if won:
		return
	if Input.is_key_pressed(KEY_SPACE):
		var target := player_cell + facing
		if is_inside_grid(target) and grid[target.y][target.x] != null:
			if target != mine_target:
				mine_target = target
				mine_elapsed = 0.0
			var block: Dictionary = grid[target.y][target.x]
			var tool_info: Dictionary = TOOL_DATA[selected_tool]
			var hardness: int = block["hardness"]
			var cycle_time: float = 0.78 * float(hardness) / float(tool_info["speed"])
			mine_elapsed += delta
			if mine_elapsed >= cycle_time:
				mine_elapsed = 0.0
				if int(tool_durability[selected_tool]) <= 0:
					status_message = selected_tool.capitalize() + " is broken. Switch tools or return to surface to repair."
				else:
					# Durability is spent only while the tool is actively working on a block.
					tool_durability[selected_tool] = max(0, int(tool_durability[selected_tool]) - int(tool_info["wear"]))
					if int(tool_info["power"]) >= hardness:
						var amount: int = min(HARVEST_PER_CYCLE, int(block["remaining"]))
						block["remaining"] = int(block["remaining"]) - amount
						inventory[block["kind"]] = int(inventory[block["kind"]]) + amount
						status_message = "+%d %s | tool wear -%d" % [amount, BLOCK_DATA[block["kind"]]["name"], int(tool_info["wear"])]
						if int(block["remaining"]) <= 0:
							grid[target.y][target.x] = null
							status_message += " | vein exhausted"
					else:
						status_message = "Too hard for this tool. Attempt failed; durability still reduced."
					if int(tool_durability[selected_tool]) <= 0:
						status_message += " Tool broken!"
			_check_win()
		else:
			mine_elapsed = 0.0
			mine_target = Vector2i(-999, -999)
	else:
		mine_elapsed = 0.0
		mine_target = Vector2i(-999, -999)
	queue_redraw()

func _check_win() -> void:
	var total := 0
	for value in inventory.values():
		total += int(value)
	if total >= GOAL_ORE and player_cell.y <= 1:
		won = true
		status_message = "Contract complete! You collected %d units and returned to the surface." % total

func is_inside_grid(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < GRID_W and cell.y >= 0 and cell.y < GRID_H

func _draw() -> void:
	_draw_grid()
	_draw_hud()

func _draw_grid() -> void:
	for y in range(GRID_H):
		for x in range(GRID_W):
			var rect := Rect2(GRID_ORIGIN + Vector2(x * TILE, y * TILE), Vector2(TILE - 2, TILE - 2))
			var block = grid[y][x]
			var fill := Color(0.12, 0.16, 0.18)
			if y < 2:
				fill = Color(0.13, 0.22, 0.18)
			elif block != null:
				match block["kind"]:
					"rock": fill = Color(0.34, 0.36, 0.39)
					"iron": fill = Color(0.48, 0.32, 0.25)
					"copper": fill = Color(0.62, 0.35, 0.18)
					"crystal": fill = Color(0.30, 0.25, 0.60)
			draw_rect(rect, fill, true)
			draw_rect(rect, Color(0.07, 0.08, 0.09), false, 1.0)
			if y == 0:
				draw_string(ThemeDB.fallback_font, rect.position + Vector2(5, 15), "SURF", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(0.72, 0.86, 0.75))
			if block != null:
				var short_label: String = BLOCK_DATA[block["kind"]]["short"]
				draw_string(ThemeDB.fallback_font, rect.position + Vector2(6, 22), short_label, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.98, 0.98, 0.95))
				draw_string(ThemeDB.fallback_font, rect.position + Vector2(6, 35), str(block["remaining"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.98, 0.98, 0.95))
			if player_cell == Vector2i(x, y):
				draw_rect(rect.grow(-5), Color(0.25, 0.95, 0.70), false, 3.0)
				draw_circle(rect.position + Vector2(TILE / 2.0, TILE / 2.0), 6.0, Color(0.92, 1.0, 0.94))
	var player_center := GRID_ORIGIN + Vector2(player_cell.x * TILE + TILE / 2.0, player_cell.y * TILE + TILE / 2.0)
	var face_center := player_center + Vector2(facing.x, facing.y) * 13.0
	draw_line(player_center, face_center, Color(0.95, 1.0, 0.96), 3.0)

func _draw_hud() -> void:
	var x := 30.0
	var y := GRID_ORIGIN.y + GRID_H * TILE + 15.0
	draw_string(ThemeDB.fallback_font, Vector2(x, y), "ORE SHIFT // KROLL MINE", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0.86, 0.95, 0.94))
	y += 25.0
	var total := 0
	for key in inventory.keys():
		total += int(inventory[key])
	var inv_text := "Rock %d   Iron %d   Copper %d   Crystal %d   TOTAL %d/%d" % [inventory["rock"], inventory["iron"], inventory["copper"], inventory["crystal"], total, GOAL_ORE]
	draw_string(ThemeDB.fallback_font, Vector2(x, y), inv_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.90, 0.90, 0.83))
	y += 21.0
	var tool_info: Dictionary = TOOL_DATA[selected_tool]
	var durability_text := "%s  Power %d  Speed %.2fx  Durability %d/%d" % [tool_info["name"], tool_info["power"], tool_info["speed"], tool_durability[selected_tool], tool_info["max_durability"]]
	draw_string(ThemeDB.fallback_font, Vector2(x, y), durability_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.70, 0.88, 1.0))
	y += 20.0
	draw_string(ThemeDB.fallback_font, Vector2(x, y), "Move: WASD/Arrows   Mine: HOLD SPACE   Tool: 1/2   Repair at surface: R", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.75, 0.78, 0.79))
	y += 18.0
	draw_string(ThemeDB.fallback_font, Vector2(x, y), "Goal: collect %d units, then return to the top two rows." % GOAL_ORE, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.75, 0.78, 0.79))
	y += 22.0
	var msg_color := Color(0.95, 0.82, 0.48) if not won else Color(0.35, 1.0, 0.65)
	draw_string(ThemeDB.fallback_font, Vector2(x, y), status_message, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, msg_color)
	if won:
		draw_string(ThemeDB.fallback_font, Vector2(x, y + 22), "PRESS ENTER TO PLAY AGAIN", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.35, 1.0, 0.65))
