extends Camera3D
## A camera that follows a target from behind, like in most driving games.
##
## Each physics frame we work out where the camera *wants* to be (behind and
## above the car), then move only part of the way there. That small delay is
## what makes the camera feel smooth instead of glued to the car.

## The node to follow. Set this in the Inspector (we point it at the car).
@export var target: Node3D
## How far behind the target the camera sits, in metres.
@export var distance := 7.0
## How high above the target the camera sits, in metres.
@export var height := 2.8
## How quickly the camera catches up. Higher = stiffer, lower = floatier.
@export var follow_speed := 4.0
## How high above the car's origin the camera looks.
@export var look_height := 1.0


func _ready() -> void:
	# Make the camera ignore its parent's movement, so only this script moves it.
	top_level = true
	if target:
		global_position = _desired_position()


func _physics_process(delta: float) -> void:
	if target == null:
		return
	# This "1 - exp(...)" trick gives the same smoothness at any frame rate.
	var weight := 1.0 - exp(-follow_speed * delta)
	global_position = global_position.lerp(_desired_position(), weight)
	look_at(target.global_position + Vector3.UP * look_height)


func _desired_position() -> Vector3:
	# The car drives towards its +Z axis. Flatten that direction so the camera
	# does not swing up and down when the car tilts on a bump.
	var forward := target.global_transform.basis.z
	forward.y = 0.0
	if forward.length() < 0.01:
		forward = Vector3.BACK
	forward = forward.normalized()
	return target.global_position - forward * distance + Vector3.UP * height
