extends CanvasLayer
## A hidden developer console for testing. Press the key left of 1 (` on most
## keyboards, § on Nordic ones) on any screen to open or close it, type a
## command like "unlock_all" and press Enter. Type "help" to see them all.
##
## It's an "autoload": Project Settings > Globals lists it, so Godot creates it
## once when the game starts and keeps it alive across every scene change.
## That's why it works on every screen without being added to any scene.
## Other scripts can reach it by its autoload name, DevConsole.
##
## To add a command: write a function called _cmd_<name>, and add a line for it
## to COMMANDS so "help" lists it.

## Sent after a command changes which upgrades are unlocked, so a screen that
## shows them (like car select) can update itself.
signal unlocks_changed

## The commands "help" shows: name -> what it does.
const COMMANDS := {
	"help": "Lists the commands.",
	"unlock_all": "Unlocks every car upgrade, without finding the places.",
	"relock": "Undoes unlock_all. Places you really found keep their upgrades.",
	"upgrades": "Lists the upgrades and whether each one is unlocked.",
	"dev": "Opens Experimental mode: hidden test maps for Explore.",
	"clear": "Empties this console.",
}

var _output: RichTextLabel
var _line: LineEdit
## The commands you typed, so Up and Down can bring them back.
var _history: Array[String] = []
var _history_index := 0
## The game's pause state and keyboard focus from before we opened, so
## closing the console puts them back.
var _was_paused := false
var _old_focus: Control


func _ready() -> void:
	# Draw on top of everything, and keep working while the game is paused.
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	hide()
	_print("Dev console. Type [b]help[/b] for the commands.")


## Makes the panel in code, so there's no scene file to keep in sync.
func _build() -> void:
	var panel := PanelContainer.new()
	# Stretch across the top 40% of the screen.
	panel.anchor_right = 1.0
	panel.anchor_bottom = 0.4
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.06, 0.08, 0.92)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)

	var box := VBoxContainer.new()
	panel.add_child(box)

	_output = RichTextLabel.new()
	_output.bbcode_enabled = true
	_output.scroll_following = true  # Always show the newest line.
	_output.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_output.add_theme_font_size_override("normal_font_size", 16)
	_output.add_theme_font_size_override("bold_font_size", 16)
	box.add_child(_output)

	_line = LineEdit.new()
	_line.placeholder_text = "Type a command and press Enter (Esc closes)"
	_line.add_theme_font_size_override("font_size", 16)
	# Stay in the box after Enter, ready for the next command.
	_line.keep_editing_on_text_submit = true
	_line.text_submitted.connect(_on_submitted)
	box.add_child(_line)


# _input sees key presses before anything else, even the text box. That way
# the toggle key opens and closes the console instead of typing a "`".
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_console"):
		_set_open(not visible)
		get_viewport().set_input_as_handled()
	elif visible and event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_ESCAPE:
				_set_open(false)
				get_viewport().set_input_as_handled()
			KEY_UP:
				_browse_history(-1)
				get_viewport().set_input_as_handled()
			KEY_DOWN:
				_browse_history(1)
				get_viewport().set_input_as_handled()


func _set_open(open: bool) -> void:
	if open == visible:
		return
	visible = open
	if open:
		# Freeze the game while you type, so the car doesn't drive off when you
		# press W or A, and the race timer stops.
		_was_paused = get_tree().paused
		get_tree().paused = true
		_old_focus = get_viewport().gui_get_focus_owner()
		_line.clear()
		_line.grab_focus()
	else:
		get_tree().paused = _was_paused
		_line.release_focus()
		if is_instance_valid(_old_focus) and _old_focus.is_visible_in_tree():
			_old_focus.grab_focus()


func _on_submitted(text: String) -> void:
	_line.clear()
	text = text.strip_edges()
	if text == "":
		return
	_history.append(text)
	_history_index = _history.size()
	_print("> " + text)
	run(text)


## Runs one command, like "unlock_all". Other scripts (or tests) can call this
## too: DevConsole.run("unlock_all").
func run(text: String) -> void:
	var command := text.split(" ", false)[0].to_lower()
	if not COMMANDS.has(command):
		_print("[color=#ff8a70]Unknown command \"%s\". Type help for the list.[/color]" % command)
		return
	# Call the function _cmd_<command> on this node.
	call("_cmd_" + command)


func _cmd_help() -> void:
	for command: String in COMMANDS:
		_print("  [b]%s[/b]  %s" % [command, COMMANDS[command]])


func _cmd_unlock_all() -> void:
	Upgrades.set_unlock_all(true)
	_print("All %d upgrades unlocked. Fit them on the car-select screen." % Upgrades.PATHS.size())
	unlocks_changed.emit()


func _cmd_relock() -> void:
	Upgrades.set_unlock_all(false)
	_print("Upgrades relocked. %d / %d are unlocked from places you found."
			% [Upgrades.unlocked_count(), Upgrades.PATHS.size()])
	unlocks_changed.emit()


func _cmd_upgrades() -> void:
	for upgrade in Upgrades.all():
		var state := "[color=#8fe388]unlocked[/color]" if Upgrades.is_unlocked(upgrade) else "[color=#999999]locked[/color]"
		_print("  %s (%s): %s" % [upgrade.display_name, upgrade.slot, state])
	if Upgrades.unlock_all_on():
		_print("  (unlock_all is on)")


func _cmd_dev() -> void:
	_print("Opening Experimental mode. Pick a map and a car, then press Drive!")
	# Close the console first. That also unpauses the game, so the next screen
	# doesn't start frozen.
	_set_open(false)
	get_tree().paused = false
	GameMode.select("experimental")
	get_tree().change_scene_to_file(GameMode.selected().first_screen)


func _cmd_clear() -> void:
	_output.clear()


func _print(line: String) -> void:
	_output.append_text(line + "\n")


## Up = the command before, Down = the one after (or an empty box at the end).
func _browse_history(step: int) -> void:
	if _history.is_empty():
		return
	_history_index = clampi(_history_index + step, 0, _history.size())
	_line.text = _history[_history_index] if _history_index < _history.size() else ""
	_line.caret_column = _line.text.length()
