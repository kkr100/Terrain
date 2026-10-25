class_name Race
extends Node
## The game rules: count down, then drive through every checkpoint in order,
## as fast as you can.
##
## The checkpoints are the children of the "Checkpoints" node in main.tscn.
## Their order in the Scene panel is the order you drive them in, and the last
## one is the finish. Drag them around in the editor to make a new route. You
## only need to set X and Z: when the game starts, each one is moved down (or
## up) onto the ground.

## Sent when the car reaches the finish.
signal finished(time: float, best_time: float, is_new_best: bool)

@export var car: VehicleBody3D
@export var terrain: Terrain
## The node whose children are the checkpoints.
@export var checkpoints_root: Node3D
## How long the "3, 2, 1" countdown lasts, in seconds.
@export var countdown_time := 3.0

var checkpoints: Array[Checkpoint] = []
## Which checkpoint to drive to now (0 is the first).
var next_index := 0
## Seconds since the countdown ended.
var elapsed := 0.0
## Seconds left of the countdown. Once it's below 0 the race is on (it keeps
## counting down, so the HUD knows how long ago the race started).
var countdown := 0.0
var has_started := false
var is_finished := false


func _ready() -> void:
	for child in checkpoints_root.get_children():
		if child is Checkpoint:
			checkpoints.append(child)
			child.global_position.y = terrain.get_height_at(child.global_position)
			child.reached.connect(_on_checkpoint_reached)
	countdown = countdown_time
	# Hold the car still until the countdown is over.
	car.controls_enabled = false
	_update_checkpoints()


func _process(delta: float) -> void:
	if is_finished:
		return
	countdown -= delta
	if countdown > 0.0:
		return
	if not has_started:
		has_started = true
		car.controls_enabled = true
	elapsed += delta


## How far the car is from the next checkpoint, in metres (ignoring height).
func distance_to_next() -> float:
	if next_index >= checkpoints.size():
		return 0.0
	var offset := checkpoints[next_index].global_position - car.global_position
	offset.y = 0.0
	return offset.length()


func _on_checkpoint_reached(checkpoint: Checkpoint) -> void:
	if checkpoint != checkpoints[next_index]:
		return
	next_index += 1
	if next_index >= checkpoints.size():
		_finish()
		return
	# If the car falls off the world or gets stuck, it comes back here,
	# pointing at the next checkpoint.
	car.set_respawn_point(checkpoint.global_position + Vector3.UP * 1.5,
			checkpoints[next_index].global_position)
	_update_checkpoints()


func _finish() -> void:
	is_finished = true
	car.controls_enabled = false
	_update_checkpoints()
	var best := BestTime.read()
	var is_new_best := best < 0.0 or elapsed < best
	if is_new_best:
		best = elapsed
		BestTime.write(best)
	finished.emit(elapsed, best, is_new_best)


func _update_checkpoints() -> void:
	for i in checkpoints.size():
		if i < next_index:
			checkpoints[i].set_state(Checkpoint.State.DONE)
		elif i == next_index:
			checkpoints[i].set_state(Checkpoint.State.NEXT, i == checkpoints.size() - 1)
		else:
			checkpoints[i].set_state(Checkpoint.State.WAITING)
