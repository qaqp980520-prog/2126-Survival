extends SceneTree

const Rules = preload("res://rules.gd")

func _initialize() -> void:
	_run_tests()
	quit(0)

func _run_tests() -> void:
	var beds: Array[Dictionary] = Rules.create_beds()
	assert(beds.size() == 3)
	assert(is_equal_approx(float(beds[0]["moisture"]), 65.0))
	assert(Rules.water(beds[0]))
	assert(is_equal_approx(float(beds[0]["moisture"]), 93.0))
	assert(Rules.water(beds[0]))
	assert(is_equal_approx(float(beds[0]["moisture"]), 100.0), "Watering must clamp moisture at 100")
	assert(not Rules.water(beds[0]), "Watering a full bed must be a no-op")
	assert(not Rules.harvest(beds[0]), "Immature crops cannot be harvested")
	Rules.advance_bed(beds[0], 9.0)
	assert(float(beds[0]["growth"]) >= 100.0)
	assert(Rules.harvest(beds[0]))
	assert(int(beds[0]["harvests"]) == 1)
	assert(is_equal_approx(float(beds[0]["growth"]), 0.0))
	assert(is_equal_approx(float(beds[0]["moisture"]), Rules.REPLANT_MOISTURE))
	assert(Rules.total_harvests(beds) == 1)
	for index in range(9):
		var bed_index: int = index % beds.size()
		beds[bed_index]["harvests"] = int(beds[bed_index]["harvests"]) + 1
	assert(Rules.is_victory(beds))
	assert(Rules.is_timeout(0.0))
	var dry_bed: Dictionary = {"growth": 10.0, "moisture": 0.0, "harvests": 0}
	Rules.advance_bed(dry_bed, 2.0)
	assert(is_equal_approx(float(dry_bed["growth"]), 10.0), "Dry crops must stop growing")
	assert(is_equal_approx(float(dry_bed["moisture"]), 0.0))
	var thirsty_bed: Dictionary = {"growth": 0.0, "moisture": 15.0, "harvests": 0}
	Rules.advance_bed(thirsty_bed, 1.0)
	assert(is_equal_approx(float(thirsty_bed["growth"]), 12.0))
	assert(is_equal_approx(float(thirsty_bed["moisture"]), 8.0))
	Rules.advance_bed(thirsty_bed, 2.0)
	assert(is_equal_approx(float(thirsty_bed["growth"]), 12.0), "Growth must pause below the moisture threshold")
	assert(Rules.water(thirsty_bed))
	Rules.advance_bed(thirsty_bed, 1.0)
	assert(is_equal_approx(float(thirsty_bed["growth"]), 24.0), "Watering must resume growth")
	print("KROLL Hydroponics Shift rules tests passed.")
