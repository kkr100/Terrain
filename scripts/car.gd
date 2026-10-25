extends VehicleBody3D
## A simple offroad car.
##
## VehicleBody3D does the hard physics work for us: every VehicleWheel3D child
## shoots a ray down at the ground and acts like a spring (the suspension).
## This script only has to read the keyboard and set three numbers each
## physics frame: engine_force, brake and steering.
##
## Note: in Godot a VehicleBody3D drives towards its +Z axis, so +Z is "forward".

## Engine push in newtons, given to *each* driving wheel (all four, since this
## is a 4x4). Bigger = faster acceleration.
@export var max_engine_force := 1500.0
## Brake strength used when you press the brake or the handbrake.
@export var max_brake := 40.0
## Top speed in km/h. The engine stops pushing above this.
@export var max_speed_kmh := 110.0
## Top speed when reversing, in km/h.
@export var max_reverse_kmh := 30.0
## How far the front wheels can turn, in radians (0.5 is about 29 degrees).
@export var max_steer_angle := 0.5
## How fast the wheels turn towards the target angle (radians per second).
@export var steer_speed := 2.5
## If the car falls below this height it is put back on the map.
@export var fall_limit_y := -20.0

## The name of the ground under the car ("Dirt", "Mud", ...), for the HUD.
var surface_name := ""

var _spawn_transform: Transform3D
var _wheels: Array[VehicleWheel3D] = []
# Each wheel's grip as set in car.tscn, before the ground changes it.
var _base_friction: Array[float] = []


func _ready() -> void:
	# Remember where we started, so we can respawn there if we fall off.
	_spawn_transform = global_transform
	for child in get_children():
		if child is VehicleWheel3D:
			_wheels.append(child)
			_base_friction.append(child.wheel_friction_slip)


func _physics_process(delta: float) -> void:
	# Input.get_axis returns -1, 0 or 1 (or values in between for a gamepad).
	# The action names are set up in Project > Project Settings > Input Map.
	var throttle := Input.get_axis("brake", "accelerate")
	var steer_input := Input.get_axis("steer_right", "steer_left")

	var speed := get_forward_speed()

	# --- Engine and brakes -------------------------------------------------
	engine_force = 0.0
	brake = 0.0
	if throttle > 0.0:
		if speed < -1.0:
			# Rolling backwards and pressing "forward": brake first.
			brake = max_brake * throttle
		elif speed * 3.6 < max_speed_kmh:
			engine_force = max_engine_force * throttle
	elif throttle < 0.0:
		if speed > 1.0:
			# Moving forward and pressing "back": that is a brake.
			brake = max_brake * -throttle
		elif -speed * 3.6 < max_reverse_kmh:
			# Almost stopped or rolling back: "back" means reverse, at half power.
			engine_force = max_engine_force * 0.5 * throttle

	if Input.is_action_pressed("handbrake"):
		brake = max_brake

	# --- Steering ----------------------------------------------------------
	# Turn the wheels less at high speed, so the car is easier to control.
	var speed_factor := clampf(1.0 - absf(speed) / 40.0, 0.35, 1.0)
	var target_steer := steer_input * max_steer_angle * speed_factor
	# move_toward turns the wheels smoothly instead of snapping them.
	steering = move_toward(steering, target_steer, steer_speed * delta)

	_apply_ground()

	# --- Resetting ---------------------------------------------------------
	if Input.is_action_just_pressed("reset_car"):
		flip_upright()
	if global_position.y < fall_limit_y:
		respawn()


## Changes each wheel's grip to match the ground under it, and slows the car
## down in mud.
func _apply_ground() -> void:
	var total_drag := 0.0
	var counts := {}
	for i in _wheels.size():
		var wheel := _wheels[i]
		var surface: SurfaceType = null
		# get_contact_body() is whatever the wheel is touching. If that thing
		# is our terrain, ask it which surface is under the wheel.
		if wheel.is_in_contact():
			var ground := wheel.get_contact_body()
			if ground is Terrain:
				surface = ground.get_surface_at(wheel.get_contact_point())
		if surface == null:
			wheel.wheel_friction_slip = _base_friction[i]
			continue
		wheel.wheel_friction_slip = _base_friction[i] * surface.grip
		total_drag += surface.drag / _wheels.size()
		counts[surface.display_name] = counts.get(surface.display_name, 0) + 1

	# Mud pulls back against the way the car moves. The faster you go, the
	# harder it pulls, a bit like wading through water.
	if total_drag > 0.0:
		apply_central_force(-linear_velocity * total_drag * mass)

	# Show the surface that most wheels are on.
	surface_name = ""
	var best := 0
	for surface_key in counts:
		if counts[surface_key] > best:
			best = counts[surface_key]
			surface_name = surface_key


## Speed along the direction the car points, in metres per second.
## Positive = forwards, negative = backwards.
func get_forward_speed() -> float:
	return linear_velocity.dot(global_transform.basis.z)


## Put the car back on its wheels where it is now (for when you roll over).
func flip_upright() -> void:
	var forward := global_transform.basis.z
	forward.y = 0.0
	if forward.length() < 0.01:
		forward = Vector3.FORWARD
	var new_transform := Transform3D.IDENTITY
	new_transform.origin = global_position + Vector3.UP * 1.5
	# looking_at points -Z at the target, so we look "backwards" to get +Z forward.
	new_transform = new_transform.looking_at(new_transform.origin - forward, Vector3.UP)
	_place(new_transform)


## Move the car back to where the level started.
func respawn() -> void:
	_place(_spawn_transform)


func _place(new_transform: Transform3D) -> void:
	global_transform = new_transform
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	steering = 0.0
