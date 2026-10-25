extends CanvasLayer
## Press Esc during the race to pause the game and show this menu.
##
## get_tree().paused = true freezes every node whose "Process > Mode" is
## "Pausable" (the default): physics, the car, the race timer. This menu's
## mode is set to "Always" in pause_menu.tscn, so it keeps working while
## everything else is frozen. That's how it can notice Esc again to unpause.

@onready var _resume_button: Button = $Center/Panel/Box/ResumeButton


func _ready() -> void:
	hide()
	_resume_button.pressed.connect(_set_paused.bind(false))
	$Center/Panel/Box/RestartButton.pressed.connect(_on_restart_pressed)
	$Center/Panel/Box/MenuButton.pressed.connect(_on_menu_pressed)
	$Center/Panel/Box/QuitButton.pressed.connect(get_tree().quit)


# _unhandled_input gets key presses that no button or other UI used up.
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		_set_paused(not get_tree().paused)
		get_viewport().set_input_as_handled()


func _set_paused(paused: bool) -> void:
	get_tree().paused = paused
	visible = paused
	if paused:
		_resume_button.grab_focus()


func _on_restart_pressed() -> void:
	# Unpause first, or the new scene would start frozen.
	get_tree().paused = false
	get_tree().reload_current_scene()


func _on_menu_pressed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
