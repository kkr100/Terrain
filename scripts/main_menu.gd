extends Control
## The first screen you see: pick a mode (which then takes you to the
## level-select or car-select screen), or quit.

@onready var _race_button: Button = $Center/Box/RaceButton
@onready var _explore_button: Button = $Center/Box/ExploreButton
@onready var _best_label: Label = $Center/Box/BestLabel
@onready var _mode_label: Label = $Center/Box/ModeLabel


func _ready() -> void:
	_race_button.pressed.connect(_on_mode_pressed.bind("point_to_point"))
	_explore_button.pressed.connect(_on_mode_pressed.bind("explore"))
	$Center/Box/QuitButton.pressed.connect(get_tree().quit)
	# Show what each mode is about while its button is focused or hovered.
	for button: Button in [_race_button, _explore_button]:
		button.focus_entered.connect(_show_mode_info.bind(button))
		button.mouse_entered.connect(button.grab_focus)

	_show_progress()
	# The dev console (the ` key) can unlock upgrades while you're here.
	DevConsole.unlocks_changed.connect(_show_progress)

	# Focus the mode you played last time, so you can just press Enter.
	if GameMode.selected().id == "explore":
		_explore_button.grab_focus()
	else:
		_race_button.grab_focus()


## Your best time, and how many places and upgrades you've found.
func _show_progress() -> void:
	var car: Dictionary = CarChoice.selected()
	var level: Dictionary = LevelChoice.selected()
	var best := BestTime.read(level.id, car.id)
	var lines := []
	if best >= 0.0:
		lines.append("Best time (%s, %s): %s" % [level.name, car.name, BestTime.format(best)])
	else:
		lines.append("No best time yet")
	var total := Exploration.total_count()
	if total > 0:
		lines.append("Places found: %d / %d   Upgrades unlocked: %d / %d" % [Exploration.load_found().size(),
				total, Upgrades.unlocked_count(), Upgrades.PATHS.size()])
	_best_label.text = "\n".join(lines)


func _show_mode_info(button: Button) -> void:
	var id := "explore" if button == _explore_button else "point_to_point"
	for mode in GameMode.MODES:
		if mode.id == id:
			_mode_label.text = mode.description


func _on_mode_pressed(id: String) -> void:
	GameMode.select(id)
	# Swap this whole menu scene for the mode's first screen.
	for mode in GameMode.MODES:
		if mode.id == id:
			get_tree().change_scene_to_file(mode.first_screen)
