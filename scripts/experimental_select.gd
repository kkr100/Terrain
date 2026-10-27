extends Control
## The map picker of Experimental mode: flip through the maps (see
## ExperimentalMaps), look at each poster, then go on to pick a car.
##
## You get here with the dev console command "dev".

## The poster pictures we made already, by map path, so flipping back is
## instant. "static" means it's kept even after you leave this screen.
static var _posters := {}

var _index := 0

@onready var _poster: TextureRect = $Poster
@onready var _name_label: Label = $Panel/Box/Picker/NameLabel
@onready var _count_label: Label = $Panel/Box/CountLabel
@onready var _region_label: Label = $Panel/Box/RegionLabel
@onready var _description_label: Label = $Panel/Box/DescriptionLabel
@onready var _found_label: Label = $Panel/Box/FoundLabel
@onready var _car_button: Button = $Panel/Box/CarButton


func _ready() -> void:
	$Panel/Box/Picker/PrevButton.pressed.connect(_change_map.bind(-1))
	$Panel/Box/Picker/NextButton.pressed.connect(_change_map.bind(1))
	_car_button.pressed.connect(_on_car_pressed)
	$Panel/Box/BackButton.pressed.connect(_on_back_pressed)
	# Left/Right should pick a map, not move the keyboard focus.
	_car_button.focus_neighbor_left = _car_button.get_path()
	_car_button.focus_neighbor_right = _car_button.get_path()
	_index = ExperimentalMaps.selected_index()
	_show_map()
	_car_button.grab_focus()


# The same keys and buttons as the level-select screen (see level_select.gd).
func _input(event: InputEvent) -> void:
	if event.is_action("steer_left") or event.is_action("steer_right"):
		if Input.is_action_just_pressed_by_event("steer_left", event):
			_change_map(-1)
		elif Input.is_action_just_pressed_by_event("steer_right", event):
			_change_map(1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_on_back_pressed()


func _change_map(step: int) -> void:
	_index = wrapi(_index + step, 0, ExperimentalMaps.MAPS.size())
	_show_map()


func _show_map() -> void:
	_count_label.text = "%d / %d" % [_index + 1, ExperimentalMaps.MAPS.size()]
	var map := ExperimentalMaps.load_map(_index)
	var section := ExperimentalMaps.save_section(map)
	if map == null:
		_name_label.text = ExperimentalMaps.EXPLORE_COPY_NAME
		_region_label.text = "The Explore map"
		_description_label.text = "A copy of the Explore map, for trying out changes to it."
		_poster.texture = null
	else:
		_name_label.text = map.display_name
		_region_label.text = map.region
		_description_label.text = map.description
		var path: String = ExperimentalMaps.MAPS[_index]
		if not _posters.has(path):
			_posters[path] = ImageTexture.create_from_image(map.poster)
		_poster.texture = _posters[path]

	var total := Exploration.total_count(section)
	if total > 0:
		_found_label.text = "Places found: %d / %d" % [Exploration.load_found(section).size(), total]
	else:
		_found_label.text = "Not driven yet"


func _on_car_pressed() -> void:
	ExperimentalMaps.select(_index)
	get_tree().change_scene_to_file("res://scenes/car_select.tscn")


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
