extends CanvasLayer
## Everything drawn on top of the world in Explore mode: speed, how many
## places you've found, the compass, the "Discovered!" message and the map.

## The car whose speed we show. CarSpawner fills this in.
@export var car: Car
@export var exploration: Exploration
## How long the "Discovered!" message stays, in seconds.
@export var message_time := 5.0

const CONTROLS := "W / Up: drive   S / Down: brake, reverse   A D / Left Right: steer\nSpace: handbrake   R: flip the car back up   M: map   Esc or P: pause"

@onready var _speed_label: Label = $SpeedLabel
@onready var _found_label: Label = $FoundLabel
@onready var _message: Control = $Message
@onready var _message_title: Label = $Message/Panel/Box/Title
@onready var _message_name: Label = $Message/Panel/Box/Name
@onready var _message_text: Label = $Message/Panel/Box/Text
@onready var _map: Control = $Map
@onready var _chime: AudioStreamPlayer = $Chime

var _message_tween: Tween


func _ready() -> void:
	_message.hide()
	_map.hide()
	exploration.discovered.connect(_on_discovered)
	exploration.all_discovered.connect(_on_all_discovered)
	_chime.stream = _make_chime()
	_show_message("Explore!", "Find all %d places" % exploration.points.size(),
			"Follow the ? on the compass at the top. Press M for the map.")


func _process(_delta: float) -> void:
	var kmh := absf(car.get_forward_speed()) * 3.6
	var ground: String = car.surface_name if car.surface_name != "" else "In the air"
	_speed_label.text = "%d km/h   gear %d   %d rpm   %s\n%s" % [roundi(kmh), car.gear,
			roundi(car.rpm / 100.0) * 100, ground, CONTROLS]
	_found_label.text = "Places found: %d / %d" % [exploration.found.size(), exploration.points.size()]


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("map"):
		_map.visible = not _map.visible
		get_viewport().set_input_as_handled()


func _on_discovered(point: PointOfInterest) -> void:
	_chime.play()
	_show_message("Discovered!", point.display_name, point.description)


func _on_all_discovered() -> void:
	# Wait until the last "Discovered!" message is gone.
	await get_tree().create_timer(message_time).timeout
	_show_message("You found them all!", "Well done, explorer!",
			"Keep driving around, or go back to the menu with Esc.")


func _show_message(title: String, place_name: String, text: String) -> void:
	_message_title.text = title
	_message_name.text = place_name
	_message_text.text = text
	_message.show()
	_message.modulate.a = 1.0
	# A Tween changes a value over time: wait, then fade the message out.
	if _message_tween:
		_message_tween.kill()
	_message_tween = create_tween()
	_message_tween.tween_interval(message_time)
	_message_tween.tween_property(_message, "modulate:a", 0.0, 0.8)
	_message_tween.tween_callback(_message.hide)


# Makes a short "ding-ding-ding" sound in code (like the engine sound), so we
# don't need a sound file: three notes going up, each fading out.
func _make_chime() -> AudioStreamWAV:
	var rate := 22050
	var notes := [523.25, 659.25, 783.99]  # C, E and G: a happy chord.
	var note_length := 0.12
	var total := note_length * notes.size() + 0.5
	var data := PackedByteArray()
	data.resize(int(total * rate) * 2)
	for i in int(total * rate):
		var t := float(i) / rate
		var sample := 0.0
		for n in notes.size():
			var start: float = n * note_length
			if t >= start:
				var age: float = t - start
				sample += sin(TAU * notes[n] * age) * exp(-age * 6.0) * 0.25
		data.encode_s16(i * 2, int(clampf(sample, -1.0, 1.0) * 32767.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = rate
	stream.data = data
	return stream
