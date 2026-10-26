extends Node
## The engine noise, made from real engine recordings.
##
## The sounds/engines/ folder has short recordings ("loops") of each engine
## running at one steady RPM: one at idle, a few in the middle, one near the
## redline. Each loop is cut so its end flows straight into its start, so it
## can play over and over without a gap.
##
## While you drive, we play the two loops closest to the engine's RPM at the
## same time and blend between them, like a DJ crossfading two records. Each
## one is also sped up or slowed down a little (pitch_scale) so it matches the
## RPM exactly: 2400 RPM with a loop recorded at 2000 RPM plays it 1.2 times
## faster.
##
## With your foot off the pedal the engine isn't working hard, so it sounds
## quieter and more muffled. We do the muffling with a low-pass filter, an
## audio effect that turns down the high, sharp parts of a sound.
##
## Put this node inside a car. It reads the car's rpm, throttle and gear.

## The loops, from the lowest RPM to the highest.
@export var loops: Array[AudioStream] = []
## The RPM each loop was recorded at, in the same order as the loops.
@export var loop_rpms: PackedFloat32Array = []
## Overall loudness in decibels. 0 = as recorded, -6 = about half as loud.
@export var volume_db := 0.0
## How muffled the engine sounds with your foot off the pedal, in Hz. Lower is
## more muffled.
@export var coasting_cutoff_hz := 900.0

## How long the throttle is cut while the gearbox changes up, in seconds.
const SHIFT_TIME := 0.15

var _car: Node
var _players: Array[AudioStreamPlayer] = []
# Our own audio bus: a channel on the mixing desk (see the Audio tab at the
# bottom of the editor) with the low-pass filter on it.
var _bus_name := ""
var _filter: AudioEffectLowPassFilter
# How hard the engine works, 0 to 1. Follows the throttle, but smoothly.
var _load := 0.0
var _last_gear := 1
var _shift_timer := 0.0


func _ready() -> void:
	_car = get_parent()
	_last_gear = _car.gear
	_make_bus()
	for stream in loops:
		var player := AudioStreamPlayer.new()
		player.stream = stream
		player.bus = _bus_name
		player.volume_db = -80.0
		add_child(player)
		# Every loop plays all the time. The ones we don't need are silent.
		player.play()
		_players.append(player)


func _exit_tree() -> void:
	# Tidy up: stop the loops and take our bus off the mixing desk again.
	for player in _players:
		player.stop()
	var index := AudioServer.get_bus_index(_bus_name)
	if index != -1:
		AudioServer.remove_bus(index)


func _make_bus() -> void:
	# Every engine gets its own bus, so muffling one car doesn't muffle
	# anything else.
	_bus_name = "Engine%d" % get_instance_id()
	var index := AudioServer.bus_count
	AudioServer.add_bus(index)
	AudioServer.set_bus_name(index, _bus_name)
	AudioServer.set_bus_send(index, "Master")
	_filter = AudioEffectLowPassFilter.new()
	AudioServer.add_bus_effect(index, _filter)


func _process(delta: float) -> void:
	if _players.is_empty():
		return
	var rpm: float = _car.rpm

	# Changing up a gear: let go of the "pedal" for a moment, like a driver
	# does with the clutch. That gives the little dip you hear between gears.
	if _car.gear > _last_gear:
		_shift_timer = SHIFT_TIME
	_last_gear = _car.gear
	_shift_timer = maxf(_shift_timer - delta, 0.0)

	var target_load := absf(_car.throttle) if _car.controls_enabled else 0.0
	if _shift_timer > 0.0:
		target_load = 0.0
	_load = lerpf(_load, target_load, 1.0 - exp(-12.0 * delta))

	# The filter lets everything through at full throttle, and only the low,
	# rumbly part when coasting. Multiplying (not adding) moves smoothly
	# through the low and high notes alike.
	_filter.cutoff_hz = coasting_cutoff_hz * pow(16000.0 / coasting_cutoff_hz, _load)
	# Louder with your foot down, and a bit louder at high RPM.
	var rpm_fraction := inverse_lerp(loop_rpms[0], loop_rpms[-1], rpm)
	var loudness := lerpf(0.45, 1.0, _load) * lerpf(0.75, 1.0, clampf(rpm_fraction, 0.0, 1.0))

	# Find the two loops either side of the RPM, and how far between them we are.
	var upper := loop_rpms.size() - 1
	for i in loop_rpms.size():
		if loop_rpms[i] >= rpm:
			upper = i
			break
	var lower := maxi(upper - 1, 0)
	var blend := 1.0
	if upper != lower:
		blend = clampf(inverse_lerp(loop_rpms[lower], loop_rpms[upper], rpm), 0.0, 1.0)

	for i in _players.size():
		var weight := 0.0
		# sin and cos keep the total loudness the same through the crossfade.
		if i == upper:
			weight = sin(blend * PI / 2.0)
		elif i == lower:
			weight = cos(blend * PI / 2.0)
		var player := _players[i]
		player.volume_db = linear_to_db(weight * loudness) + volume_db if weight > 0.001 else -80.0
		player.pitch_scale = clampf(rpm / loop_rpms[i], 0.5, 2.0)
