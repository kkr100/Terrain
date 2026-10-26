extends Control
## The level-select screen for point-to-point: flip through the levels, see a
## map of each one with its route, then go on to pick a car.
##
## To draw a level's map we load its scene, but we don't add it to the game:
## we only ask its Terrain for a small picture of the ground
## (Terrain.make_map_image) and read where its checkpoints are. That takes a
## moment, so it runs on a background thread (WorkerThreadPool), and the map
## says "Drawing the map..." until it's ready.

const DIFFICULTY_NAMES := ["", "Easy", "Medium", "Hard"]
const DIFFICULTY_COLORS := [Color.WHITE, Color(0.45, 1.0, 0.45), Color(1.0, 0.85, 0.3), Color(1.0, 0.45, 0.35)]

## Maps we have already drawn, by level id, so flipping back is instant.
## "static" means it's shared and kept even after you leave this screen.
static var _maps := {}

var _index := 0
# The background job drawing a map, and what it found out.
var _task_id := -1
var _task_level_id := ""
var _task_result := {}

@onready var _map: LevelMap = $Map
@onready var _name_label: Label = $Panel/Box/Picker/NameLabel
@onready var _count_label: Label = $Panel/Box/CountLabel
@onready var _difficulty_label: Label = $Panel/Box/DifficultyLabel
@onready var _description_label: Label = $Panel/Box/DescriptionLabel
@onready var _best_label: Label = $Panel/Box/BestLabel
@onready var _car_button: Button = $Panel/Box/CarButton


func _ready() -> void:
	$Panel/Box/Picker/PrevButton.pressed.connect(_change_level.bind(-1))
	$Panel/Box/Picker/NextButton.pressed.connect(_change_level.bind(1))
	_car_button.pressed.connect(_on_car_pressed)
	$Panel/Box/BackButton.pressed.connect(_on_back_pressed)
	# Left/Right should pick a level, not move the keyboard focus.
	_car_button.focus_neighbor_left = _car_button.get_path()
	_car_button.focus_neighbor_right = _car_button.get_path()
	_index = LevelChoice.selected_index()
	_show_level()
	_car_button.grab_focus()


func _exit_tree() -> void:
	# Don't leave a background job running when the screen closes.
	if _task_id >= 0:
		WorkerThreadPool.wait_for_task_completion(_task_id)
		_task_id = -1


func _process(_delta: float) -> void:
	if _task_id >= 0 and WorkerThreadPool.is_task_completed(_task_id):
		WorkerThreadPool.wait_for_task_completion(_task_id)
		_task_id = -1
		_maps[_task_level_id] = {
			"texture": ImageTexture.create_from_image(_task_result.image),
			"route": _task_result.route,
			"size": _task_result.size,
		}
		_show_level()


# _input sees key presses before the buttons do.
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("steer_left"):
		_change_level(-1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("steer_right"):
		_change_level(1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"):
		# Mark the key as used first: going back removes this screen from the
		# tree right away, and then get_viewport() would be null.
		get_viewport().set_input_as_handled()
		_on_back_pressed()


func _change_level(step: int) -> void:
	_index = wrapi(_index + step, 0, LevelChoice.LEVELS.size())
	_show_level()


func _show_level() -> void:
	var info: Dictionary = LevelChoice.LEVELS[_index]
	_name_label.text = info.name
	_count_label.text = "%d / %d" % [_index + 1, LevelChoice.LEVELS.size()]
	_difficulty_label.text = DIFFICULTY_NAMES[info.difficulty]
	_difficulty_label.modulate = DIFFICULTY_COLORS[info.difficulty]
	_description_label.text = info.description

	# Your best time on this level with each car.
	var lines := ["Best times:"]
	for car in CarChoice.CARS:
		var best := BestTime.read(info.id, car.id)
		lines.append("   %s:  %s" % [car.name, BestTime.format(best) if best >= 0.0 else "-"])
	_best_label.text = "\n".join(lines)

	if _maps.has(info.id):
		var map: Dictionary = _maps[info.id]
		_map.show_map(map.texture, map.route, map.size)
		# The route is the start, the checkpoints, then the finish.
		_difficulty_label.text += "   %d checkpoints" % (map.route.size() - 2)
	else:
		_map.show_map(null, PackedVector2Array(), 1)
		_start_drawing(info)


func _start_drawing(info: Dictionary) -> void:
	# One map at a time. When it's done, _show_level runs again and starts
	# the next one if you've flipped on in the meantime.
	if _task_id >= 0:
		return
	_task_level_id = info.id
	_task_id = WorkerThreadPool.add_task(_draw_map.bind(info.scene))


# Runs on a background thread. Nodes that aren't in the scene tree are safe
# to use there.
func _draw_map(scene_path: String) -> void:
	var level: Node = load(scene_path).instantiate()
	var terrain: Terrain = level.get_node("Terrain")
	# The route: the start (where the car is), then every checkpoint.
	var route := PackedVector2Array([Vector2.ZERO])
	for checkpoint: Node3D in level.get_node("Checkpoints").get_children():
		route.append(Vector2(checkpoint.position.x, checkpoint.position.z))
	_task_result = {"image": terrain.make_map_image(256), "route": route, "size": terrain.size}
	level.free()


func _on_car_pressed() -> void:
	LevelChoice.select(_index)
	get_tree().change_scene_to_file("res://scenes/car_select.tscn")


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
