extends Control
## The car-select screen: flip through the cars, see (and hear) each one, then
## drive the one you like.
##
## The 3D car on the left lives in a SubViewport: a small separate 3D world
## drawn inside the menu, with its own light, floor and camera. We put the real
## car scene in there (with its controls turned off), so you see exactly the
## car you'll drive, and hear its engine idle.

## How fast the camera circles the car, in radians per second.
@export var orbit_speed := 0.35
## How far from the car the camera is, in metres.
@export var orbit_distance := 8.0

var _index := 0
var _car: Car
var _orbit_angle := 0.6

@onready var _car_spot: Node3D = $Preview/Viewport/CarSpot
@onready var _camera: Camera3D = $Preview/Viewport/Camera
@onready var _name_label: Label = $Panel/Box/Picker/NameLabel
@onready var _count_label: Label = $Panel/Box/CountLabel
@onready var _description_label: Label = $Panel/Box/DescriptionLabel
@onready var _stats: GridContainer = $Panel/Box/Stats
@onready var _best_label: Label = $Panel/Box/BestLabel
@onready var _drive_button: Button = $Panel/Box/DriveButton


func _ready() -> void:
	$Panel/Box/Picker/PrevButton.pressed.connect(_change_car.bind(-1))
	$Panel/Box/Picker/NextButton.pressed.connect(_change_car.bind(1))
	_drive_button.pressed.connect(_on_drive_pressed)
	$Panel/Box/BackButton.pressed.connect(_on_back_pressed)
	# Left/Right should pick a car, not move the keyboard focus off "Drive!".
	_drive_button.focus_neighbor_left = _drive_button.get_path()
	_drive_button.focus_neighbor_right = _drive_button.get_path()
	# The panel covers the right side of the screen, so shift the camera's
	# view to put the car in the middle of the part you can see.
	_camera.h_offset = 1.8
	_index = CarChoice.selected_index()
	_show_car()
	_drive_button.grab_focus()


func _process(delta: float) -> void:
	# Circle slowly around the car, always looking at it.
	_orbit_angle += orbit_speed * delta
	var offset := Vector3(sin(_orbit_angle), 0.0, cos(_orbit_angle)) * orbit_distance
	_camera.position = offset + Vector3.UP * 2.2
	_camera.look_at(Vector3.UP * 0.8)


# _input sees key presses before the buttons do.
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("steer_left"):
		_change_car(-1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("steer_right"):
		_change_car(1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"):
		_on_back_pressed()
		get_viewport().set_input_as_handled()


func _change_car(step: int) -> void:
	# wrapi wraps around: going right from the last car gives the first again.
	_index = wrapi(_index + step, 0, CarChoice.CARS.size())
	_show_car()


func _show_car() -> void:
	var info: Dictionary = CarChoice.CARS[_index]
	_name_label.text = info.name
	_count_label.text = "%d / %d" % [_index + 1, CarChoice.CARS.size()]
	_description_label.text = info.description
	var best := BestTime.read(info.id)
	_best_label.text = "Best time: %s" % BestTime.format(best) if best >= 0.0 else "No best time with this car yet"
	_show_stats(info.stats)

	# Swap the 3D car for the new one.
	if _car:
		_car.queue_free()
	_car = load(info.scene).instantiate()
	_car.controls_enabled = false
	_car_spot.add_child(_car)
	# Give it a little rev as it rolls in, so you hear its engine.
	_car.rpm = _car.redline_rpm * 0.8


## One row per stat: a name, then a bar from 1 to 5.
func _show_stats(stats: Dictionary) -> void:
	for child in _stats.get_children():
		child.queue_free()
	for stat_name in stats:
		var label := Label.new()
		label.text = stat_name
		label.add_theme_font_size_override("font_size", 18)
		_stats.add_child(label)
		var bar := ProgressBar.new()
		bar.max_value = 5
		bar.value = stats[stat_name]
		bar.show_percentage = false
		bar.custom_minimum_size = Vector2(220, 18)
		bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_stats.add_child(bar)


func _on_drive_pressed() -> void:
	CarChoice.select(_index)
	get_tree().change_scene_to_file("res://scenes/main.tscn")


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
