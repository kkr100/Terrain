extends Camera3D
## A camera that follows a target from behind, like in most driving games.
##
## Each physics frame we work out where the camera *wants* to be (behind and
## above the car), then move only part of the way there. That small delay is
## what makes the camera feel smooth instead of glued to the car.
##
## Driving downhill, the ground behind the car is higher than the car, so
## "behind and a bit above" can end up inside the hill. To stop that, the
## camera shoots invisible rays (raycasts) at the ground: one straight down to
## stay above it, and one from the car to the camera to make sure no hill is
## in between. This is the same idea as Godot's SpringArm3D node.

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
## The camera never goes lower than this above the ground, in metres.
@export var ground_clearance := 1.5


func _ready() -> void:
	# Make the camera ignore its parent's movement, so only this script moves it.
	top_level = true
	if target:
		global_position = _desired_position()


func _physics_process(delta: float) -> void:
	if target == null:
		return
	var look_point := target.global_position + Vector3.UP * look_height
	# This "1 - exp(...)" trick gives the same smoothness at any frame rate.
	var weight := 1.0 - exp(-follow_speed * delta)
	# If the car suddenly jumped far away (it was put back on the map), jump
	# with it, instead of gliding there through the hills.
	if global_position.distance_to(target.global_position) > distance * 5.0:
		weight = 1.0
	var new_position := global_position.lerp(_desired_position(), weight)
	# The smoothing above lags behind, so it could still drag the camera into
	# a hill. These two checks happen straight away, with no smoothing.
	new_position = _above_ground(new_position)
	new_position = _in_sight_of(look_point, new_position)
	global_position = new_position
	look_at(look_point)


func _desired_position() -> Vector3:
	# The car drives towards its +Z axis. Flatten that direction so the camera
	# does not swing up and down when the car tilts on a bump.
	var forward := target.global_transform.basis.z
	forward.y = 0.0
	if forward.length() < 0.01:
		forward = Vector3.BACK
	forward = forward.normalized()
	var wanted := target.global_position - forward * distance + Vector3.UP * height
	# If the hill behind the car is higher than that, go up over it. The
	# camera then looks down at the car, which also shows the slope ahead.
	return _above_ground(wanted)


## Moves "point" up if it is lower than ground_clearance above the ground.
func _above_ground(point: Vector3) -> Vector3:
	var hit := _ground_hit(point + Vector3.UP * 100.0, point + Vector3.DOWN * 100.0)
	if hit:
		point.y = maxf(point.y, hit.position.y + ground_clearance)
	return point


## If the ground is between the car and the camera (like the top of a hill
## you just drove over), moves the camera forward to just in front of it.
func _in_sight_of(look_point: Vector3, camera_point: Vector3) -> Vector3:
	var hit := _ground_hit(look_point, camera_point)
	if hit.is_empty():
		return camera_point
	return hit.position + (look_point - hit.position).normalized() * 0.5


## Shoots a ray from "from" to "to" and returns where it first hits the
## ground, as a Dictionary with a "position" (empty if nothing was hit).
## Only the terrain counts: trees, rocks and the car itself are skipped, so
## the camera doesn't jump about every time a tree trunk passes in front.
func _ground_hit(from: Vector3, to: Vector3) -> Dictionary:
	var space := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(from, to)
	for i in 8:
		var hit := space.intersect_ray(query)
		if hit.is_empty():
			return {}
		# Both terrains (the race map and the Explore map) have this function.
		if hit.collider.has_method("get_surface_at"):
			return hit
		# Something else, like a tree: ignore it and shoot again.
		query.exclude += [hit.rid]
	return {}
