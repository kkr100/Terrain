class_name GameMode
## The ways you can play, and which one you picked last time.
##
## The main menu has a button for each mode. Picking one saves it here, then
## the car-select screen opens, and "Drive!" loads that mode's scene.

const MODES := [
	{
		"id": "point_to_point",
		"name": "Point to point",
		"scene": "res://scenes/main.tscn",
		"description": "Race through every checkpoint, in order, as fast as you can.",
	},
	{
		"id": "explore",
		"name": "Explore",
		"scene": "res://scenes/explore.tscn",
		"description": "Roam a huge map, ten times wider than the race map, and find all the hidden places.",
	},
]

const SAVE_PATH := "user://save.cfg"


## The picked mode's entry from MODES (a Dictionary with id, name, scene, ...).
static func selected() -> Dictionary:
	var file := ConfigFile.new()
	file.load(SAVE_PATH)
	var id: String = file.get_value("mode", "selected", MODES[0].id)
	for mode in MODES:
		if mode.id == id:
			return mode
	return MODES[0]


static func select(id: String) -> void:
	var file := ConfigFile.new()
	file.load(SAVE_PATH)  # Keep anything else that's already saved, like best times.
	file.set_value("mode", "selected", id)
	file.save(SAVE_PATH)
