extends CanvasLayer
## Everything drawn on top of the 3D world: speed, race info, the countdown
## and the finish screen.

## The car whose speed we show. Set this in the Inspector.
@export var car: VehicleBody3D
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
@onready var _menu_button: Button = $FinishScreen/Panel/Box/MenuButton


func _ready() -> void:
	_finish_screen.hide()
	race.finished.connect(_on_race_finished)
	_restart_button.pressed.connect(_on_restart_pressed)
	_menu_button.pressed.connect(_on_menu_pressed)


func _process(_delta: float) -> void:
	# linear_velocity is in metres per second. Multiply by 3.6 for km/h.
	var kmh := absf(car.get_forward_speed()) * 3.6
	var ground: String = car.surface_name if car.surface_name != "" else "In the air"
	_speed_label.text = "%d km/h   %s\n%s" % [roundi(kmh), ground, CONTROLS]

	var total := race.checkpoints.size()
	if race.is_finished:
		_race_label.text = "Finished!"
	elif race.next_index == total - 1:
		_race_label.text = "Finish line   %d m\n%s" % [roundi(race.distance_to_next()), BestTime.format(race.elapsed)]
	else:
		_race_label.text = "Checkpoint %d / %d   %d m\n%s" % [race.next_index + 1, total - 1,
				roundi(race.distance_to_next()), BestTime.format(race.elapsed)]

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
	_finish_screen.show()
	# Focus the button so Enter or a gamepad can press it without the mouse.
	_restart_button.grab_focus()


func _on_restart_pressed() -> void:
	get_tree().reload_current_scene()


func _on_menu_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
