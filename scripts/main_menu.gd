extends Control
## The first screen you see: start the game, or quit.

@onready var _start_button: Button = $Center/Box/StartButton
@onready var _best_label: Label = $Center/Box/BestLabel


func _ready() -> void:
	_start_button.pressed.connect(_on_start_pressed)
	$Center/Box/QuitButton.pressed.connect(get_tree().quit)
	var car: Dictionary = CarChoice.selected()
	var best := BestTime.read(car.id)
	_best_label.text = "Best time (%s): %s" % [car.name, BestTime.format(best)] if best >= 0.0 else "No best time yet"
	# Focus Start so you can just press Enter (or use the arrow keys).
	_start_button.grab_focus()


func _on_start_pressed() -> void:
	# Swap this whole menu scene for the car-select screen.
	get_tree().change_scene_to_file("res://scenes/car_select.tscn")
