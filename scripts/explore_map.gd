class_name ExploreMap
extends Control
## The map screen of Explore mode (press M). It shows the whole map from
## above, where you are, and the points of interest: the ones you found with
## their names, and the ones you haven't found as a "?".
##
## The picture of the land is made once, by asking the terrain for the
## height and surface of 256 x 256 spots (ExploreTerrain.make_map_image).
## That takes a moment, so it runs on a background thread when the game
## starts, and the map shows "Drawing the map..." until it's ready.

@export var exploration: Exploration
## Show where the points of interest you haven't found yet are, as a "?".
## Turn it off to make exploring harder.
@export var show_undiscovered := true
@export var map_pixels := 256

var _texture: ImageTexture
var _task_id := -1
var _image: Image


func _ready() -> void:
	_task_id = WorkerThreadPool.add_task(_make_image)


func _exit_tree() -> void:
	if _task_id >= 0:
		WorkerThreadPool.wait_for_task_completion(_task_id)
		_task_id = -1


# Runs on a background thread.
func _make_image() -> void:
	_image = exploration.terrain.make_map_image(map_pixels)


func _process(_delta: float) -> void:
	if _task_id >= 0 and WorkerThreadPool.is_task_completed(_task_id):
		WorkerThreadPool.wait_for_task_completion(_task_id)
		_task_id = -1
		_texture = ImageTexture.create_from_image(_image)
	if visible:
		queue_redraw()


func _draw() -> void:
	var font := ThemeDB.fallback_font
	# The map is a square in the middle of the screen.
	var side := minf(size.x, size.y) - 80.0
	var rect := Rect2((size - Vector2(side, side)) / 2.0, Vector2(side, side))
	draw_rect(rect.grow(6.0), Color(0, 0, 0, 0.7))
	if _texture == null:
		draw_string(font, rect.get_center() - Vector2(90, 0), "Drawing the map...",
				HORIZONTAL_ALIGNMENT_LEFT, -1, 22)
		return
	draw_texture_rect(_texture, rect, false)

	var title := "Map   (M to close)"
	draw_string_outline(font, rect.position + Vector2(10, 28), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, 6, Color.BLACK)
	draw_string(font, rect.position + Vector2(10, 28), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 22)

	_draw_marker(font, rect, Vector3.ZERO, "Start", Color(0.9, 0.9, 0.9), 5.0)
	for point in exploration.points:
		if exploration.is_found(point):
			_draw_marker(font, rect, point.global_position, point.display_name, Color(0.4, 1.0, 0.45), 7.0)
		elif show_undiscovered:
			_draw_marker(font, rect, point.global_position, "?", Color(1.0, 0.85, 0.2), 7.0)

	# The car: a triangle pointing the way it drives.
	var car := exploration.car
	if car:
		var centre := _to_map(rect, car.global_position)
		var forward := Vector2(car.global_transform.basis.z.x, car.global_transform.basis.z.z).normalized()
		var right := Vector2(-forward.y, forward.x)
		var tip := centre + forward * 14.0
		var points := PackedVector2Array([tip, centre - forward * 8.0 + right * 8.0, centre - forward * 8.0 - right * 8.0])
		draw_colored_polygon(points, Color(1, 0.3, 0.25))
		draw_polyline(points + PackedVector2Array([tip]), Color.WHITE, 2.0)


func _draw_marker(font: Font, rect: Rect2, world: Vector3, text: String, color: Color, radius: float) -> void:
	var spot := _to_map(rect, world)
	draw_circle(spot, radius + 2.0, Color.BLACK)
	draw_circle(spot, radius, color)
	draw_string_outline(font, spot + Vector2(radius + 4.0, 6.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, 5, Color.BLACK)
	draw_string(font, spot + Vector2(radius + 4.0, 6.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, color)


# Where a spot in the world is on the map. North (-Z) is up.
func _to_map(rect: Rect2, world: Vector3) -> Vector2:
	var terrain := exploration.terrain
	var local := terrain.to_local(world)
	var half := terrain.size / 2.0
	var fraction := Vector2((local.x + half) / terrain.size, (local.z + half) / terrain.size)
	return rect.position + fraction.clamp(Vector2.ZERO, Vector2.ONE) * rect.size
