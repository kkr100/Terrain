class_name LevelChoice
## The list of point-to-point levels, and which one you picked last time.
##
## Every level is its own scene in scenes/levels/. They all "inherit" from
## scenes/race_base.tscn, which has everything a race needs (the sun, the
## terrain, the car, the camera, the HUD, ...). A level scene only changes what
## makes it different: the terrain settings, the sky and the checkpoints.
##
## To add a fourth level: in the FileSystem panel, right-click
## scenes/race_base.tscn and pick "New Inherited Scene". Change the Terrain's
## settings, add Checkpoint scenes under "Checkpoints", set the Race node's
## "Level Id", save it in scenes/levels/, then add an entry to LEVELS below.

## "difficulty" is 1 to 3 stars on the level-select screen.
const LEVELS := [
	{
		"id": "green_valley",
		"name": "Green Valley",
		"scene": "res://scenes/levels/green_valley.tscn",
		"difficulty": 1,
		"description": "Rolling green hills with a few muddy puddles. A friendly loop to learn the cars.",
	},
	{
		"id": "mud_marsh",
		"name": "Mud Marsh",
		"scene": "res://scenes/levels/mud_marsh.tscn",
		"difficulty": 2,
		"description": "Low, soggy land on a grey day. Half of it is deep mud: find the dry paths, or take the pickup and plough straight through.",
	},
	{
		"id": "rocky_ridge",
		"name": "Rocky Ridge",
		"scene": "res://scenes/levels/rocky_ridge.tscn",
		"difficulty": 3,
		"description": "Steep hills and rocky ridges at sunset. Eleven checkpoints, up and over the tops. Don't roll it!",
	},
]

const SAVE_PATH := "user://save.cfg"


## The position in LEVELS of the level you picked last time (the first level
## if you haven't picked one yet).
static func selected_index() -> int:
	var file := ConfigFile.new()
	file.load(SAVE_PATH)
	return index_of(file.get_value("levels", "selected", LEVELS[0].id))


## The picked level's entry from LEVELS (a Dictionary with id, name, scene, ...).
static func selected() -> Dictionary:
	return LEVELS[selected_index()]


static func select(index: int) -> void:
	var file := ConfigFile.new()
	file.load(SAVE_PATH)  # Keep anything else that's already saved, like best times.
	file.set_value("levels", "selected", LEVELS[index].id)
	file.save(SAVE_PATH)


## The position in LEVELS of the level called id (0 if there's no such level).
static func index_of(id: String) -> int:
	for i in LEVELS.size():
		if LEVELS[i].id == id:
			return i
	return 0
