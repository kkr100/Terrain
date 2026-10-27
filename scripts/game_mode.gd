class_name GameMode
## The ways you can play, and which one you picked last time.
##
## The main menu has a button for each mode (except hidden ones). Picking one saves it here and
## opens the mode's first screen: the level select for point to point, the
## car select for Explore. "Drive!" on the car-select screen then loads the
## scene to play (scene_to_play below).

const MODES := [
	{
		"id": "point_to_point",
		"name": "Point to point",
		"first_screen": "res://scenes/level_select.tscn",
		# No "scene": each level has its own (see LevelChoice).
		"description": "Race through every checkpoint, in order, as fast as you can.",
	},
	{
		"id": "explore",
		"name": "Explore",
		"first_screen": "res://scenes/car_select.tscn",
		"scene": "res://scenes/explore.tscn",
		"description": "Roam a huge map, ten times wider than the race map, and find all the hidden places.",
	},
	{
		# A hidden test copy of Explore, for trying out new maps. It has no
		# button on the main menu: type "dev" in the dev console to open it.
		# It saves the places you find in its own "experimental" section, so it
		# never changes your Explore progress or unlocks upgrades.
		"id": "experimental",
		"name": "Experimental",
		"first_screen": "res://scenes/car_select.tscn",
		"scene": "res://scenes/experimental.tscn",
		"hidden": true,
		"description": "A test copy of Explore for trying out new maps.",
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


## The scene to load when you press "Drive!": the picked level in point to
## point, the big map in Explore.
static func scene_to_play() -> String:
	var mode := selected()
	if mode.id == "point_to_point":
		return LevelChoice.selected().scene
	return mode.scene


static func select(id: String) -> void:
	var file := ConfigFile.new()
	file.load(SAVE_PATH)  # Keep anything else that's already saved, like best times.
	file.set_value("mode", "selected", id)
	file.save(SAVE_PATH)
