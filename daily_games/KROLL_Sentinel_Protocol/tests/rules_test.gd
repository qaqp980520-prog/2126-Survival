extends SceneTree
const Rules = preload("res://scripts/game_rules.gd")
var failures: Array[String] = []
func _initialize() -> void:
    _expect(Rules.apply_damage(3, 1) == 2, "damage reduces core integrity")
    _expect(Rules.apply_damage(1, 8) == 0, "damage clamps integrity to zero")
    _expect(Rules.apply_damage(2, -3) == 2, "negative damage cannot alter integrity")
    _expect(Rules.clamp_player_position(Vector2(-50, 900), Vector2(1280, 720)) == Vector2(17, 703), "player stays inside viewport")
    _expect(Rules.hit_test(Vector2.ZERO, Vector2(10, 0), 10.0), "hit test includes boundary")
    _expect(not Rules.hit_test(Vector2.ZERO, Vector2(10.1, 0), 10.0), "hit test rejects outside boundary")
    _expect(Rules.normalize_aim(Vector2.ZERO) == Vector2.RIGHT, "zero aim has safe fallback")
    _expect(is_equal_approx(Rules.normalize_aim(Vector2(3, 4)).length(), 1.0), "aim direction is normalized")
    _expect(Rules.can_win(0.0, 1), "surviving until timer ends wins")
    _expect(not Rules.can_win(0.0, 0), "core failure cannot also win")
    _expect(Rules.score_for_kill() == 10, "kill score is deterministic")
    var exit_code := 0
    if failures.is_empty():
        print("KROLL Sentinel Protocol rules tests passed.")
    else:
        for failure in failures:
            push_error("FAIL: " + failure)
        exit_code = 1
    quit(exit_code)
func _expect(condition: bool, description: String) -> void:
    if condition:
        print("PASS: " + description)
    else:
        failures.append(description)
