class_name BestTime
## Saves and loads the fastest finish time, so it's still there next time you play.
##
## "user://" is a folder Godot gives every game for its save files. On Windows
## it's in %APPDATA%\Godot\app_userdata\Terrain, on Linux in
## ~/.local/share/godot/app_userdata/Terrain. A ConfigFile is a simple text
## file with [sections] and key=value lines, much like project.godot.

const SAVE_PATH := "user://save.cfg"


## The best time in seconds, or -1 if you haven't finished yet.
static func read() -> float:
	var file := ConfigFile.new()
	if file.load(SAVE_PATH) != OK:
		return -1.0
	return file.get_value("race", "best_time", -1.0)


static func write(seconds: float) -> void:
	var file := ConfigFile.new()
	file.load(SAVE_PATH)  # Keep anything else that's already saved.
	file.set_value("race", "best_time", seconds)
	file.save(SAVE_PATH)


## Turns 83.25 seconds into "1:23.2".
static func format(seconds: float) -> String:
	var minutes := floori(seconds / 60.0)
	return "%d:%04.1f" % [minutes, seconds - minutes * 60.0]
