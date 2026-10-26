extends CanvasLayer
## Everything drawn on top of the 3D world: speed, race info, the countdown
## and the finish screen.

## The car whose speed we show. CarSpawner fills this in.
@export var car: Car
## The race whose time and checkpoints we show.
@export var race: Race

const CONTROLS := "W / Up: drive   S / Down: brake, reverse   A D / Left Right: steer\nSpace: handbrake   R: flip the car back up   Esc or P: pause"

# "@onready" fills these in just before _ready runs, when the child nodes exist.
# "$Name" is short for get_node("Name").
@onready var _speed_label: Label = $SpeedLabel
@onready var _race_label: Label = $RaceLabel
@onready var _countdown_label: Label = $CountdownLabel
@onready var _finish_screen: Control = $FinishScreen
@onready var _result_label: Label = $FinishScreen/Panel/Box/ResultLabel
@onready var _restart_button: Button = $FinishScreen/Panel/Box/RestartButton
@onready var _next_button: Button = $FinishScreen/Panel/Box/NextButton
@onready var _menu_button: Button = $FinishScreen/Panel/Box/MenuButton


func _ready() -> void:
	_finish_screen.hide()
	race.finished.connect(_on_race_finished)
	_restart_button.pressed.connect(_on_restart_pressed)
	_next_button.pressed.connect(_on_next_pressed)
	_menu_button.pressed.connect(_on_menu_pressed)


func _process(_delta: float) -> void:
	# linear_velocity is in metres per second. Multiply by 3.6 for km/h.
	var kmh := absf(car.get_forward_speed()) * 3.6
	var ground: String = car.surface_name if car.surface_name != "" else "In the air"
	var nitro := ""
	if car.boost_power > 0.0:
		nitro = "   nitro %d%% (Shift)" % roundi(car.nitro * 100.0)
	_speed_label.text = "%d km/h   gear %d   %d rpm   %s%s\n%s" % [roundi(kmh), car.gear,
			roundi(car.rpm / 100.0) * 100, ground, nitro, CONTROLS]

	var total := race.checkpoints.size()
	var text: String = race.level().name + "\n"
	if race.is_finished:
		text += "Finished!"
	elif race.next_index == total - 1:
		text += "Finish line   %d m\n%s" % [roundi(race.distance_to_next()), BestTime.format(race.elapsed)]
	else:
		text += "Checkpoint %d / %d   %d m\n%s" % [race.next_index + 1, total - 1,
				roundi(race.distance_to_next()), BestTime.format(race.elapsed)]
	_race_label.text = text

	# Show "3", "2", "1", then "GO!" for one second after the start.
	if race.countdown > 0.0:
		_countdown_label.text = str(ceili(race.countdown))
	elif race.countdown > -1.0 and not race.is_finished:
		_countdown_label.text = "GO!"
	else:
		_countdown_label.text = ""


func _on_race_finished(time: float, best_time: float, is_new_best: bool) -> void:
	var text := "Your time: %s\n" % BestTime.format(time)
	if is_new_best:
		text += "New best time!"
	else:
		text += "Best time: %s" % BestTime.format(best_time)
	_result_label.text = text
	# Offer the next level, unless this was the last one.
	var next := LevelChoice.index_of(race.level_id) + 1
	_next_button.visible = next < LevelChoice.LEVELS.size()
	if _next_button.visible:
		_next_button.text = "Next level: %s" % LevelChoice.LEVELS[next].name
	_finish_screen.show()
	# Focus the button so Enter or a gamepad can press it without the mouse.
	_restart_button.grab_focus()


func _on_restart_pressed() -> void:
	get_tree().reload_current_scene()


func _on_next_pressed() -> void:
	var next := LevelChoice.index_of(race.level_id) + 1
	LevelChoice.select(next)
	get_tree().change_scene_to_file(LevelChoice.LEVELS[next].scene)


func _on_menu_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
