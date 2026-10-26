extends Control
## The car-select screen: flip through the cars, see (and hear) each one, fit
## the upgrades you unlocked in Explore mode, then drive the one you like.
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
@onready var _upgrades_title: Label = $Panel/Box/UpgradesTitle
@onready var _upgrades_grid: GridContainer = $Panel/Box/Upgrades
@onready var _upgrade_info: Label = $Panel/Box/UpgradeInfo
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
	$Title.text = "Choose your car: %s" % _title()
	_index = CarChoice.selected_index()
	_make_upgrade_pickers()
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
	if GameMode.selected().id == "point_to_point":
		var best := BestTime.read(LevelChoice.selected().id, info.id)
		_best_label.text = "Best time: %s" % BestTime.format(best) if best >= 0.0 else "No best time with this car yet"
	else:
		_best_label.text = ""
	# No best times in Explore mode, so hide the label to save space.
	_best_label.visible = _best_label.text != ""
	_show_upgrades()
	_show_stats(info.stats)
	_show_preview()


## Puts the picked car, with its upgrades, on the stage.
func _show_preview() -> void:
	var info: Dictionary = CarChoice.CARS[_index]
	# Swap the 3D car for the new one.
	if _car:
		_car.queue_free()
	_car = load(info.scene).instantiate()
	_car.controls_enabled = false
	_car.upgrades = Upgrades.fitted(info.id)
	_car_spot.add_child(_car)
	# Give it a little rev as it rolls in, so you hear its engine.
	_car.rpm = _car.redline_rpm * 0.8


## One row per stat: a name, a bar from 1 to 5, and how much the fitted
## upgrades change it ("+1" in green, "-1" in red).
func _show_stats(stats: Dictionary) -> void:
	for child in _stats.get_children():
		child.queue_free()
	var bonus := {}
	for upgrade in Upgrades.fitted(CarChoice.CARS[_index].id):
		for stat_name in upgrade.stat_bonus:
			bonus[stat_name] = bonus.get(stat_name, 0) + upgrade.stat_bonus[stat_name]
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
		var change: int = bonus.get(stat_name, 0)
		var change_label := Label.new()
		change_label.custom_minimum_size = Vector2(28, 0)
		change_label.add_theme_font_size_override("font_size", 18)
		if change > 0:
			change_label.text = "+%d" % change
			change_label.modulate = Color(0.5, 1.0, 0.45)
		elif change < 0:
			change_label.text = str(change)
			change_label.modulate = Color(1.0, 0.5, 0.4)
		_stats.add_child(change_label)


## Makes one row per slot (Engine, Tyres, ...): its name and a drop-down list
## (an OptionButton) of the upgrades for that slot. Locked ones are greyed out.
func _make_upgrade_pickers() -> void:
	for slot: String in Upgrades.SLOTS:
		var label := Label.new()
		label.text = slot
		label.add_theme_font_size_override("font_size", 18)
		_upgrades_grid.add_child(label)
		var picker := OptionButton.new()
		picker.name = slot
		picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		picker.add_theme_font_size_override("font_size", 16)
		picker.get_popup().add_theme_font_size_override("font_size", 16)
		picker.add_item("Stock")
		for upgrade in Upgrades.in_slot(slot):
			if Upgrades.is_unlocked(upgrade):
				picker.add_item(upgrade.display_name)
			else:
				picker.add_item("Locked: explore to find it")
				picker.set_item_disabled(picker.item_count - 1, true)
			# Each item remembers its upgrade, so we know what was picked.
			picker.set_item_metadata(picker.item_count - 1, upgrade)
		picker.item_selected.connect(_on_upgrade_picked.bind(picker))
		# Show what an upgrade does while you hover over it in the list.
		picker.get_popup().id_focused.connect(_on_upgrade_hovered.bind(picker))
		_upgrades_grid.add_child(picker)
	_upgrades_title.text = "Upgrades: %d / %d unlocked" % [Upgrades.unlocked_count(), Upgrades.PATHS.size()]


## Sets each slot's drop-down to the upgrade fitted to this car.
func _show_upgrades() -> void:
	var fitted := Upgrades.fitted(CarChoice.CARS[_index].id)
	for slot: String in Upgrades.SLOTS:
		var picker: OptionButton = _upgrades_grid.get_node(slot)
		picker.select(0)  # Stock
		for i in picker.item_count:
			if picker.get_item_metadata(i) in fitted:
				picker.select(i)
	if Upgrades.unlocked_count() == 0:
		_upgrade_info.text = "Find places in Explore mode to unlock upgrades."
	else:
		_upgrade_info.text = "Each car keeps its own upgrades."


func _on_upgrade_picked(item: int, picker: OptionButton) -> void:
	var upgrade: CarUpgrade = picker.get_item_metadata(item)
	Upgrades.fit(CarChoice.CARS[_index].id, picker.name, upgrade)
	_show_stats(CarChoice.CARS[_index].stats)
	_show_preview()
	_upgrade_info.text = upgrade.description if upgrade else "The car's own %s." % String(picker.name).to_lower()


func _on_upgrade_hovered(item: int, picker: OptionButton) -> void:
	var upgrade: CarUpgrade = picker.get_item_metadata(item)
	if upgrade and Upgrades.is_unlocked(upgrade):
		_upgrade_info.text = upgrade.description


func _on_drive_pressed() -> void:
	CarChoice.select(_index)
	# Load the level (or the Explore map) you picked before.
	get_tree().change_scene_to_file(GameMode.scene_to_play())


func _on_back_pressed() -> void:
	# Back to the screen before this one.
	if GameMode.selected().id == "point_to_point":
		get_tree().change_scene_to_file("res://scenes/level_select.tscn")
	else:
		get_tree().change_scene_to_file("res://scenes/main_menu.tscn")


# "Point to point: Green Valley", or just "Explore".
func _title() -> String:
	var mode := GameMode.selected()
	if mode.id == "point_to_point":
		return "%s, %s" % [mode.name, LevelChoice.selected().name]
	return mode.name
