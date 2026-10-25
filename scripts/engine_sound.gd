extends AudioStreamPlayer
## The engine noise, made from scratch in code. There's no sound file!
##
## A sound is just a long list of numbers between -1 and 1 ("samples"), played
## thousands per second. An AudioStreamGenerator lets us write those numbers
## ourselves while the game runs, so the sound can follow the engine's RPM
## exactly.
##
## How a petrol engine sounds: every time a cylinder fires there's a little
## bang. At 3000 RPM a 4-cylinder engine fires 100 times a second, and our ears
## hear that fast row of bangs as a buzzing note. So for each sample we work
## out where we are between two bangs, and play a short bang that fades out.
## More RPM = bangs closer together = higher note. More cylinders = more bangs
## per turn = a smoother, higher sound.
##
## Put this node inside a car. It reads the car's "rpm" and "throttle".

## How many cylinders the engine has. 4 sounds buzzy, 6 smooth, 8 deep.
@export_range(1, 12) var cylinders := 4
## How quickly each bang fades. Higher = sharper, rasping sound;
## lower = rounder, softer sound.
@export_range(5.0, 60.0) var sharpness := 20.0
## How uneven the cylinders are. A bit of unevenness gives the lumpy
## "burble" of a big V8. 0 = perfectly even.
@export_range(0.0, 1.0) var rumble := 0.2
## How much hissing air (intake and exhaust noise) there is at full throttle.
@export_range(0.0, 1.0) var hiss := 0.15
## The highest frequency let through, in Hz, at full throttle. Lower sounds
## more muffled, like a big exhaust.
@export var brightness_hz := 2500.0

## Samples per second. 22050 is half of CD quality, plenty for an engine and
## easier on the computer than 44100.
const MIX_RATE := 22050.0

var _car: Node
var _playback: AudioStreamGeneratorPlayback
# Where we are in one full engine cycle (two turns of the crankshaft, in which
# every cylinder fires once). 0 to 1.
var _cycle := 0.0
# How loud each cylinder's bang is, so they aren't all the same.
var _cylinder_strength: Array[float] = []
var _low_pass := 0.0
var _last_input := 0.0
var _high_pass := 0.0
var _load := 0.0
# Worked out once per frame in _process, then used for every sample.
var _cycle_step := 0.0
var _amplitude := 0.0
var _smoothing := 0.0
var _noise := 0.0


func _ready() -> void:
	_car = get_parent()
	var generator := AudioStreamGenerator.new()
	generator.mix_rate = MIX_RATE
	generator.buffer_length = 0.1  # seconds of sound we prepare ahead
	stream = generator
	# A fixed seed, so the same car always sounds the same.
	var random := RandomNumberGenerator.new()
	random.seed = cylinders * 1000 + int(sharpness)
	for i in cylinders:
		_cylinder_strength.append(1.0 + random.randf_range(-rumble, rumble))
	play()
	_playback = get_stream_playback()


func _process(delta: float) -> void:
	if _playback == null:
		return
	var rpm: float = _car.rpm
	# "Load" is how hard the engine works. Full throttle is louder and
	# brighter than rolling with your foot off the pedal.
	var target_load := absf(_car.throttle) if _car.controls_enabled else 0.0
	_load = lerpf(_load, target_load, 1.0 - exp(-10.0 * delta))
	_prepare(rpm)
	for i in _playback.get_frames_available():
		var value := next_sample()
		_playback.push_frame(Vector2(value, value))  # left and right speaker


## Works out the settings that stay the same for this frame's samples.
func _prepare(rpm: float) -> void:
	# Two crankshaft turns per cycle, so cycles per second = RPM / 60 / 2.
	_cycle_step = rpm / 120.0 / MIX_RATE
	_amplitude = lerpf(0.25, 0.6, _load)
	# A "one-pole low-pass filter" smooths the sound. The higher the cutoff,
	# the more of the sharp, high parts get through.
	var cutoff := lerpf(brightness_hz * 0.35, brightness_hz, _load)
	_smoothing = 1.0 - exp(-TAU * cutoff / MIX_RATE)
	_noise = hiss * _load


## Works out the next sample of sound, a number between -1 and 1.
func next_sample() -> float:
	_cycle = fmod(_cycle + _cycle_step, 1.0)
	# Which cylinder fired last, and how far we are towards the next one.
	var firing := _cycle * cylinders
	var cylinder := int(firing)
	var since_bang := firing - cylinder
	var bang := exp(-sharpness * since_bang) * _cylinder_strength[cylinder]
	var sample := bang + randf_range(-_noise, _noise)

	_low_pass += (sample - _low_pass) * _smoothing
	# The "high-pass" part removes the constant push in one direction, so the
	# speaker moves back and forth around the middle.
	_high_pass = 0.995 * (_high_pass + _low_pass - _last_input)
	_last_input = _low_pass
	return clampf(_high_pass * _amplitude * 1.6, -1.0, 1.0)
