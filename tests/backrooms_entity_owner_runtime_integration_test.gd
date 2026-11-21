extends SceneTree

const RuntimeScript = preload("res://systems/BackroomsMazeCellRuntime.gd")
const EntityRuntimeStateScript = preload("res://systems/BackroomsEntityRuntimeState.gd")
const FileStoreScript = preload("res://systems/WorldEnvelopeFileStore.gd")
const MovementDriverScript = preload("res://systems/BackroomsEntityMovementDriver.gd")
const DISK_SAVE_PATH: String = "user://run342_backrooms_hound_file_roundtrip.json"
const MOBILE_ENTITY_IDS := ["smiler", "hound", "skin_stealer", "faceling", "duller", "deathmoth"]

class PhysicsMovementTickDriver:
	extends Node

	var runtime: Node
	var movement_driver: RefCounted
	var result: Dictionary = {}
	var attempts: int = 0
	var max_attempts: int = 12
	var finished: bool = false

	func _physics_process(_delta: float) -> void:
		if finished:
			return
		attempts += 1
		if runtime == null or movement_driver == null:
			result = {"ok": false, "reason": "physics_driver_dependency_missing"}
			finished = true
			set_physics_process(false)
			return
		result = movement_driver.call("tick", runtime, 0.11)
		if int(result.get("transferred_count", 0)) > 0 or attempts >= max_attempts:
			finished = true
			set_physics_process(false)


var failures: Array[String] = []
var disk_restore_runtime: Node3D
var disk_restore_report: Dictionary = {}

func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var runtime: Node3D = RuntimeScript.new() as Node3D
	root.add_child(runtime)
	var metadata_probe := Node3D.new()
	var probe_window := CharacterBody3D.new()
	probe_window.set_meta("backrooms_entity_id", "window")
	probe_window.set_meta("spawn_cell", Vector2i(-1, 0))
	metadata_probe.add_child(probe_window)
	var probe_hound := CharacterBody3D.new()
	probe_hound.set_meta("backrooms_entity_id", "hound")
	probe_hound.set_meta("spawn_cell", Vector2i(0, 0))
	metadata_probe.add_child(probe_hound)
	metadata_probe.set_meta("backrooms_entity_identity_keys", ["-1,0|window", "0,0|hound"])
	metadata_probe.set_meta("backrooms_entity_spawn_ids", ["window", "hound"])
	_expect(
		bool(runtime.call("_validate_cell_entity_identity_metadata", metadata_probe)),
		"cell identity metadata accepts supported static and mobile entities with aligned live nodes"
	)
	metadata_probe.set_meta("backrooms_entity_identity_keys", ["-1,0|window", "-1,0|window"])
	metadata_probe.set_meta("backrooms_entity_spawn_ids", ["window", "window"])
	_expect(
		not bool(runtime.call("_validate_cell_entity_identity_metadata", metadata_probe)),
		"cell identity metadata rejects duplicate live spawn identities"
	)
	metadata_probe.free()
	var prepared: Dictionary = runtime.call(
		"prepare_destination", "Level 2", 20261118, Vector3.ZERO, 8.0, 1
	)
	_expect(bool(prepared.get("ok", false)), "runtime prepares a deterministic Level 2 ownership window")
	if not bool(prepared.get("ok", false)):
		_finish(runtime, null)
		return
	_expect(bool(runtime.call("activate_destination")), "prepared ownership runtime activates")

	var candidate: Dictionary = _find_transfer_candidate(runtime)
	_expect(not candidate.is_empty(), "loaded maze contains a mobile entity with an open adjacent ownership hop")
	if candidate.is_empty():
		_finish(runtime, null)
		return
	var entity_root: CharacterBody3D = candidate.get("entity_root") as CharacterBody3D
	var source_root: Node3D = candidate.get("source_root") as Node3D
	var spawn_cell_key: String = str(candidate.get("spawn_cell_key", ""))
	var entity_id: String = str(candidate.get("entity_id", ""))
	_expect(entity_id == "hound", "Level 2 transfer fixture selects the Hound for durable file-persistence coverage")
	var source_cell: Vector2i = candidate.get("source_cell", Vector2i.ZERO)
	var target_cell: Vector2i = candidate.get("target_cell", Vector2i.ZERO)
	var direction: Vector2i = candidate.get("direction", Vector2i.ZERO)
	var target_key: String = "%d,%d" % [target_cell.x, target_cell.y]
	var source_key: String = "%d,%d" % [source_cell.x, source_cell.y]
	var route: Dictionary = candidate.get("route", {})
	var middle_turn_cell: Vector2i = Vector2i(0, -1)
	var middle_turn_key: String = "%d,%d" % [middle_turn_cell.x, middle_turn_cell.y]
	var middle_turn_root: Node3D = runtime.call("get_cell_root", middle_turn_key) as Node3D
	var pursuit_goal_cell: Vector2i = candidate.get("pursuit_goal_cell", Vector2i.ZERO)
	var pursuit_goal_key: String = "%d,%d" % [pursuit_goal_cell.x, pursuit_goal_cell.y]
	var pursuit_goal_root: Node3D = runtime.call("get_cell_root", pursuit_goal_key) as Node3D
	var pursuit_route: Dictionary = candidate.get("pursuit_route", {})
	var pursuit_path_value: Variant = pursuit_route.get("cell_path", [])
	var pursuit_directions_value: Variant = pursuit_route.get("edge_directions", [])
	var first_hop_direction: Vector2i = Vector2i.ZERO
	var second_hop_direction: Vector2i = Vector2i.ZERO
	var third_hop_direction: Vector2i = Vector2i.ZERO
	if pursuit_directions_value is Array and pursuit_directions_value.size() == 3:
		if pursuit_directions_value[0] is Vector2i:
			first_hop_direction = pursuit_directions_value[0]
		if pursuit_directions_value[1] is Vector2i:
			second_hop_direction = pursuit_directions_value[1]
		if pursuit_directions_value[2] is Vector2i:
			third_hop_direction = pursuit_directions_value[2]
	_expect(
		bool(pursuit_route.get("ok", false))
		and pursuit_path_value is Array
		and pursuit_path_value.size() == 4
		and pursuit_path_value[1] == target_cell
		and pursuit_path_value[2] == middle_turn_cell
		and pursuit_path_value[3] == pursuit_goal_cell
		and first_hop_direction == direction
		and absi(second_hop_direction.x) + absi(second_hop_direction.y) == 1
		and second_hop_direction != direction
		and second_hop_direction != -direction
		and absi(third_hop_direction.x) + absi(third_hop_direction.y) == 1
		and third_hop_direction != second_hop_direction
		and third_hop_direction != -second_hop_direction,
		"selected Hound has a validated three-hop route with two 90-degree turns"
	)
	_expect(
		source_cell == Vector2i(1, 0)
		and target_cell == Vector2i(0, 0)
		and middle_turn_cell == Vector2i(0, -1)
		and pursuit_goal_cell == Vector2i(-1, -1)
		and direction == Vector2i(-1, 0)
		and first_hop_direction == Vector2i(-1, 0)
		and second_hop_direction == Vector2i(0, -1)
		and third_hop_direction == Vector2i(-1, 0),
		"Level 2 seed 20261118 resolves the deterministic west-north-west three-hop fixture"
	)
	_expect(middle_turn_root != null and pursuit_goal_root != null, "both loaded turn and pursuit destination roots are available")
	_expect(entity_root != null and source_root != null and not spawn_cell_key.is_empty(), "selected entity preserves its immutable spawn identity")
	_expect(entity_root != null and str(entity_root.get_meta("spawn_level_id", "")) == "Level 2", "spawn descriptor factory preserves the runtime level identity")
	_expect(entity_root != null and int(entity_root.get_meta("spawn_world_seed", -1)) == 20261118, "spawn descriptor factory preserves the runtime world seed")

	var initial_owner: Dictionary = runtime.call("get_entity_owner_record", spawn_cell_key, entity_id)
	_expect(spawn_cell_key == source_key, "selected entity begins in its immutable deterministic spawn cell")
	_expect(str(initial_owner.get("owner_cell_key", "")) == source_key, "initial ownership ledger assigns the deterministic spawn cell")
	_expect(int(initial_owner.get("owner_revision", -1)) == 0, "initial ownership revision is zero")
	var identity_key: String = spawn_cell_key + "|" + entity_id
	var target_root: Node3D = runtime.call("get_cell_root", target_key) as Node3D
	_expect(target_root != null, "adjacent transfer target root is loaded")
	var source_identity_keys_before: Array = source_root.get_meta("backrooms_entity_identity_keys", []).duplicate()
	var source_spawn_ids_before: Array = source_root.get_meta("backrooms_entity_spawn_ids", []).duplicate()
	var target_identity_keys_before: Array = target_root.get_meta("backrooms_entity_identity_keys", []).duplicate() if target_root != null else []
	var target_spawn_ids_before: Array = target_root.get_meta("backrooms_entity_spawn_ids", []).duplicate() if target_root != null else []
	var source_identity_index_before: int = source_identity_keys_before.find(identity_key)
	_expect(source_identity_index_before >= 0, "source cell identity metadata contains the immutable spawn key")
	_expect(
		source_identity_index_before >= 0
		and source_identity_index_before < source_spawn_ids_before.size()
		and str(source_spawn_ids_before[source_identity_index_before]) == entity_id,
		"source cell identity arrays preserve aligned spawn IDs"
	)

	var safe_extent: float = 8.0 * 0.5 - 0.65
	var source_local: Vector3 = entity_root.position
	source_local.x = 0.0
	source_local.z = 0.0
	entity_root.position = source_local
	var premature_transfer: Dictionary = runtime.call(
		"transfer_entity_to_next_cell", spawn_cell_key, entity_id, route
	)
	_expect(not bool(premature_transfer.get("ok", false)), "transfer is rejected before the entity reaches the source-cell edge")
	_expect(str(premature_transfer.get("reason", "")) == "transfer_entity_not_at_cell_edge", "premature transfer reports the boundary precondition")
	_expect(entity_root.get_parent() == source_root, "premature transfer leaves node ownership unchanged")

	# The edge tolerance applies only along the travel axis, never to the perpendicular serialized coordinate.
	var invalid_horizontal: Vector3 = source_local
	if direction.x != 0:
		invalid_horizontal.x = float(direction.x) * safe_extent
		invalid_horizontal.z = safe_extent + 0.25
	else:
		invalid_horizontal.z = float(direction.y) * safe_extent
		invalid_horizontal.x = safe_extent + 0.25
	entity_root.position = invalid_horizontal
	var horizontal_bounds_transfer: Dictionary = runtime.call(
		"transfer_entity_to_next_cell", spawn_cell_key, entity_id, route
	)
	_expect(
		not bool(horizontal_bounds_transfer.get("ok", false))
		and str(horizontal_bounds_transfer.get("reason", "")) == "transfer_entity_position_out_of_bounds",
		"transfer rejects an out-of-bounds perpendicular cell coordinate before preparing ownership"
	)
	_expect(entity_root.get_parent() == source_root, "horizontal bounds rejection preserves the source Node owner")
	var horizontal_owner: Dictionary = runtime.call("get_entity_owner_record", spawn_cell_key, entity_id)
	_expect(
		str(horizontal_owner.get("owner_cell_key", "")) == source_key
		and int(horizontal_owner.get("owner_revision", -1)) == 0,
		"horizontal bounds rejection preserves the committed owner and revision"
	)
	var ledger_after_horizontal: RefCounted = runtime.get("ownership_ledger") as RefCounted
	_expect(
		ledger_after_horizontal != null
		and int(ledger_after_horizontal.call("get_pending_transfer_count")) == 0,
		"horizontal bounds rejection creates no pending ledger transaction"
	)

	var invalid_vertical: Vector3 = source_local
	if direction.x != 0:
		invalid_vertical.x = float(direction.x) * safe_extent
	else:
		invalid_vertical.z = float(direction.y) * safe_extent
	invalid_vertical.y = EntityRuntimeStateScript.MAX_LOCAL_Y + 0.25
	entity_root.position = invalid_vertical
	var vertical_bounds_transfer: Dictionary = runtime.call(
		"transfer_entity_to_next_cell", spawn_cell_key, entity_id, route
	)
	_expect(
		not bool(vertical_bounds_transfer.get("ok", false))
		and str(vertical_bounds_transfer.get("reason", "")) == "transfer_entity_position_out_of_bounds",
		"transfer rejects a vertical position outside the serialized owner-cell bounds"
	)
	_expect(entity_root.get_parent() == source_root, "vertical bounds rejection preserves the source Node owner")
	var vertical_owner: Dictionary = runtime.call("get_entity_owner_record", spawn_cell_key, entity_id)
	_expect(
		str(vertical_owner.get("owner_cell_key", "")) == source_key
		and int(vertical_owner.get("owner_revision", -1)) == 0,
		"vertical bounds rejection preserves the committed owner and revision"
	)
	var ledger_after_vertical: RefCounted = runtime.get("ownership_ledger") as RefCounted
	_expect(
		ledger_after_vertical != null
		and int(ledger_after_vertical.call("get_pending_transfer_count")) == 0,
		"vertical bounds rejection creates no pending ledger transaction"
	)
	entity_root.position = source_local

	if direction.x != 0:
		entity_root.position.x = float(direction.x) * safe_extent
	else:
		entity_root.position.z = float(direction.y) * safe_extent
	var edge_transform: Transform3D = entity_root.global_transform
	var stale_route: Dictionary = route.duplicate(true)
	stale_route["stream_generation"] = int(stale_route.get("stream_generation", 0)) + 1
	var stale_transfer: Dictionary = runtime.call(
		"transfer_entity_to_next_cell", spawn_cell_key, entity_id, stale_route
	)
	_expect(not bool(stale_transfer.get("ok", false)), "stale route snapshot is rejected before node reparent")
	_expect(entity_root.get_parent() == source_root, "rejected stale transfer leaves the live entity under its original owner")
	_expect(entity_root.global_transform.origin.is_equal_approx(edge_transform.origin), "rejected stale transfer preserves the exact entity position")
	_expect(
		str(runtime.call("get_entity_owner_record", spawn_cell_key, entity_id).get("owner_cell_key", "")) == source_key,
		"rejected stale transfer leaves the ownership ledger unchanged"
	)

	var ownership_ledger: RefCounted = runtime.get("ownership_ledger") as RefCounted
	var blocked_target_local: Vector3 = target_root.to_local(entity_root.global_position)
	if direction.x != 0:
		blocked_target_local.x = -float(direction.x) * safe_extent
	else:
		blocked_target_local.z = -float(direction.y) * safe_extent
	var blocker := StaticBody3D.new()
	blocker.name = "TransferRollbackBlocker"
	blocker.collision_layer = 1
	blocker.collision_mask = 0
	var blocker_shape := CollisionShape3D.new()
	var blocker_box := BoxShape3D.new()
	blocker_box.size = Vector3(1.4, 4.0, 1.4)
	blocker_shape.shape = blocker_box
	blocker.add_child(blocker_shape)
	blocker.position = blocked_target_local
	target_root.add_child(blocker)
	await physics_frame
	var blocked_transfer: Dictionary = runtime.call(
		"transfer_entity_to_next_cell", spawn_cell_key, entity_id, route
	)
	_expect(not bool(blocked_transfer.get("ok", false)), "physical obstruction rejects the live owner transfer")
	_expect(str(blocked_transfer.get("reason", "")) == "transfer_physics_handoff_blocked", "blocked transfer reports the physics handoff failure")
	_expect(entity_root.get_parent() == source_root, "blocked transfer reparents the entity back to its original cell")
	_expect(entity_root.global_transform.origin.is_equal_approx(edge_transform.origin), "blocked transfer restores the exact pre-transfer transform")
	var owner_after_block: Dictionary = runtime.call("get_entity_owner_record", spawn_cell_key, entity_id)
	_expect(str(owner_after_block.get("owner_cell_key", "")) == source_key and int(owner_after_block.get("owner_revision", -1)) == 0, "blocked transfer leaves the ownership ledger and revision unchanged")
	_expect(ownership_ledger != null and int(ownership_ledger.call("get_pending_transfer_count")) == 0, "blocked transfer clears its pending ledger transaction")
	_expect(source_root.get_meta("backrooms_entity_identity_keys", []) == source_identity_keys_before, "blocked transfer leaves source identity metadata unchanged")
	_expect(source_root.get_meta("backrooms_entity_spawn_ids", []) == source_spawn_ids_before, "blocked transfer leaves source spawn IDs unchanged")
	_expect(target_root.get_meta("backrooms_entity_identity_keys", []) == target_identity_keys_before, "blocked transfer leaves target identity metadata unchanged")
	_expect(target_root.get_meta("backrooms_entity_spawn_ids", []) == target_spawn_ids_before, "blocked transfer leaves target spawn IDs unchanged")
	target_root.remove_child(blocker)
	blocker.free()
	await physics_frame

	var hound_brain: Node = entity_root.get_node_or_null("AI")
	_expect(hound_brain != null, "selected Hound exposes its production behavior brain")
	var transfer: Dictionary = {}
	var second_transfer: Dictionary = {}
	var second_transfer_ok: bool = false
	var third_transfer: Dictionary = {}
	var third_transfer_ok: bool = false
	if hound_brain != null:
		var pursuit_staging_local: Vector3 = entity_root.position
		if direction.x != 0:
			pursuit_staging_local.x = float(direction.x) * 2.5
			pursuit_staging_local.z = 1.0
		else:
			pursuit_staging_local.z = float(direction.y) * 2.5
			pursuit_staging_local.x = 1.0
		entity_root.position = pursuit_staging_local
		var perpendicular_target_offset := Vector3.ZERO
		if direction.x != 0:
			perpendicular_target_offset.z = 1.25
		else:
			perpendicular_target_offset.x = 1.25
		var target_world_position: Vector3 = (
			pursuit_goal_root.global_position
			+ Vector3(0.0, entity_root.position.y, 0.0)
			+ perpendicular_target_offset
		)
		var pursuit_decision: Dictionary = hound_brain.call("evaluate_perception", {
			"distance_to_player": entity_root.global_position.distance_to(target_world_position),
			"has_line_of_sight": true,
			"player_looking_at_entity": false,
			"noise_strength": 0.0,
			"player_position": target_world_position
		}, 0.2)
		_expect(str(pursuit_decision.get("state", "")) == "pursue", "Hound receives a pursuit target three loaded cells away")
		await physics_frame
		var movement_driver = MovementDriverScript.new()
		var movement_records: Array = movement_driver.call("_collect_entity_records", runtime)
		var hound_identity_key: String = spawn_cell_key + "|" + entity_id
		var hound_record_found: bool = false
		for movement_record in movement_records:
			if str(movement_record.get("key", "")) == hound_identity_key:
				hound_record_found = true
				break
		_expect(hound_record_found, "movement scheduler collects the selected Hound under its immutable spawn identity")
		movement_driver.set("_next_entity_key", hound_identity_key)
		var physics_tick_driver := PhysicsMovementTickDriver.new()
		physics_tick_driver.runtime = runtime
		physics_tick_driver.movement_driver = movement_driver
		physics_tick_driver.max_attempts = 12
		runtime.add_child(physics_tick_driver)
		physics_tick_driver.set_physics_process(true)
		for _physics_attempt in range(12):
			if physics_tick_driver.finished:
				break
			await physics_frame
		var movement_result: Dictionary = physics_tick_driver.result
		var current_owner: Dictionary = runtime.call("get_entity_owner_record", spawn_cell_key, entity_id)
		_expect(physics_tick_driver.finished, "movement driver completes or safely times out inside an actual physics callback")
		print(
			"HOUND_CROSS_CELL_PERSISTENCE_DIAGNOSTIC result=", movement_result,
			" owner=", current_owner,
			" physics_attempts=", physics_tick_driver.attempts,
			" driver=", movement_driver.call("get_diagnostics")
		)
		var transfer_results: Array = movement_result.get("transfer_results", [])
		if not transfer_results.is_empty() and transfer_results[0] is Dictionary:
			transfer = transfer_results[0]
		_expect(
			int(movement_result.get("transferred_count", 0)) == 1 and bool(transfer.get("ok", false)),
			"Hound pursuit driver reaches the edge and commits the production ownership transfer; result=%s owner=%s" % [
				str(movement_result), str(current_owner)
			]
		)
		_expect(
			str(transfer.get("from_owner_cell_key", "")) == source_key
			and str(transfer.get("to_owner_cell_key", "")) == target_key,
			"first physics tick commits only the first adjacent hop of the three-hop route"
		)
		var first_hop_owner: Dictionary = runtime.call("get_entity_owner_record", spawn_cell_key, entity_id)
		_expect(entity_root.get_parent() == target_root, "first hop reparents the Hound into the intermediate cell")
		_expect(str(first_hop_owner.get("owner_cell_key", "")) == target_key and int(first_hop_owner.get("owner_revision", -1)) == 1, "first hop commits owner revision one")
		_expect(int(entity_root.get_meta("backrooms_owner_revision", -1)) == 1, "first-hop entity metadata records revision one")
		_expect(_count_identity_in_root(source_root, spawn_cell_key, entity_id) == 0 and _count_identity_in_root(target_root, spawn_cell_key, entity_id) == 1, "first hop moves the single Hound identity from A into B")
		var first_hop_perpendicular: float = entity_root.position.z if direction.x != 0 else entity_root.position.x
		_expect(
			absf(first_hop_perpendicular) <= 0.25,
			"turning first hop centers its doorway instead of projecting a later-cell target offset"
		)
		var first_hop_edge_coordinate: float = entity_root.position.x if direction.x != 0 else entity_root.position.z
		_expect(absf(first_hop_edge_coordinate) <= safe_extent - 0.02 + 0.001, "first-hop landing remains inside the strict serialization boundary")
		movement_driver.call("reset")
		if bool(transfer.get("ok", false)):
			movement_driver.set("_next_entity_key", hound_identity_key)
			var second_physics_tick_driver := PhysicsMovementTickDriver.new()
			second_physics_tick_driver.runtime = runtime
			second_physics_tick_driver.movement_driver = movement_driver
			second_physics_tick_driver.max_attempts = 24
			runtime.add_child(second_physics_tick_driver)
			second_physics_tick_driver.set_physics_process(true)
			for _second_physics_attempt in range(24):
				if second_physics_tick_driver.finished:
					break
				await physics_frame
			var second_movement_result: Dictionary = second_physics_tick_driver.result
			var second_transfer_results: Array = second_movement_result.get("transfer_results", [])
			if not second_transfer_results.is_empty() and second_transfer_results[0] is Dictionary:
				second_transfer = second_transfer_results[0]
			second_transfer_ok = (
				int(second_movement_result.get("transferred_count", 0)) == 1
				and bool(second_transfer.get("ok", false))
			)
			var second_owner: Dictionary = runtime.call("get_entity_owner_record", spawn_cell_key, entity_id)
			_expect(second_physics_tick_driver.finished, "second Hound hop completes or safely times out in a separate physics tick")
			_expect(second_transfer_ok, "second physics tick commits exactly one additional Hound owner transfer; result=%s owner=%s" % [str(second_movement_result), str(second_owner)])
			_expect(
				str(second_transfer.get("from_owner_cell_key", "")) == target_key
				and str(second_transfer.get("to_owner_cell_key", "")) == middle_turn_key,
				"second hop is replanned from B and commits the first turn into C"
			)
			_expect(
				str(second_owner.get("owner_cell_key", "")) == middle_turn_key
				and int(second_owner.get("owner_revision", -1)) == 2,
				"second hop commits the intermediate turn cell at owner revision two"
			)
			_expect(entity_root.get_parent() == middle_turn_root, "live Hound is reparented into the second-hop turn cell")
			var second_hop_perpendicular: float = entity_root.position.x
			_expect(absf(second_hop_perpendicular) <= 0.25, "second turning hop centers its north-facing doorway")
			var second_hop_edge_coordinate: float = entity_root.position.z
			_expect(absf(second_hop_edge_coordinate) <= safe_extent - 0.02 + 0.001, "second-hop landing remains inside the strict serialization boundary")
			_expect(_count_identity_in_root(target_root, spawn_cell_key, entity_id) == 0, "B no longer contains the Hound after the second transfer")
			_expect(_count_identity_in_root(middle_turn_root, spawn_cell_key, entity_id) == 1, "C contains exactly one Hound identity after the second transfer")
			_expect(_count_identity_in_root(source_root, spawn_cell_key, entity_id) == 0, "A remains free of a duplicate after two hops")
			_expect(ownership_ledger != null and int(ownership_ledger.call("get_pending_transfer_count")) == 0, "second hop closes its ownership-ledger transaction")
			movement_driver.call("reset")
			if second_transfer_ok:
				movement_driver.set("_next_entity_key", hound_identity_key)
				var third_physics_tick_driver := PhysicsMovementTickDriver.new()
				third_physics_tick_driver.runtime = runtime
				third_physics_tick_driver.movement_driver = movement_driver
				third_physics_tick_driver.max_attempts = 24
				runtime.add_child(third_physics_tick_driver)
				third_physics_tick_driver.set_physics_process(true)
				for _third_physics_attempt in range(24):
					if third_physics_tick_driver.finished:
						break
					await physics_frame
				var third_movement_result: Dictionary = third_physics_tick_driver.result
				var third_transfer_results: Array = third_movement_result.get("transfer_results", [])
				if not third_transfer_results.is_empty() and third_transfer_results[0] is Dictionary:
					third_transfer = third_transfer_results[0]
				third_transfer_ok = (
					int(third_movement_result.get("transferred_count", 0)) == 1
					and bool(third_transfer.get("ok", false))
				)
				var third_owner: Dictionary = runtime.call("get_entity_owner_record", spawn_cell_key, entity_id)
				_expect(third_physics_tick_driver.finished, "third Hound hop completes or safely times out in its own physics tick")
				_expect(third_transfer_ok, "third physics tick commits exactly one additional Hound owner transfer; result=%s owner=%s" % [str(third_movement_result), str(third_owner)])
				_expect(
					str(third_transfer.get("from_owner_cell_key", "")) == middle_turn_key
					and str(third_transfer.get("to_owner_cell_key", "")) == pursuit_goal_key,
					"third hop is replanned from C and commits the second turn into D"
				)
				_expect(
					str(third_owner.get("owner_cell_key", "")) == pursuit_goal_key
					and int(third_owner.get("owner_revision", -1)) == 3,
					"three-hop pursuit commits the final owner cell at revision three"
				)
				_expect(entity_root.get_parent() == pursuit_goal_root, "live Hound is reparented into the third-hop destination cell")
				_expect(_count_identity_in_root(source_root, spawn_cell_key, entity_id) == 0, "A remains free of a duplicate after three hops")
				_expect(_count_identity_in_root(target_root, spawn_cell_key, entity_id) == 0, "B remains free of a duplicate after three hops")
				_expect(_count_identity_in_root(middle_turn_root, spawn_cell_key, entity_id) == 0, "C no longer contains the Hound after the third transfer")
				_expect(_count_identity_in_root(pursuit_goal_root, spawn_cell_key, entity_id) == 1, "D contains exactly one Hound identity after the third transfer")
				_expect(ownership_ledger != null and int(ownership_ledger.call("get_pending_transfer_count")) == 0, "third hop closes its ownership-ledger transaction")
				print("HOUND_THREE_HOP_DIAGNOSTIC first=", transfer, " second=", second_transfer, " third=", third_transfer, " owner=", third_owner, " attempts=", second_physics_tick_driver.attempts, "/", third_physics_tick_driver.attempts)
				movement_driver.call("reset")
				if third_transfer_ok:
					target_cell = pursuit_goal_cell
					target_key = pursuit_goal_key
					target_root = pursuit_goal_root
	if not bool(transfer.get("ok", false)) or not second_transfer_ok or not third_transfer_ok:
		_finish(runtime, null)
		return
	_expect(target_root != null and entity_root.get_parent() == target_root, "live entity is reparented to the next loaded cell")
	_expect(entity_root.get_meta("spawn_cell", null) == source_cell, "ownership transfer preserves immutable spawn-cell identity")
	_expect(str(entity_root.get_meta("backrooms_owner_cell_key", "")) == target_key, "entity metadata records the new owner cell")
	_expect(int(entity_root.get_meta("backrooms_owner_revision", -1)) == 3, "entity metadata records the final three-hop owner revision")
	var owner_record: Dictionary = runtime.call("get_entity_owner_record", spawn_cell_key, entity_id)
	_expect(str(owner_record.get("owner_cell_key", "")) == target_key and int(owner_record.get("owner_revision", -1)) == 3, "ownership ledger commits the final three-hop owner and revision")
	var source_identity_keys_after: Array = source_root.get_meta("backrooms_entity_identity_keys", [])
	var source_spawn_ids_after: Array = source_root.get_meta("backrooms_entity_spawn_ids", [])
	var target_identity_keys_after: Array = target_root.get_meta("backrooms_entity_identity_keys", [])
	var target_spawn_ids_after: Array = target_root.get_meta("backrooms_entity_spawn_ids", [])
	var target_identity_index: int = target_identity_keys_after.find(identity_key)
	_expect(not source_identity_keys_after.has(identity_key), "successful transfer removes immutable identity from source cell metadata")
	_expect(target_identity_index >= 0, "successful transfer registers immutable identity in target cell metadata")
	_expect(target_identity_index >= 0 and str(target_spawn_ids_after[target_identity_index]) == entity_id, "target cell identity and spawn ID arrays remain aligned")
	_expect(source_identity_keys_after.size() == source_spawn_ids_after.size(), "source cell identity arrays remain aligned after transfer")
	_expect(target_identity_keys_after.size() == target_spawn_ids_after.size(), "target cell identity arrays remain aligned after transfer")
	_expect(ownership_ledger != null and int(ownership_ledger.call("get_pending_transfer_count")) == 0, "successful transfer closes its ledger transaction")
	_expect(
		absf(entity_root.position.x) <= safe_extent + 0.001
		and absf(entity_root.position.z) <= safe_extent + 0.001,
		"transferred entity lands inside the target cell's safe physics bounds"
	)
	var final_target_local: Vector3 = target_root.to_local(
		pursuit_goal_root.global_position
		+ Vector3(0.0, entity_root.position.y, 0.0)
		+ (Vector3(0.0, 0.0, 1.25) if third_hop_direction.x != 0 else Vector3(1.25, 0.0, 0.0))
	)
	var final_perpendicular: float = entity_root.position.z if third_hop_direction.x != 0 else entity_root.position.x
	var expected_final_perpendicular: float = final_target_local.z if third_hop_direction.x != 0 else final_target_local.x
	_expect(absf(final_perpendicular - expected_final_perpendicular) <= 0.25, "third-hop landing preserves the projected perpendicular target within the transfer tolerance")
	var final_edge_coordinate: float = entity_root.position.x if third_hop_direction.x != 0 else entity_root.position.z
	_expect(absf(final_edge_coordinate) <= safe_extent - 0.02 + 0.001, "third-hop landing remains inside the strict serialization boundary")

	var saved_after_transfer: Dictionary = runtime.call("to_save_dict")
	_expect(not saved_after_transfer.is_empty(), "immediate save after owner transfer accepts the migrated owner-local position")
	if int(saved_after_transfer.get("schema_version", -1)) != 4:
		var runtime_state: RefCounted = runtime.get("stream_state") as RefCounted
		var capture_diagnostic: Dictionary = runtime.call(
			"_collect_entity_runtime_states", runtime_state, runtime_state.call("get_center_cell")
		) if runtime_state != null else {"ok": false, "reason": "stream_state_unavailable"}
		var ledger_diagnostic: RefCounted = runtime.get("ownership_ledger") as RefCounted
		var ledger_save_diagnostic: Dictionary = runtime.call(
			"_get_ownership_ledger_save", runtime_state, ledger_diagnostic
		) if runtime_state != null and ledger_diagnostic != null else {}
		print(
			"POST_TRANSFER_SAVE_DIAGNOSTIC last_error=%s capture_ok=%s capture_reason=%s capture_records=%d live_ledger_records=%d ledger_save_records=%d pending=%d owner=%s revision=%d local_position=%s"
			% [
				str(runtime.get("last_error")),
				str(capture_diagnostic.get("ok", false)),
				str(capture_diagnostic.get("reason", "")),
				(capture_diagnostic.get("records", []) as Array).size(),
				(ledger_diagnostic.call("get_records") as Array).size() if ledger_diagnostic != null else -1,
				(ledger_save_diagnostic.get("records", []) as Array).size(),
				int(ledger_diagnostic.call("get_pending_transfer_count")) if ledger_diagnostic != null else -1,
				str(entity_root.get_meta("backrooms_owner_cell_key", "")),
				int(entity_root.get_meta("backrooms_owner_revision", -1)),
				str(entity_root.position)
			]
		)
	_expect(int(saved_after_transfer.get("schema_version", -1)) == 4, "runtime saves ownership state using maze schema four")
	_expect(int(saved_after_transfer.get("entity_ownership_ledger_version", -1)) == 1, "runtime save declares ownership ledger version one")
	var ledger_payload: Dictionary = saved_after_transfer.get("entity_ownership_ledger", {})
	var saved_owner_found: bool = false
	for record_value in ledger_payload.get("records", []):
		if record_value is Dictionary:
			var record: Dictionary = record_value
			if str(record.get("spawn_cell_key", "")) == spawn_cell_key and str(record.get("entity_id", "")) == entity_id:
				saved_owner_found = str(record.get("owner_cell_key", "")) == target_key
	_expect(saved_owner_found, "save snapshot persists the migrated owner-cell assignment")

	var far_center: Vector2i = pursuit_goal_cell + Vector2i(2, 0)
	var far_position := Vector3(float(far_center.x) * 8.0, 0.0, float(far_center.y) * 8.0)
	var away_result: Dictionary = runtime.call("sync_to_world_position", far_position)
	_expect(bool(away_result.get("ok", false)), "stream can unload the owner cell while retaining its one-cell-halo ownership record")
	_expect(runtime.call("get_cell_root", target_key) == null, "owner cell is actually unloaded before reconstruction")
	var retained_after_unload: Dictionary = runtime.call("get_entity_owner_record", spawn_cell_key, entity_id)
	_expect(str(retained_after_unload.get("owner_cell_key", "")) == target_key, "ownership ledger retains the owner assignment inside the one-cell halo")
	var archive_after_unload: Dictionary = runtime.call("to_save_dict")
	var archived_owner_found: bool = false
	for record_value in archive_after_unload.get("entity_runtime_states", []):
		if record_value is Dictionary:
			var record: Dictionary = record_value
			if str(record.get("spawn_cell_key", "")) == spawn_cell_key and str(record.get("entity_id", "")) == entity_id:
				archived_owner_found = str(record.get("cell_key", "")) == target_key
	_expect(archived_owner_found, "unloaded migrated entity remains archived under its mutable owner cell")

	var live_stream_state: RefCounted = runtime.get("stream_state") as RefCounted
	var original_archived_states: Array = live_stream_state.call("get_entity_runtime_states")
	var migrated_state_index: int = -1
	for index in range(original_archived_states.size()):
		var archived_record: Dictionary = original_archived_states[index]
		if str(archived_record.get("spawn_cell_key", "")) == spawn_cell_key and str(archived_record.get("entity_id", "")) == entity_id:
			migrated_state_index = index
	_expect(migrated_state_index >= 0, "unloaded migrated owner has one archived runtime-state record")
	var mismatched_owner_cell: Vector2i = target_cell + Vector2i(-direction.y, direction.x)
	var mismatched_owner_key: String = "%d,%d" % [mismatched_owner_cell.x, mismatched_owner_cell.y]

	# Save must fail closed for either half of a broken state/ledger pair, without
	# mutating the already committed StreamState snapshot.
	if migrated_state_index >= 0:
		var mismatched_live_states: Array = original_archived_states.duplicate(true)
		var mismatched_live_record: Dictionary = mismatched_live_states[migrated_state_index]
		mismatched_live_record["cell_key"] = mismatched_owner_key
		mismatched_live_states[migrated_state_index] = mismatched_live_record
		_expect(bool(live_stream_state.call("set_entity_runtime_states", mismatched_live_states)), "test fixture accepts a structurally valid but owner-mismatched archived record")
		var before_mismatch_save: Dictionary = live_stream_state.call("to_save_dict")
		var mismatch_save: Dictionary = runtime.call("to_save_dict")
		_expect(mismatch_save.is_empty(), "save rejects an archived state whose owner cell disagrees with the ledger")
		_expect(live_stream_state.call("to_save_dict") == before_mismatch_save, "failed mismatched save leaves the committed StreamState snapshot unchanged")
		var before_shift_center: Vector2i = live_stream_state.call("get_center_cell")
		var before_shift_loaded: Array = runtime.call("get_loaded_cell_keys")
		var rejected_shift: Dictionary = runtime.call(
			"sync_to_world_position",
			Vector3(
				float(before_shift_center.x + mismatched_owner_cell.x - target_cell.x) * 8.0,
				0.0,
				float(before_shift_center.y + mismatched_owner_cell.y - target_cell.y) * 8.0
			)
		)
		_expect(not bool(rejected_shift.get("ok", false)), "stream-window shift rejects a retained state/ledger owner mismatch")
		_expect(live_stream_state.call("get_center_cell") == before_shift_center, "rejected stream shift preserves the committed center cell")
		_expect(runtime.call("get_loaded_cell_keys") == before_shift_loaded, "rejected stream shift preserves the loaded-cell window")
		_expect(bool(live_stream_state.call("set_entity_runtime_states", original_archived_states)), "test restores the original archived state after mismatch-save probe")

		var missing_live_states: Array = original_archived_states.duplicate(true)
		missing_live_states.remove_at(migrated_state_index)
		_expect(bool(live_stream_state.call("set_entity_runtime_states", missing_live_states)), "test fixture removes only the migrated archived state")
		var before_missing_save: Dictionary = live_stream_state.call("to_save_dict")
		var missing_save: Dictionary = runtime.call("to_save_dict")
		_expect(missing_save.is_empty(), "save rejects a migrated ownership record with no runtime-state archive")
		_expect(live_stream_state.call("to_save_dict") == before_missing_save, "failed missing-state save leaves the committed StreamState snapshot unchanged")
		_expect(bool(live_stream_state.call("set_entity_runtime_states", original_archived_states)), "test restores the original archive after missing-state save probe")

	var mismatched_payload: Dictionary = archive_after_unload.duplicate(true)
	var mismatched_payload_states: Array = mismatched_payload.get("entity_runtime_states", [])
	for index in range(mismatched_payload_states.size()):
		var record: Dictionary = mismatched_payload_states[index]
		if str(record.get("spawn_cell_key", "")) == spawn_cell_key and str(record.get("entity_id", "")) == entity_id:
			record["cell_key"] = mismatched_owner_key
			mismatched_payload_states[index] = record
	mismatched_payload["entity_runtime_states"] = mismatched_payload_states
	var mismatch_restore: Node3D = RuntimeScript.new() as Node3D
	mismatch_restore.set("force_metadata_only", true)
	root.add_child(mismatch_restore)
	var mismatch_restore_ok: bool = bool(mismatch_restore.call("load_save_dict", mismatched_payload))
	_expect(not mismatch_restore_ok, "restore rejects a retained runtime-state owner key that disagrees with the ownership ledger")
	_expect(not bool(mismatch_restore.call("is_prepared")) and int(mismatch_restore.call("get_loaded_cell_count")) == 0, "owner-key mismatch leaves the destination runtime unprepared and empty")
	mismatch_restore.queue_free()

	var missing_payload: Dictionary = archive_after_unload.duplicate(true)
	var missing_payload_states: Array = missing_payload.get("entity_runtime_states", [])
	for index in range(missing_payload_states.size() - 1, -1, -1):
		var record: Dictionary = missing_payload_states[index]
		if str(record.get("spawn_cell_key", "")) == spawn_cell_key and str(record.get("entity_id", "")) == entity_id:
			missing_payload_states.remove_at(index)
	var missing_ledger_payload: Dictionary = archive_after_unload.duplicate(true)
	var ownership_payload: Dictionary = missing_ledger_payload.get("entity_ownership_ledger", {})
	var ownership_records: Array = ownership_payload.get("records", [])
	for index in range(ownership_records.size() - 1, -1, -1):
		var ownership_record: Dictionary = ownership_records[index]
		if str(ownership_record.get("spawn_cell_key", "")) == spawn_cell_key and str(ownership_record.get("entity_id", "")) == entity_id:
			ownership_records.remove_at(index)
	ownership_payload["records"] = ownership_records
	missing_ledger_payload["entity_ownership_ledger"] = ownership_payload
	var missing_ledger_restore: Node3D = RuntimeScript.new() as Node3D
	missing_ledger_restore.set("force_metadata_only", true)
	root.add_child(missing_ledger_restore)
	var missing_ledger_restore_ok: bool = bool(missing_ledger_restore.call("load_save_dict", missing_ledger_payload))
	_expect(not missing_ledger_restore_ok, "restore rejects a runtime-state record with no matching ownership-ledger record")
	_expect(not bool(missing_ledger_restore.call("is_prepared")) and int(missing_ledger_restore.call("get_loaded_cell_count")) == 0, "missing ownership record leaves the destination runtime unprepared and empty")
	missing_ledger_restore.queue_free()

	missing_payload["entity_runtime_states"] = missing_payload_states
	var missing_restore: Node3D = RuntimeScript.new() as Node3D
	missing_restore.set("force_metadata_only", true)
	root.add_child(missing_restore)
	var missing_restore_ok: bool = bool(missing_restore.call("load_save_dict", missing_payload))
	_expect(not missing_restore_ok, "restore rejects a migrated ownership record whose runtime-state archive is missing")
	_expect(not bool(missing_restore.call("is_prepared")) and int(missing_restore.call("get_loaded_cell_count")) == 0, "missing migrated state leaves the destination runtime unprepared and empty")
	missing_restore.queue_free()

	# The valid owner cell is outside the loaded window but still inside the retention
	# halo. Restore must keep its ledger/state pair, then reconstruct it when streamed in.
	var unloaded_restored: Node3D = RuntimeScript.new() as Node3D
	unloaded_restored.set("force_metadata_only", true)
	root.add_child(unloaded_restored)
	var valid_unloaded_restore: bool = bool(unloaded_restored.call("load_save_dict", archive_after_unload))
	_expect(valid_unloaded_restore, "valid migrated owner restores while its owner cell is retained but unloaded")
	if valid_unloaded_restore:
		_expect(unloaded_restored.call("get_cell_root", target_key) == null, "valid unloaded-owner restore does not eagerly load the retained owner cell")
		var unloaded_owner_record: Dictionary = unloaded_restored.call("get_entity_owner_record", spawn_cell_key, entity_id)
		_expect(str(unloaded_owner_record.get("owner_cell_key", "")) == target_key, "unloaded restore preserves the mutable owner-cell assignment")
		_expect(bool(unloaded_restored.call("activate_destination")), "unloaded-owner restore activates only after candidate validation")
		var unloaded_return: Dictionary = unloaded_restored.call("sync_to_world_position", Vector3(float(target_cell.x) * 8.0, 0.0, float(target_cell.y) * 8.0))
		_expect(bool(unloaded_return.get("ok", false)), "streaming the retained owner cell back in succeeds after unloaded restore")
		var unloaded_identity: Dictionary = _find_entity(unloaded_restored, spawn_cell_key, entity_id)
		_expect(int(unloaded_identity.get("count", 0)) == 1, "unloaded-owner restore reconstructs exactly one migrated entity when its cell loads")
		var unloaded_entity: CharacterBody3D = unloaded_identity.get("entity_root") as CharacterBody3D
		var unloaded_owner_root: Node3D = unloaded_restored.call("get_cell_root", target_key) as Node3D
		_expect(
			unloaded_entity != null and unloaded_owner_root != null and unloaded_entity.get_parent() == unloaded_owner_root,
			"unloaded-owner reconstruction attaches the entity under the persisted owner cell"
		)
	unloaded_restored.queue_free()

	var return_position := Vector3(float(target_cell.x) * 8.0, 0.0, float(target_cell.y) * 8.0)
	var return_result: Dictionary = runtime.call("sync_to_world_position", return_position)
	_expect(bool(return_result.get("ok", false)), "returning to the retained owner cell stages a reconstruction transaction")
	var reconstructed: Dictionary = _find_entity(runtime, spawn_cell_key, entity_id)
	_expect(int(reconstructed.get("count", 0)) == 1, "reconstruction creates exactly one entity for the immutable spawn identity")
	var reconstructed_root: CharacterBody3D = reconstructed.get("entity_root") as CharacterBody3D
	var reconstructed_owner_root: Node3D = runtime.call("get_cell_root", target_key) as Node3D
	_expect(
		reconstructed_root != null and reconstructed_owner_root != null
		and reconstructed_root.get_parent() == reconstructed_owner_root,
		"reconstructed entity is attached to its persisted owner cell, not its original spawn cell"
	)
	if reconstructed_root != null:
		_expect(str(reconstructed_root.get_meta("backrooms_owner_cell_key", "")) == target_key, "reconstructed node restores owner-cell metadata")
		_expect(int(reconstructed_root.get_meta("backrooms_owner_revision", -1)) == 3, "reconstructed node restores three-hop owner revision")
	var spawn_root: Node3D = runtime.call("get_cell_root", spawn_cell_key) as Node3D
	var spawn_cell_identity_count: int = _count_identity_in_root(spawn_root, spawn_cell_key, entity_id)
	_expect(spawn_cell_identity_count == 0, "original spawn cell does not create a duplicate after owner-cell reconstruction")

	var final_save: Dictionary = runtime.call("to_save_dict")
	var runtime_records: Array = final_save.get("entity_runtime_states", [])
	_expect(not runtime_records.is_empty(), "transferred Hound snapshot contains a validated runtime-state record")
	if not runtime_records.is_empty():
		var expected_level_id: String = str(final_save.get("level_id", "Level 2"))
		var expected_world_seed: int = int(final_save.get("world_seed", 20261118))
		var expected_cell_size: float = float(final_save.get("cell_size", 8.0))
		var expected_spawn_version: int = int(final_save.get("entity_spawn_algorithm_version", 1))
		var huge_spawn_version_records: Array = runtime_records.duplicate(true)
		huge_spawn_version_records[0]["spawn_algorithm_version"] = 1e308
		var huge_spawn_version_result: Dictionary = EntityRuntimeStateScript.validate_records(
			huge_spawn_version_records, expected_level_id, expected_world_seed, expected_cell_size, expected_spawn_version
		)
		_expect(not bool(huge_spawn_version_result.get("ok", false)), "entity runtime validator rejects huge finite spawn versions without integer overflow")
		var huge_patrol_records: Array = runtime_records.duplicate(true)
		huge_patrol_records[0]["patrol_index"] = 1e308
		var huge_patrol_result: Dictionary = EntityRuntimeStateScript.validate_records(
			huge_patrol_records, expected_level_id, expected_world_seed, expected_cell_size, expected_spawn_version
		)
		_expect(not bool(huge_patrol_result.get("ok", false)), "entity runtime validator rejects huge finite patrol indices before integer conversion")
		var huge_brain_schema_records: Array = runtime_records.duplicate(true)
		huge_brain_schema_records[0]["brain_state"]["schema_version"] = 1e308
		var huge_brain_schema_result: Dictionary = EntityRuntimeStateScript.validate_records(
			huge_brain_schema_records, expected_level_id, expected_world_seed, expected_cell_size, expected_spawn_version
		)
		_expect(not bool(huge_brain_schema_result.get("ok", false)), "Hound brain validator rejects huge finite schema numbers without integer overflow")
		var huge_brain_seed_records: Array = runtime_records.duplicate(true)
		huge_brain_seed_records[0]["brain_state"]["world_seed"] = 1e308
		var huge_brain_seed_result: Dictionary = EntityRuntimeStateScript.validate_records(
			huge_brain_seed_records, expected_level_id, expected_world_seed, expected_cell_size, expected_spawn_version
		)
		_expect(not bool(huge_brain_seed_result.get("ok", false)), "Hound brain validator rejects huge finite world seeds without integer overflow")
		var huge_brain_spawn_records: Array = runtime_records.duplicate(true)
		huge_brain_spawn_records[0]["brain_state"]["spawn_cell"] = [1e308, 0]
		var huge_brain_spawn_result: Dictionary = EntityRuntimeStateScript.validate_records(
			huge_brain_spawn_records, expected_level_id, expected_world_seed, expected_cell_size, expected_spawn_version
		)
		_expect(not bool(huge_brain_spawn_result.get("ok", false)), "Hound brain validator rejects huge finite spawn coordinates without integer overflow")
	var restored: Node3D = RuntimeScript.new() as Node3D
	root.add_child(restored)
	_expect(bool(restored.call("load_save_dict", final_save)), "fresh runtime reconstructs migrated ownership from the combined maze payload")
	_expect(bool(restored.call("activate_destination")), "restored ownership runtime activates only after reconstruction")
	var restored_identity: Dictionary = _find_entity(restored, spawn_cell_key, entity_id)
	_expect(int(restored_identity.get("count", 0)) == 1, "save/load round trip preserves exactly one migrated entity")
	var restored_root: CharacterBody3D = restored_identity.get("entity_root") as CharacterBody3D
	var restored_owner_root: Node3D = restored.call("get_cell_root", target_key) as Node3D
	_expect(
		restored_root != null and restored_owner_root != null and restored_root.get_parent() == restored_owner_root,
		"save/load round trip restores the entity under its committed owner cell"
	)
	_expect(
		str(restored.call("get_entity_owner_record", spawn_cell_key, entity_id).get("owner_cell_key", "")) == target_key,
		"save/load round trip restores the ownership ledger assignment"
	)
	_expect(restored.call("to_save_dict") == final_save, "restored ownership runtime reproduces the exact saved maze and ledger snapshot")

	# Persist the transferred Hound snapshot through the same atomic file store used by
	# SurfaceWorld. Corrupt the primary after rotating a known-good backup, then recover.
	var file_store: RefCounted = FileStoreScript.new()
	var disk_envelope: Dictionary = {
		"schema_version": 1,
		"active_location": "backrooms",
		"backrooms_runtime": final_save.duplicate(true)
	}
	_expect(bool(file_store.call("write_atomically", DISK_SAVE_PATH, disk_envelope)), "atomic file store writes the Hound owner-ledger/runtime-state envelope")
	_expect(bool(file_store.call("write_atomically", DISK_SAVE_PATH, disk_envelope)), "second atomic write rotates a known-good Hound envelope into .bak")
	_expect(_write_text(DISK_SAVE_PATH, "{malformed primary"), "test corrupts only the primary Hound save after backup rotation")
	disk_restore_runtime = RuntimeScript.new() as Node3D
	root.add_child(disk_restore_runtime)
	var disk_loaded: bool = bool(file_store.call(
		"load_with_backup",
		DISK_SAVE_PATH,
		Callable(self, "_restore_runtime_from_file_envelope"),
		Callable(self, "_get_disk_restore_report"),
		int(Time.get_unix_time_from_system())
	))
	_expect(disk_loaded, "corrupt Hound primary recovers from the atomic .bak file")
	var disk_report: Dictionary = file_store.call("get_last_report")
	_expect(str(disk_report.get("phase", "")) == "backup_restored", "Hound backup recovery reports the backup restore phase")
	var disk_details: Dictionary = disk_report.get("details", {})
	_expect(str(disk_details.get("source", "")) == DISK_SAVE_PATH + ".bak", "Hound recovery identifies the exact backup source")
	_expect(bool(disk_details.get("primary_repaired", false)), "Hound backup recovery repairs the primary after preserving corruption")
	_expect(FileAccess.file_exists(DISK_SAVE_PATH + ".corrupt"), "malformed Hound primary is preserved as a diagnostic file")
	var disk_owner: Dictionary = disk_restore_runtime.call("get_entity_owner_record", spawn_cell_key, entity_id)
	_expect(
		str(disk_owner.get("owner_cell_key", "")) == target_key and int(disk_owner.get("owner_revision", -1)) == 3,
		"disk recovery preserves Hound immutable spawn identity, mutable owner cell, and owner revision"
	)
	var disk_identity: Dictionary = _find_entity(disk_restore_runtime, spawn_cell_key, entity_id)
	_expect(int(disk_identity.get("count", 0)) == 1, "disk recovery reconstructs exactly one Hound for the immutable spawn identity")
	var disk_entity: CharacterBody3D = disk_identity.get("entity_root") as CharacterBody3D
	var disk_owner_root: Node3D = disk_restore_runtime.call("get_cell_root", target_key) as Node3D
	_expect(
		disk_entity != null and disk_owner_root != null and disk_entity.get_parent() == disk_owner_root,
		"disk-recovered Hound is attached under the committed owner cell"
	)
	if disk_entity != null:
		_expect(str(disk_entity.get_meta("backrooms_owner_cell_key", "")) == target_key, "disk-recovered Hound node restores owner-cell metadata")
		_expect(int(disk_entity.get_meta("backrooms_owner_revision", -1)) == 3, "disk-recovered Hound node restores three-hop owner revision metadata")
		var disk_agent: NavigationAgent3D = disk_entity.get_node_or_null("NavigationAnchor/NavigationAgent") as NavigationAgent3D
		_expect(disk_agent != null, "disk-recovered Hound receives a fresh NavigationAgent3D from the current cell factory")
		if disk_agent != null:
			_expect(not disk_agent.avoidance_enabled, "disk-recovered NavigationAgent3D preserves the bounded non-avoidance policy")
			_expect(absf(disk_agent.path_desired_distance - 0.2) <= 0.0001, "disk-recovered NavigationAgent3D uses the current waypoint tolerance")
	var disk_runtime_snapshot: Dictionary = disk_restore_runtime.call("to_save_dict")
	_expect(
		_save_values_equal(disk_runtime_snapshot, final_save),
		"disk-recovered Hound reproduces the semantic ownership and runtime-state snapshot after JSON numeric canonicalization"
	)

	# Schema-three saves predate the ownership ledger. A retained owner==spawn
	# archive must be deterministically backfilled even when its cell is not loaded.
	var legacy_payload: Dictionary = final_save.duplicate(true)
	legacy_payload["schema_version"] = 3
	legacy_payload.erase("entity_ownership_ledger_version")
	legacy_payload.erase("entity_ownership_ledger")
	# Move the stream center two cells west of immutable spawn cell A so it is unloaded
	# from the 3x3 window while remaining inside the retention halo.
	var legacy_center: Vector2i = source_cell + direction * 2
	legacy_payload["center_cell"] = [legacy_center.x, legacy_center.y]
	var legacy_state: Dictionary = {}
	for state_value in final_save.get("entity_runtime_states", []):
		if state_value is Dictionary:
			var state_record: Dictionary = state_value
			if str(state_record.get("spawn_cell_key", "")) == spawn_cell_key and str(state_record.get("entity_id", "")) == entity_id:
				legacy_state = state_record.duplicate(true)
				legacy_state["cell_key"] = spawn_cell_key
				break
	legacy_payload["entity_runtime_states"] = [legacy_state] if not legacy_state.is_empty() else []
	_expect(not legacy_state.is_empty(), "legacy migration fixture retains the original deterministic spawn state")
	var legacy_restored: Node3D = RuntimeScript.new() as Node3D
	root.add_child(legacy_restored)
	var legacy_loaded: bool = bool(legacy_restored.call("load_save_dict", legacy_payload))
	_expect(legacy_loaded, "schema-three owner==spawn archive restores through deterministic ledger backfill")
	if legacy_loaded:
		_expect(legacy_restored.call("get_cell_root", spawn_cell_key) == null, "legacy backfilled owner remains archived while its cell is outside the loaded window")
		var legacy_owner: Dictionary = legacy_restored.call("get_entity_owner_record", spawn_cell_key, entity_id)
		_expect(str(legacy_owner.get("owner_cell_key", "")) == spawn_cell_key, "legacy backfill assigns only the immutable spawn cell as owner")
		_expect(bool(legacy_restored.call("activate_destination")), "legacy migrated runtime activates after backfill validation")
		var legacy_return: Dictionary = legacy_restored.call(
			"sync_to_world_position",
			Vector3(float(source_cell.x) * 8.0, 0.0, float(source_cell.y) * 8.0)
		)
		_expect(bool(legacy_return.get("ok", false)), "legacy owner cell streams back in after deterministic backfill")
		var legacy_identity: Dictionary = _find_entity(legacy_restored, spawn_cell_key, entity_id)
		_expect(int(legacy_identity.get("count", 0)) == 1, "legacy owner==spawn state reconstructs exactly once")
	legacy_restored.queue_free()

	_finish(runtime, restored)


func _find_transfer_candidate(runtime: Node) -> Dictionary:
	var directions: Array[Vector2i] = [
		Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)
	]
	var loaded_keys_value: Variant = runtime.call("get_loaded_cell_keys")
	if not (loaded_keys_value is Array):
		return {}
	var loaded_keys: Array = loaded_keys_value
	for cell_key_value in loaded_keys:
		var cell_key: String = str(cell_key_value)
		var cell_root: Node3D = runtime.call("get_cell_root", cell_key) as Node3D
		if cell_root == null:
			continue
		var cell_value: Variant = cell_root.get_meta("backrooms_cell", null)
		if not (cell_value is Vector2i):
			continue
		var cell: Vector2i = cell_value
		if cell != Vector2i(1, 0):
			continue
		for child in cell_root.get_children():
			if not (child is CharacterBody3D):
				continue
			var entity_id: String = str(child.get_meta("backrooms_entity_id", ""))
			if entity_id != "hound":
				continue
			var spawn_value: Variant = child.get_meta("spawn_cell", null)
			if not (spawn_value is Vector2i):
				continue
			var spawn_cell: Vector2i = spawn_value
			var spawn_key: String = "%d,%d" % [spawn_cell.x, spawn_cell.y]
			for direction in directions:
				if direction != Vector2i(-1, 0):
					continue
				var target_cell: Vector2i = cell + direction
				var route: Dictionary = runtime.call("plan_route_between_loaded_cells", cell, target_cell)
				var first_path_value: Variant = route.get("cell_path", [])
				if not bool(route.get("ok", false)) or not (first_path_value is Array) or first_path_value.size() != 2:
					continue
				for goal_key_value in loaded_keys:
					var goal_root: Node3D = runtime.call("get_cell_root", str(goal_key_value)) as Node3D
					if goal_root == null:
						continue
					var goal_cell_value: Variant = goal_root.get_meta("backrooms_cell", null)
					if not (goal_cell_value is Vector2i):
						continue
					var goal_cell: Vector2i = goal_cell_value
					if goal_cell != Vector2i(-1, -1):
						continue
					if goal_cell == cell or goal_cell == target_cell:
						continue
					var pursuit_route: Dictionary = runtime.call("plan_route_between_loaded_cells", cell, goal_cell)
					var pursuit_path_value: Variant = pursuit_route.get("cell_path", [])
					var pursuit_directions_value: Variant = pursuit_route.get("edge_directions", [])
					if (
						bool(pursuit_route.get("ok", false))
						and pursuit_path_value is Array
						and pursuit_path_value.size() == 4
						and pursuit_path_value[1] == target_cell
						and pursuit_path_value[2] == Vector2i(0, -1)
						and pursuit_path_value[3] == goal_cell
						and pursuit_directions_value is Array
						and pursuit_directions_value.size() == 3
						and pursuit_directions_value[0] is Vector2i
						and pursuit_directions_value[0] == direction
						and pursuit_directions_value[1] is Vector2i
						and pursuit_directions_value[1] == Vector2i(0, -1)
						and pursuit_directions_value[2] is Vector2i
						and pursuit_directions_value[2] == Vector2i(-1, 0)
					):
						return {
							"entity_root": child,
							"source_root": cell_root,
							"spawn_cell_key": spawn_key,
							"entity_id": entity_id,
							"source_cell": cell,
							"target_cell": target_cell,
							"direction": direction,
							"route": route,
							"pursuit_goal_cell": goal_cell,
							"pursuit_route": pursuit_route
						}
	return {}


func _find_entity(runtime: Node, spawn_cell_key: String, entity_id: String) -> Dictionary:
	var matches: Array[CharacterBody3D] = []
	for cell_key_value in runtime.call("get_loaded_cell_keys"):
		var cell_root: Node3D = runtime.call("get_cell_root", str(cell_key_value)) as Node3D
		if cell_root == null:
			continue
		for child in cell_root.get_children():
			if not (child is CharacterBody3D) or str(child.get_meta("backrooms_entity_id", "")) != entity_id:
				continue
			var spawn_value: Variant = child.get_meta("spawn_cell", null)
			if not (spawn_value is Vector2i):
				continue
			var spawn_cell: Vector2i = spawn_value
			if ("%d,%d" % [spawn_cell.x, spawn_cell.y]) == spawn_cell_key:
				matches.append(child as CharacterBody3D)
	return {
		"count": matches.size(),
		"entity_root": matches[0] if matches.size() == 1 else null
	}


func _count_identity_in_root(cell_root: Node3D, spawn_cell_key: String, entity_id: String) -> int:
	if cell_root == null:
		return 0
	var count: int = 0
	for child in cell_root.get_children():
		if not (child is CharacterBody3D) or str(child.get_meta("backrooms_entity_id", "")) != entity_id:
			continue
		var spawn_value: Variant = child.get_meta("spawn_cell", null)
		if not (spawn_value is Vector2i):
			continue
		var spawn_cell: Vector2i = spawn_value
		if ("%d,%d" % [spawn_cell.x, spawn_cell.y]) == spawn_cell_key:
			count += 1
	return count


static func _save_values_equal(left: Variant, right: Variant) -> bool:
	if left is Dictionary:
		if not (right is Dictionary) or left.size() != right.size():
			return false
		for key in left.keys():
			if not right.has(key) or not _save_values_equal(left[key], right[key]):
				return false
		return true
	if left is Array:
		if not (right is Array) or left.size() != right.size():
			return false
		for index in range(left.size()):
			if not _save_values_equal(left[index], right[index]):
				return false
		return true
	if (left is int or left is float) and (right is int or right is float):
		return float(left) == float(right)
	return left == right


func _restore_runtime_from_file_envelope(payload: Dictionary, _now_unix: int = -1) -> bool:
	disk_restore_report = {"success": false, "phase": "validation", "rollback_complete": true}
	if disk_restore_runtime == null or not (payload.get("backrooms_runtime", null) is Dictionary):
		return false
	var runtime_payload: Dictionary = payload.get("backrooms_runtime", {})
	var restored_ok: bool = bool(disk_restore_runtime.call("load_save_dict", runtime_payload))
	if restored_ok:
		restored_ok = bool(disk_restore_runtime.call("activate_destination"))
	disk_restore_report = {
		"success": restored_ok,
		"phase": "complete" if restored_ok else "runtime_restore",
		"rollback_complete": true
	}
	return restored_ok


func _get_disk_restore_report() -> Dictionary:
	return disk_restore_report.duplicate(true)


func _write_text(path: String, value: String) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(value)
	file.flush()
	var write_error: Error = file.get_error()
	file.close()
	return write_error == OK


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failures.append(message)
	push_error("FAILED: " + message)


func _finish(runtime: Node3D, restored: Node3D) -> void:
	if restored != null:
		restored.queue_free()
	if disk_restore_runtime != null:
		disk_restore_runtime.queue_free()
	if runtime != null:
		runtime.queue_free()
	for suffix in ["", ".tmp", ".bak", ".corrupt"]:
		var path: String = DISK_SAVE_PATH + suffix
		var absolute: String = ProjectSettings.globalize_path(path)
		if FileAccess.file_exists(path) or DirAccess.dir_exists_absolute(absolute):
			DirAccess.remove_absolute(absolute)
	await process_frame
	if failures.is_empty():
		print("Backrooms entity owner runtime integration tests passed.")
		quit(0)
	else:
		for failure in failures:
			push_error("FAILED: " + failure)
		quit(1)
