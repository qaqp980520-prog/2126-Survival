extends RefCounted

const WORLD_SIZE: Vector2 = Vector2(960.0, 540.0)
const PLAYER_SIZE: Vector2 = Vector2(28.0, 36.0)
const MOVE_SPEED: float = 260.0
const GRAVITY: float = 1100.0
const JUMP_SPEED: float = 470.0
const LEVEL_DATA: Array = [
    {
        "name": "Dustline Depot",
        "start": [48.0, 464.0],
        "package": [206.0, 468.0, 24.0, 24.0],
        "exit": [888.0, 444.0, 44.0, 56.0],
        "platforms": [[0.0, 500.0, 960.0, 40.0], [270.0, 430.0, 110.0, 16.0], [490.0, 380.0, 130.0, 16.0], [700.0, 430.0, 100.0, 16.0]],
        "hazards": [[360.0, 478.0, 54.0, 22.0], [640.0, 478.0, 62.0, 22.0]],
        "time_limit": 75.0,
        "par_time": 38.0
    },
    {
        "name": "Crater Relay",
        "start": [48.0, 464.0],
        "package": [156.0, 468.0, 24.0, 24.0],
        "exit": [884.0, 444.0, 44.0, 56.0],
        "platforms": [[0.0, 500.0, 960.0, 40.0], [180.0, 440.0, 110.0, 16.0], [370.0, 390.0, 120.0, 16.0], [580.0, 420.0, 130.0, 16.0], [760.0, 370.0, 100.0, 16.0]],
        "hazards": [[280.0, 478.0, 52.0, 22.0], [470.0, 478.0, 60.0, 22.0], [690.0, 478.0, 58.0, 22.0]],
        "time_limit": 85.0,
        "par_time": 46.0
    },
    {
        "name": "Polar Antenna Run",
        "start": [48.0, 464.0],
        "package": [112.0, 468.0, 24.0, 24.0],
        "exit": [884.0, 444.0, 44.0, 56.0],
        "platforms": [[0.0, 500.0, 960.0, 40.0], [150.0, 430.0, 100.0, 16.0], [330.0, 370.0, 120.0, 16.0], [520.0, 420.0, 120.0, 16.0], [700.0, 350.0, 120.0, 16.0]],
        "hazards": [[250.0, 478.0, 54.0, 22.0], [420.0, 478.0, 58.0, 22.0], [610.0, 478.0, 60.0, 22.0], [790.0, 478.0, 50.0, 22.0]],
        "time_limit": 95.0,
        "par_time": 54.0
    }
]

static func level_count() -> int:
    return LEVEL_DATA.size()

static func level_at(index: int) -> Dictionary:
    var safe_index: int = clampi(index, 0, LEVEL_DATA.size() - 1)
    var raw: Dictionary = LEVEL_DATA[safe_index]
    var result: Dictionary = raw.duplicate(true)
    var start_values: Array = raw["start"]
    result["start_position"] = Vector2(float(start_values[0]), float(start_values[1]))
    var package_values: Array = raw["package"]
    result["package_rect"] = Rect2(float(package_values[0]), float(package_values[1]), float(package_values[2]), float(package_values[3]))
    var exit_values: Array = raw["exit"]
    result["exit_rect"] = Rect2(float(exit_values[0]), float(exit_values[1]), float(exit_values[2]), float(exit_values[3]))
    var platforms: Array[Rect2] = []
    for entry in raw["platforms"]:
        var values: Array = entry
        platforms.append(Rect2(float(values[0]), float(values[1]), float(values[2]), float(values[3])))
    result["platforms"] = platforms
    var hazards: Array[Rect2] = []
    for entry in raw["hazards"]:
        var values: Array = entry
        hazards.append(Rect2(float(values[0]), float(values[1]), float(values[2]), float(values[3])))
    result["hazards"] = hazards
    return result

static func new_state(level_index: int = 0, campaign_score: int = 0, awarded: Array = []) -> Dictionary:
    var safe_index: int = clampi(level_index, 0, LEVEL_DATA.size() - 1)
    var level: Dictionary = level_at(safe_index)
    var awards: Array = awarded.duplicate(true)
    if awards.size() != LEVEL_DATA.size():
        awards = [false, false, false]
    return {
        "level_index": safe_index,
        "player_position": level["start_position"],
        "velocity": Vector2.ZERO,
        "grounded": false,
        "carrying": false,
        "package_rect": level["package_rect"],
        "exit_rect": level["exit_rect"],
        "lives": 3,
        "time_left": float(level["time_limit"]),
        "campaign_score": maxi(0, campaign_score),
        "awarded": awards,
        "status": "active"
    }

static func player_rect(position: Vector2) -> Rect2:
    return Rect2(position, PLAYER_SIZE)

static func rects_overlap(first: Rect2, second: Rect2) -> bool:
    return first.intersects(second)

static func landing_platform(previous_position: Vector2, current_position: Vector2, velocity_y: float, platforms: Array) -> int:
    if velocity_y < 0.0:
        return -1
    var previous_bottom: float = previous_position.y + PLAYER_SIZE.y
    var current_bottom: float = current_position.y + PLAYER_SIZE.y
    var best_index: int = -1
    var best_top: float = INF
    for index in range(platforms.size()):
        var platform: Rect2 = platforms[index]
        var horizontal_overlap: bool = (
            current_position.x < platform.position.x + platform.size.x
            and current_position.x + PLAYER_SIZE.x > platform.position.x
        )
        if not horizontal_overlap:
            continue
        if previous_bottom <= platform.position.y + 1.0 and current_bottom >= platform.position.y:
            if platform.position.y < best_top:
                best_top = platform.position.y
                best_index = index
    return best_index
