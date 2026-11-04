extends RefCounted
class_name DebrisSkimmerRules

const FIELD_RECT := Rect2(24.0, 76.0, 1052.0, 500.0)
const DOCK_POSITION := Vector2(104.0, 326.0)
const DOCK_RADIUS := 62.0
const TRACTOR_RANGE := 104.0
const SHIP_ACCELERATION := 220.0
const REVERSE_ACCELERATION := 135.0
const TURN_RATE := 2.7
const MAX_SPEED := 280.0
const DRAG_PER_FRAME := 0.994

const SECTORS := [
	{"name":"Ring Fragments","target":3,"cargo_positions":[Vector2(330,150),Vector2(545,155),Vector2(760,455),Vector2(910,260)],"asteroids":[{"position":Vector2(430,285),"velocity":Vector2(42,31),"radius":19.0},{"position":Vector2(700,345),"velocity":Vector2(-34,25),"radius":25.0}]},
	{"name":"Ice Drift","target":4,"cargo_positions":[Vector2(280,475),Vector2(455,145),Vector2(640,475),Vector2(840,165),Vector2(940,430)],"asteroids":[{"position":Vector2(360,300),"velocity":Vector2(56,-24),"radius":21.0},{"position":Vector2(650,280),"velocity":Vector2(-45,38),"radius":24.0},{"position":Vector2(900,330),"velocity":Vector2(25,48),"radius":16.0}]},
	{"name":"Station Graveyard","target":5,"cargo_positions":[Vector2(265,150),Vector2(410,470),Vector2(570,160),Vector2(730,465),Vector2(900,250),Vector2(965,485)],"asteroids":[{"position":Vector2(340,310),"velocity":Vector2(62,28),"radius":22.0},{"position":Vector2(550,355),"velocity":Vector2(-50,-34),"radius":27.0},{"position":Vector2(800,300),"velocity":Vector2(36,55),"radius":20.0},{"position":Vector2(970,145),"velocity":Vector2(-44,42),"radius":17.0}]}
]

static func sector_count() -> int:
	return SECTORS.size()

static func sector_data(index: int) -> Dictionary:
	return SECTORS[clampi(index, 0, SECTORS.size() - 1)].duplicate(true)

static func wrap_position(position: Vector2) -> Vector2:
	return Vector2(wrapf(position.x, FIELD_RECT.position.x, FIELD_RECT.end.x), wrapf(position.y, FIELD_RECT.position.y, FIELD_RECT.end.y))

static func integrate_ship(position: Vector2, velocity: Vector2, heading: float, turn: float, thrust: bool, reverse: bool, delta: float) -> Dictionary:
	var safe_delta := clampf(delta, 0.0, 0.05)
	var next_heading := wrapf(heading + clampf(turn, -1.0, 1.0) * TURN_RATE * safe_delta, -PI, PI)
	var next_velocity := velocity
	var forward := Vector2.RIGHT.rotated(next_heading)
	if thrust:
		next_velocity += forward * SHIP_ACCELERATION * safe_delta
	if reverse:
		next_velocity -= forward * REVERSE_ACCELERATION * safe_delta
	next_velocity *= pow(DRAG_PER_FRAME, safe_delta * 60.0)
	if next_velocity.length() > MAX_SPEED:
		next_velocity = next_velocity.normalized() * MAX_SPEED
	return {"position":wrap_position(position + next_velocity * safe_delta),"velocity":next_velocity,"heading":next_heading}

static func can_collect(ship_position: Vector2, cargo_position: Vector2, radius: float = TRACTOR_RANGE) -> bool:
	return radius >= 0.0 and ship_position.distance_to(cargo_position) <= radius

static func can_dock(ship_position: Vector2) -> bool:
	return ship_position.distance_to(DOCK_POSITION) <= DOCK_RADIUS

static func sector_complete(delivered: int, target: int) -> bool:
	return target > 0 and delivered >= target

static func clear_reward(already_cleared: bool) -> int:
	return 0 if already_cleared else 100
