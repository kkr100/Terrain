class_name BestTime
## Saves and loads the fastest finish time for each level and car, so it's
## still there next time you play.
##
## "user://" is a folder Godot gives every game for its save files. On Windows
## it's in %APPDATA%\Godot\app_userdata\Terrain, on Linux in
## ~/.local/share/godot/app_userdata/Terrain. A ConfigFile is a simple text
## file with [sections] and key=value lines, much like project.godot.

const SAVE_PATH := "user://save.cfg"


## The best time in seconds on the level called level_id ("green_valley", ...)
## with the car called car_id ("rally", "suv", ...), or -1 if you haven't
## finished that level with that car yet.
static func read(level_id: String, car_id: String) -> float:
	var file := ConfigFile.new()
	if file.load(SAVE_PATH) != OK:
		return -1.0
	var best: float = file.get_value("best_times", _key(level_id, car_id), -1.0)
	# Before there were levels, best times were saved by car only, and they
	# were all on the map that is now the first level. Keep those.
	if best < 0.0 and level_id == LevelChoice.LEVELS[0].id:
		best = file.get_value("best_times", car_id, -1.0)
	return best


static func write(level_id: String, car_id: String, seconds: float) -> void:
	var file := ConfigFile.new()
	file.load(SAVE_PATH)  # Keep anything else that's already saved.
	file.set_value("best_times", _key(level_id, car_id), seconds)
	file.save(SAVE_PATH)


## Turns 83.25 seconds into "1:23.2".
static func format(seconds: float) -> String:
	var minutes := floori(seconds / 60.0)
	return "%d:%04.1f" % [minutes, seconds - minutes * 60.0]


# The name a time is saved under, like "green_valley/rally".
static func _key(level_id: String, car_id: String) -> String:
	return "%s/%s" % [level_id, car_id]
