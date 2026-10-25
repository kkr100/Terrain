class_name CarChoice
## The list of cars you can pick, and which one you picked last time.
##
## To add a fourth car: make a new scene in scenes/cars/ (duplicate one of the
## others and change its numbers), then add an entry to CARS below.

## "stats" are 1 to 5 bars on the car-select screen. They're only for show:
## the real numbers are in each car's scene (select the root node and look in
## the Inspector).
const CARS := [
	{
		"id": "rally",
		"name": "Rally Hatch",
		"scene": "res://scenes/cars/rally.tscn",
		"description": "Light, nimble and fast on dry dirt. Small tyres and a high-revving little 4-cylinder. Keep it out of the mud!",
		"stats": {"Top speed": 5, "Acceleration": 5, "Handling": 5, "Mud": 1},
	},
	{
		"id": "suv",
		"name": "Trail SUV",
		"scene": "res://scenes/cars/suv.tscn",
		"description": "The all-rounder. A smooth 6-cylinder, chunky tyres and a soft suspension that soaks up the bumps.",
		"stats": {"Top speed": 3, "Acceleration": 3, "Handling": 3, "Mud": 3},
	},
	{
		"id": "pickup",
		"name": "Heavy Pickup",
		"scene": "res://scenes/cars/pickup.tscn",
		"description": "Big, heavy and slow to turn, with a rumbling V8. Huge tyres and long suspension plough straight through mud.",
		"stats": {"Top speed": 2, "Acceleration": 2, "Handling": 1, "Mud": 5},
	},
]

const SAVE_PATH := "user://save.cfg"


## The position in CARS of the car you picked last time (the first car if you
## haven't picked one yet).
static func selected_index() -> int:
	var file := ConfigFile.new()
	file.load(SAVE_PATH)
	var id: String = file.get_value("cars", "selected", CARS[0].id)
	for i in CARS.size():
		if CARS[i].id == id:
			return i
	return 0


## The picked car's entry from CARS (a Dictionary with id, name, scene, ...).
static func selected() -> Dictionary:
	return CARS[selected_index()]


static func select(index: int) -> void:
	var file := ConfigFile.new()
	file.load(SAVE_PATH)  # Keep anything else that's already saved, like best times.
	file.set_value("cars", "selected", CARS[index].id)
	file.save(SAVE_PATH)
