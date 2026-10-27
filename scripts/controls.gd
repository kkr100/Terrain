extends Node
## Knows whether you're playing with the keyboard or a game controller (an
## Xbox, PlayStation or similar gamepad), so the HUD can show the right
## buttons. Press a key and the hints show keys; press a controller button
## and they show that controller's buttons.
##
## The controls themselves don't live here: they're the actions in
## Project > Project Settings > Input Map. Each action (like "accelerate")
## lists every key and controller button that does it, so car.gd just asks
## Input about "accelerate" and doesn't care which one you used.
##
## Godot calls controllers "joypads". It knows the button layout of almost
## every controller, and always reports them by their position on an Xbox pad:
## the bottom face button is "A" (Cross on a PlayStation pad), the right one
## is "B" (Circle), and so on. That's why one set of actions works for both.
##
## It's an autoload, like DevConsole, so any script can ask
## Controls.using_gamepad or Controls.button("map").

## Names of the buttons for each action, as printed on each kind of
## controller (and the keyboard).
const KEYBOARD := {
	"drive": "W / Up", "brake": "S / Down", "steer": "A D / Left Right",
	"handbrake": "Space", "flip": "R", "boost": "Shift", "map": "M",
	"pause": "Esc or P", "back": "Esc",
}
const XBOX := {
	"drive": "RT", "brake": "LT", "steer": "Left stick", "look": "Right stick",
	"handbrake": "A", "flip": "Y", "boost": "X or RB", "map": "View",
	"pause": "Menu", "back": "B",
}
const PLAYSTATION := {
	"drive": "R2", "brake": "L2", "steer": "Left stick", "look": "Right stick",
	"handbrake": "Cross", "flip": "Triangle", "boost": "Square or R1",
	"map": "Create", "pause": "Options", "back": "Circle",
}

## True when the last thing you pressed was on a controller.
var using_gamepad := false
## True when that controller is a PlayStation one, so we say "Cross", not "A".
var is_playstation := false


func _ready() -> void:
	# Keep listening while the game is paused, so the pause menu knows too.
	process_mode = Node.PROCESS_MODE_ALWAYS
	Input.joy_connection_changed.connect(_on_joy_connection_changed)


func _input(event: InputEvent) -> void:
	# A stick that's only resting a little off-centre sends small values all
	# the time, so only a real push (past halfway) counts.
	if event is InputEventJoypadButton or (event is InputEventJoypadMotion
			and absf(event.axis_value) > 0.5):
		using_gamepad = true
		is_playstation = _is_playstation(event.device)
	elif event is InputEventKey:
		using_gamepad = false


## What to press for an action, like "map", on the device you're using now:
## "M", "View" or "Create".
func button(action: String) -> String:
	var names: Dictionary = KEYBOARD
	if using_gamepad:
		names = PLAYSTATION if is_playstation else XBOX
	return names.get(action, "")


## The two lines of controls the HUD shows under the speed. Explore mode
## also has the map.
func hint(with_map := false) -> String:
	var text := "%s: drive   %s: brake, reverse   %s: steer" % [button("drive"), button("brake"), button("steer")]
	if using_gamepad:
		text += "   %s: look around" % button("look")
	text += "\n%s: handbrake   %s: flip the car back up   " % [button("handbrake"), button("flip")]
	if with_map:
		text += "%s: map   " % button("map")
	return text + "%s: pause" % button("pause")


func _is_playstation(device: int) -> bool:
	var joy_name := Input.get_joy_name(device).to_lower()
	for word in ["playstation", "dualsense", "dualshock", "ps3", "ps4", "ps5"]:
		if word in joy_name:
			return true
	return false


func _on_joy_connection_changed(device: int, connected: bool) -> void:
	if connected:
		print("Controller connected: %s" % Input.get_joy_name(device))
	else:
		# Unplugged: go back to showing the keys.
		print("Controller %d disconnected" % device)
		using_gamepad = false
