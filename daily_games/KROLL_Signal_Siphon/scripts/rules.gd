extends RefCounted

const PORT_N: int = 1
const PORT_E: int = 2
const PORT_S: int = 4
const PORT_W: int = 8

static func index_of(cell: Vector2i, width: int) -> int:
    return cell.y * width + cell.x

static func rotate_mask(mask: int, turns: int) -> int:
    var result := mask & 15
    for _i in range(posmod(turns, 4)):
        result = ((result << 1) & 15) | ((result >> 3) & 1)
    return result

static func ports_for(cell: Dictionary) -> int:
    return rotate_mask(int(cell.get("base_mask", 0)), int(cell.get("rotation", 0)))

static func make_puzzle(width: int = 5, height: int = 5) -> Array:
    var grid: Array = []
    for y in range(height):
        for x in range(width):
            var mask := PORT_E | PORT_W if (x + y) % 2 == 0 else PORT_N | PORT_S
            grid.append({
                "base_mask": mask,
                "rotation": (x * 3 + y) % 4,
                "fixed": false,
                "kind": "pipe"
            })

    # A guaranteed route from the source at (0,2) to the receiver at (4,2).
    var route: Array = [
        {"pos": Vector2i(1, 2), "mask": PORT_W | PORT_N, "rotation": 1},
        {"pos": Vector2i(1, 1), "mask": PORT_S | PORT_E, "rotation": 2},
        {"pos": Vector2i(2, 1), "mask": PORT_W | PORT_E, "rotation": 1},
        {"pos": Vector2i(3, 1), "mask": PORT_W | PORT_S, "rotation": 3},
        {"pos": Vector2i(3, 2), "mask": PORT_N | PORT_E, "rotation": 1}
    ]
    for entry in route:
        var pos: Vector2i = entry["pos"]
        grid[index_of(pos, width)] = {
            "base_mask": int(entry["mask"]),
            "rotation": int(entry["rotation"]),
            "fixed": false,
            "kind": "pipe"
        }
    grid[index_of(Vector2i(0, 2), width)] = {
        "base_mask": PORT_E, "rotation": 0, "fixed": true, "kind": "source"
    }
    grid[index_of(Vector2i(4, 2), width)] = {
        "base_mask": PORT_W, "rotation": 0, "fixed": true, "kind": "receiver"
    }
    return grid

static func is_connected(grid: Array, width: int, height: int, start: Vector2i, goal: Vector2i) -> bool:
    if width <= 0 or height <= 0 or grid.size() != width * height:
        return false
    if not _inside(start, width, height) or not _inside(goal, width, height):
        return false

    var dirs: Array[Vector2i] = [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]
    var bits: Array[int] = [PORT_N, PORT_E, PORT_S, PORT_W]
    var opposite: Array[int] = [PORT_S, PORT_W, PORT_N, PORT_E]
    var queue: Array[Vector2i] = [start]
    var visited: Dictionary = {index_of(start, width): true}
    var cursor: int = 0

    while cursor < queue.size():
        var current: Vector2i = queue[cursor]
        cursor += 1
        if current == goal:
            return true
        var current_ports := ports_for(grid[index_of(current, width)])
        for i in range(4):
            if (current_ports & bits[i]) == 0:
                continue
            var neighbor: Vector2i = current + dirs[i]
            if not _inside(neighbor, width, height):
                continue
            var neighbor_index := index_of(neighbor, width)
            if visited.has(neighbor_index):
                continue
            var neighbor_ports := ports_for(grid[neighbor_index])
            if (neighbor_ports & opposite[i]) != 0:
                visited[neighbor_index] = true
                queue.append(neighbor)
    return false

static func _inside(cell: Vector2i, width: int, height: int) -> bool:
    return cell.x >= 0 and cell.y >= 0 and cell.x < width and cell.y < height
