extends SceneTree

const Layout = preload("res://systems/BackroomsMazeLayout.gd")
const CELL_SIZE: float = 8.0
const TEST_SEED: int = 20261026

func _initialize() -> void:
	_test_cell_mapping_and_validation()
	_test_parent_tree_reaches_origin()
	_test_edge_symmetry_and_determinism()
	_test_seed_changes_only_seeded_passages()
	print("Backrooms maze layout tests passed.")
	quit(0)

func _test_cell_mapping_and_validation() -> void:
	assert(Layout.is_valid_cell_size(CELL_SIZE))
	assert(not Layout.is_valid_cell_size(0.0))
	assert(not Layout.is_valid_cell_size(-CELL_SIZE))
	assert(not Layout.is_valid_cell_size(NAN))
	assert(Layout.cell_for_position(Vector3.ZERO, CELL_SIZE) == Vector2i.ZERO)
	assert(Layout.cell_for_position(Vector3(3.999, 0.0, -3.999), CELL_SIZE) == Vector2i.ZERO)
	assert(Layout.cell_for_position(Vector3(4.0, 0.0, 0.0), CELL_SIZE) == Vector2i(1, 0))
	assert(Layout.cell_for_position(Vector3(-4.0, 0.0, 0.0), CELL_SIZE) == Vector2i.ZERO)
	assert(Layout.cell_for_position(Vector3(-4.001, 0.0, 0.0), CELL_SIZE) == Vector2i(-1, 0))
	assert(Layout.cell_for_position(Vector3(0.0, 0.0, 4.0), CELL_SIZE) == Vector2i(0, 1))
	assert(Layout.cell_for_position(Vector3(0.0, 0.0, -4.001), CELL_SIZE) == Vector2i(0, -1))
	assert(not bool(Layout.try_cell_for_position(Vector3(NAN, 0.0, 0.0), CELL_SIZE).get("ok", false)))
	assert(not bool(Layout.try_cell_for_position(Vector3.ZERO, 0.0).get("ok", false)))
	assert(Layout.cell_for_position(Vector3.ZERO, 0.0) == Vector2i.ZERO)

func _test_parent_tree_reaches_origin() -> void:
	assert(Layout.parent_toward_origin(Vector2i.ZERO) == Vector2i.ZERO)
	for z in range(-32, 33):
		for x in range(-32, 33):
			var origin_cell := Vector2i(x, z)
			var cursor: Vector2i = origin_cell
			var steps: int = 0
			var expected_steps: int = absi(x) + absi(z)
			while cursor != Vector2i.ZERO:
				var direction: Vector2i = Layout.parent_toward_origin(cursor)
				assert(absi(direction.x) + absi(direction.y) == 1, "Every non-origin parent direction is cardinal.")
				assert(Layout.edge_is_open(cursor, direction, TEST_SEED), "Every parent edge is guaranteed open.")
				var next_cell: Vector2i = cursor + direction
				assert(absi(next_cell.x) + absi(next_cell.y) == absi(cursor.x) + absi(cursor.y) - 1, "Every parent step reduces Manhattan distance.")
				cursor = next_cell
				steps += 1
				assert(steps <= expected_steps, "Parent traversal cannot cycle.")
			assert(steps == expected_steps, "Every sampled cell reaches the origin in exactly Manhattan-distance steps.")

func _test_edge_symmetry_and_determinism() -> void:
	var directions: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	for z in range(-32, 33):
		for x in range(-32, 33):
			var cell := Vector2i(x, z)
			for direction in directions:
				var first: bool = Layout.edge_is_open(cell, direction, TEST_SEED)
				var reverse: bool = Layout.edge_is_open(cell + direction, -direction, TEST_SEED)
				assert(first == reverse, "Both cells must agree on their shared edge.")
				assert(first == Layout.edge_is_open(cell, direction, TEST_SEED), "The same seed must reproduce the same edge.")
	assert(not Layout.edge_is_open(Vector2i.ZERO, Vector2i.ZERO, TEST_SEED), "Non-cardinal edges fail closed.")
	assert(not Layout.edge_is_open(Vector2i.ZERO, Vector2i(1, 1), TEST_SEED), "Diagonal edges fail closed.")

func _test_seed_changes_only_seeded_passages() -> void:
	var different_edges: int = 0
	var directions: Array[Vector2i] = [Vector2i(1, 0), Vector2i(0, 1)]
	for z in range(-24, 25):
		for x in range(-24, 25):
			var cell := Vector2i(x, z)
			for direction in directions:
				var first: bool = Layout.edge_is_open(cell, direction, TEST_SEED)
				var second: bool = Layout.edge_is_open(cell, direction, TEST_SEED + 1)
				if first != second:
					different_edges += 1
				var parent_edge: bool = Layout.parent_toward_origin(cell) == direction or Layout.parent_toward_origin(cell + direction) == -direction
				if parent_edge:
					assert(first and second, "Changing the world seed must not close a spanning-tree edge.")
	assert(different_edges > 0, "Different layout seeds must alter at least some optional passages.")
