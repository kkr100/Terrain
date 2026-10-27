extends CanvasLayer
## Everything drawn on top of the world in Explore mode: speed, how many
## places you've found, the compass, the "Discovered!" and "Upgrade
## unlocked!" messages and the map.

## The car whose speed we show. CarSpawner fills this in.
@export var car: Car
@export var exploration: Exploration
## How long each message stays, in seconds.
@export var message_time := 5.0

@onready var _speed_label: Label = $SpeedLabel
@onready var _found_label: Label = $FoundLabel
@onready var _message: Control = $Message
@onready var _message_title: Label = $Message/Panel/Box/Title
@onready var _message_name: Label = $Message/Panel/Box/Name
@onready var _message_text: Label = $Message/Panel/Box/Text
@onready var _map: Control = $Map
@onready var _chime: AudioStreamPlayer = $Chime

var _message_tween: Tween
# Messages waiting for their turn: each is [title, name, text].
var _message_queue: Array[Array] = []


func _ready() -> void:
	_message.hide()
	_map.hide()
	exploration.discovered.connect(_on_discovered)
	exploration.all_discovered.connect(_on_all_discovered)
	_chime.stream = _make_chime()
	_show_message("Explore!", "Find all %d places" % exploration.points.size(),
			"Follow the ? on the compass at the top. Press %s for the map." % Controls.button("map"))


func _process(_delta: float) -> void:
	var kmh := absf(car.get_forward_speed()) * 3.6
	var ground: String = car.surface_name if car.surface_name != "" else "In the air"
	var nitro := ""
	if car.boost_power > 0.0:
		nitro = "   nitro %d%% (%s)" % [roundi(car.nitro * 100.0), Controls.button("boost")]
	_speed_label.text = "%d km/h   gear %d   %d rpm   %s%s\n%s" % [roundi(kmh), car.gear,
			roundi(car.rpm / 100.0) * 100, ground, nitro, Controls.hint(true)]
	_found_label.text = "Places found: %d / %d" % [exploration.found.size(), exploration.points.size()]


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("map"):
		_map.visible = not _map.visible
		get_viewport().set_input_as_handled()
	elif _map.visible and event.is_action_pressed("ui_cancel"):
		# B / Circle on a controller closes the map too.
		_map.visible = false
		get_viewport().set_input_as_handled()


func _on_discovered(point: PointOfInterest) -> void:
	_chime.play()
	_show_message("Discovered!", point.display_name, point.description)
	# Every place has a car upgrade hidden there.
	var upgrade := Upgrades.unlocked_by_place(point.id)
	if upgrade:
		_show_message("Upgrade unlocked!", upgrade.display_name,
				"%s\nFit it to your car on the car-select screen (%s slot)." % [upgrade.description, upgrade.slot])


func _on_all_discovered() -> void:
	_show_message("You found them all!", "Well done, explorer!",
			"Keep driving around, or go back to the menu with Esc.")


## Shows a message in the box at the top. If another message is still
## showing, this one waits in the queue until that one is gone.
func _show_message(title: String, place_name: String, text: String) -> void:
	_message_queue.append([title, place_name, text])
	if _message_queue.size() == 1:
		_show_next_message()


func _show_next_message() -> void:
	var title: String = _message_queue[0][0]
	var place_name: String = _message_queue[0][1]
	var text: String = _message_queue[0][2]
	_message_title.text = title
	_message_name.text = place_name
	_message_text.text = text
	_message.show()
	_message.modulate.a = 1.0
	# A Tween changes a value over time: wait, then fade the message out.
	_message_tween = create_tween()
	_message_tween.tween_interval(message_time)
	_message_tween.tween_property(_message, "modulate:a", 0.0, 0.8)
	_message_tween.tween_callback(_on_message_done)


func _on_message_done() -> void:
	_message.hide()
	_message_queue.pop_front()
	if not _message_queue.is_empty():
		_show_next_message()


# Makes a short "ding-ding-ding" sound in code, so we
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
