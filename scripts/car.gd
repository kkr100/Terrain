class_name Car
extends VehicleBody3D
## An offroad car. All three cars (scenes/cars/) use this same script: what
## makes them different is the numbers in the Inspector, the mass, and the
## wheel settings in each car's scene.
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
## How much mud slows this car down. 1 = normal, 0.5 = half as much
## (big tyres, heavy truck), 1.5 = more (small, light car).
@export var mud_drag_scale := 1.0

@export_group("Engine")
## Engine speed when idling, in revolutions per minute (RPM).
@export var idle_rpm := 850.0
## The highest engine speed. The engine changes up a gear when it gets here.
@export var redline_rpm := 6000.0
## How many forward gears the gearbox has.
@export var gear_count := 5

@export_group("Looks")
## The 3D model (a .glb from the Kenney car kit). Its wheels are called
## "wheel-front-left" and so on. When the game starts we move each one onto
## the VehicleWheel3D with the matching name (WheelFrontLeft), so the tyres
## spin, steer and bounce with the physics wheels.
@export var model: Node3D
## Makes the model's tyres bigger (1.2 = 20% bigger), for chunky offroad
## tyres. Remember to make each VehicleWheel3D's "Wheel Radius" match!
@export var tire_scale := 1.0
## Optional paint job: a recoloured copy of the model's colour texture.
@export var paint: Texture2D

## The upgrades fitted to this car (see car_upgrade.gd). Whoever creates the
## car fills this in before adding it to the scene, so they're in place when
## _ready runs. The CarSpawner and the car-select screen do that.
var upgrades: Array[CarUpgrade] = []
## Extra power while boosting, from the nitro upgrade (0 = no nitro).
var boost_power := 0.0
## How full the nitro tank is: 1 = full, 0 = empty.
var nitro := 1.0
## True while the nitro is firing. The flames on the exhaust listen to this.
var is_boosting := false
## Pushes the car down at speed, from the wing upgrade (see car_upgrade.gd).
var downforce := 0.0

## The name of the ground under the car ("Dirt", "Mud", ...), for the HUD.
var surface_name := ""
## When false the car ignores the keys and holds its brakes. The race turns
## this off during the countdown and after the finish.
var controls_enabled := true
## How hard you press the pedal right now: 1 = full gas, -1 = full
## brake/reverse. The engine sound listens to this.
var throttle := 0.0
## Engine speed right now, in RPM, and the gear it's in (1 = first gear).
var rpm := 0.0
var gear := 1

var _spawn_transform: Transform3D
var _wheels: Array[VehicleWheel3D] = []
# Each wheel's grip as set in car.tscn, before the ground changes it.
var _base_friction: Array[float] = []
# Grip multipliers from the tyre upgrades: on hard ground, and in mud.
var _grip_scale := 1.0
var _mud_grip_scale := 1.0

## A full nitro tank lasts this many seconds...
const NITRO_SECONDS := 4.0
## ...and takes this many seconds to fill up again.
const NITRO_REFILL_SECONDS := 15.0
## Nitro lets the car go this much faster than its top speed, in km/h.
const NITRO_EXTRA_KMH := 25.0


func _ready() -> void:
	# Remember where we started, so we can respawn there if we fall off.
	_spawn_transform = global_transform
	rpm = idle_rpm
	# Upgrades change the car's numbers, so they go first, before we
	# remember each wheel's grip below.
	for upgrade in upgrades:
		_apply_upgrade(upgrade)
	for child in get_children():
		if child is VehicleWheel3D:
			_wheels.append(child)
			_base_friction.append(child.wheel_friction_slip)
	if paint and model:
		_repaint(model)
	_attach_wheel_models()


func _physics_process(delta: float) -> void:
	# Input.get_axis returns -1, 0 or 1 (or values in between for a gamepad).
	# The action names are set up in Project > Project Settings > Input Map.
	throttle = Input.get_axis("brake", "accelerate")
	var steer_input := Input.get_axis("steer_right", "steer_left")
	if not controls_enabled:
		throttle = 0.0
		steer_input = 0.0

	var speed := get_forward_speed()

	# --- Nitro -------------------------------------------------------------
	# Fires while you hold the key, the gas is down and there's some left.
	is_boosting = boost_power > 0.0 and throttle > 0.0 and nitro > 0.0 \
			and Input.is_action_pressed("boost")
	if is_boosting:
		nitro = maxf(nitro - delta / NITRO_SECONDS, 0.0)
	else:
		nitro = minf(nitro + delta / NITRO_REFILL_SECONDS, 1.0)
	var power := max_engine_force
	var top_speed_kmh := max_speed_kmh
	if is_boosting:
		power *= 1.0 + boost_power
		top_speed_kmh += NITRO_EXTRA_KMH

	# --- Engine and brakes -------------------------------------------------
	engine_force = 0.0
	brake = 0.0
	if throttle > 0.0:
		if speed < -1.0:
			# Rolling backwards and pressing "forward": brake first.
			brake = max_brake * throttle
		elif speed * 3.6 < top_speed_kmh:
			engine_force = power * throttle
	elif throttle < 0.0:
		if speed > 1.0:
			# Moving forward and pressing "back": that is a brake.
			brake = max_brake * -throttle
		elif -speed * 3.6 < max_reverse_kmh:
			# Almost stopped or rolling back: "back" means reverse, at half power.
			engine_force = max_engine_force * 0.5 * throttle

	if Input.is_action_pressed("handbrake") or not controls_enabled:
		brake = max_brake

	# --- Steering ----------------------------------------------------------
	# Turn the wheels less at high speed, so the car is easier to control.
	var speed_factor := clampf(1.0 - absf(speed) / 40.0, 0.35, 1.0)
	var target_steer := steer_input * max_steer_angle * speed_factor
	# move_toward turns the wheels smoothly instead of snapping them.
	steering = move_toward(steering, target_steer, steer_speed * delta)

	_apply_ground()
	_update_engine(delta)

	# The wing pushes down harder the faster you go (speed squared, like real
	# air). At 100 km/h (27.8 m/s) the push is "downforce" times our weight.
	if downforce > 0.0:
		var push := mass * 9.8 * downforce * pow(speed / 27.8, 2.0)
		apply_central_force(-global_transform.basis.y * push)

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
		# is a terrain (the race map or the Explore map: both have a
		# get_surface_at function), ask it which surface is under the wheel.
		if wheel.is_in_contact():
			var ground := wheel.get_contact_body()
			if ground and ground.has_method("get_surface_at"):
				surface = ground.get_surface_at(wheel.get_contact_point())
		if surface == null:
			wheel.wheel_friction_slip = _base_friction[i]
			continue
		# Ground that holds you back (drag) is mud, the rest is hard ground.
		var tyre_grip := _mud_grip_scale if surface.drag > 0.0 else _grip_scale
		wheel.wheel_friction_slip = _base_friction[i] * surface.grip * tyre_grip
		total_drag += surface.drag * mud_drag_scale / _wheels.size()
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


## Changes the car's settings for one upgrade. Most upgrades multiply a
## setting, so a better engine helps every car, but each car keeps its own
## character.
func _apply_upgrade(upgrade: CarUpgrade) -> void:
	max_engine_force *= upgrade.power_scale
	max_speed_kmh += upgrade.top_speed_add
	boost_power += upgrade.boost_power
	mass *= upgrade.mass_scale
	downforce += upgrade.downforce
	_grip_scale *= upgrade.grip_scale
	_mud_grip_scale *= upgrade.mud_grip_scale
	mud_drag_scale *= upgrade.mud_drag_scale
	tire_scale *= upgrade.tire_size_scale

	var lift := 0.0  # How much higher the body ends up, in metres.
	for child in get_children():
		var wheel := child as VehicleWheel3D
		if wheel == null:
			continue
		lift = upgrade.ride_height_add + wheel.wheel_radius * (upgrade.tire_size_scale - 1.0)
		wheel.wheel_radius *= upgrade.tire_size_scale
		wheel.wheel_rest_length += upgrade.ride_height_add
		wheel.suspension_travel *= upgrade.travel_scale
		wheel.suspension_stiffness *= upgrade.stiffness_scale
		wheel.wheel_roll_influence *= upgrade.roll_scale
	# A taller car rolls over more easily. Lower the centre of mass by the same
	# amount, so it stays at the same height above the ground.
	center_of_mass.y -= lift

	# The upgrade's visible part, like a wing, placed on the matching
	# Marker3D under "Mounts" in the car's scene.
	if upgrade.part_scene:
		var mount := get_node_or_null("Mounts/" + upgrade.part_mount)
		if mount:
			mount.add_child(upgrade.part_scene.instantiate())


## Works out the engine speed (RPM) and gear from how fast the car goes, like
## an automatic gearbox. This doesn't change how the car drives, it's just
## for the engine sound and the HUD.
func _update_engine(delta: float) -> void:
	var top_speed := max_speed_kmh / 3.6
	# 0 = standing still, 1 = top speed. Each gear covers an equal slice.
	var speed_fraction := clampf(absf(get_forward_speed()) / top_speed, 0.0, 1.0)
	var gear_position := speed_fraction * gear_count
	gear = mini(floori(gear_position), gear_count - 1) + 1
	var through_gear := gear_position - (gear - 1)  # 0 at the start of a gear, 1 at the end
	var target_rpm: float
	if gear == 1:
		target_rpm = lerpf(idle_rpm, redline_rpm, through_gear)
	else:
		# After changing up, the engine drops to about 60% of the redline.
		target_rpm = lerpf(redline_rpm * 0.6, redline_rpm, through_gear)

	# Revving while (almost) standing still, or with the wheels in the air.
	var on_ground := false
	for wheel in _wheels:
		on_ground = on_ground or wheel.is_in_contact()
	var free_rev := idle_rpm + (redline_rpm - idle_rpm) * absf(throttle)
	if not on_ground:
		target_rpm = free_rev
	elif speed_fraction < 0.1:
		target_rpm = maxf(target_rpm, idle_rpm + (redline_rpm - idle_rpm) * absf(throttle) * 0.4)

	# Move smoothly towards the target, like a real engine speeding up.
	rpm = lerpf(rpm, target_rpm, 1.0 - exp(-6.0 * delta))


## Moves the model's wheel meshes onto our VehicleWheel3D nodes. Godot moves
## and turns each VehicleWheel3D as the car drives, so anything that's a child
## of one spins and steers along with it.
func _attach_wheel_models() -> void:
	if model == null:
		return
	for wheel in _wheels:
		# "WheelFrontLeft" -> "wheel_front_left" -> "wheel-front-left"
		var mesh_name := String(wheel.name).to_snake_case().replace("_", "-")
		var mesh := model.find_child(mesh_name) as Node3D
		if mesh == null:
			continue
		# reparent() keeps the mesh where it is in the world by default.
		mesh.reparent(wheel)
		# Line the tyre's axle up with the wheel's centre. We keep the
		# sideways offset, so the tyre stays under the wheel arch.
		mesh.position.y = 0.0
		mesh.position.z = 0.0
		mesh.scale *= tire_scale


## Swaps the colour texture on every mesh of the model for the "paint" one.
## The models share one small texture of colour swatches, so a recoloured copy
## of that texture gives the car a new colour without touching the model.
func _repaint(node: Node) -> void:
	if node is MeshInstance3D:
		for i in node.mesh.get_surface_count():
			var material := node.mesh.surface_get_material(i) as BaseMaterial3D
			if material:
				material = material.duplicate()
				material.albedo_texture = paint
				node.set_surface_override_material(i, material)
	for child in node.get_children():
		_repaint(child)


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


## Choose where respawn() puts the car: at "where", pointing towards "facing".
func set_respawn_point(where: Vector3, facing: Vector3) -> void:
	var new_transform := Transform3D(Basis.IDENTITY, where)
	facing.y = where.y  # Look level, not up or down a hill.
	# looking_at points -Z at the target, so we look "backwards" to get +Z forward.
	_spawn_transform = new_transform.looking_at(where - (facing - where), Vector3.UP)


## Move the car back to where the level started, or to the last checkpoint.
func respawn() -> void:
	_place(_spawn_transform)


func _place(new_transform: Transform3D) -> void:
	global_transform = new_transform
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	steering = 0.0
