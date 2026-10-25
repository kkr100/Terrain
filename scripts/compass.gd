class_name Compass
extends Control
## A compass strip along the top of the screen, like in many open-world
## games. The middle is the way the car is pointing. It shows N, E, S, W and a
## marker for every point of interest you haven't found yet that's close
## enough, with how far away it is.
##
## Instead of using Label nodes, this Control draws itself: Godot calls
## _draw(), and we draw lines and text with draw_line() and draw_string().
## queue_redraw() in _process() asks Godot to call _draw() again every frame.

@export var exploration: Exploration
## How much of the world the strip shows, in degrees (180 = from your left to
## your right).
@export var view_angle := 180.0
## Points of interest further away than this don't show up, in metres.
@export var hint_distance := 700.0
@export var marker_color := Color(1.0, 0.85, 0.2)

const DIRECTIONS := ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var car := exploration.car if exploration else null
	if car == null:
		return
	var font := ThemeDB.fallback_font
	var middle := size.x / 2.0
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.35))

	# Which way the car points, as an angle: 0 = north (-Z), 90 = east (+X).
	var heading := _bearing(car.global_transform.basis.z)

	# Ticks every 15 degrees, with a letter every 45.
	for degrees in range(0, 360, 15):
		var x := _screen_x(deg_to_rad(degrees), heading)
		if x < 0.0:
			continue
		if degrees % 45 == 0:
			var text: String = DIRECTIONS[degrees / 45]
			var font_size := 22 if text.length() == 1 else 16
			var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
			draw_string_outline(font, Vector2(x - width / 2.0, 26), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 4, Color.BLACK)
			draw_string(font, Vector2(x - width / 2.0, 26), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.WHITE)
		else:
			draw_line(Vector2(x, 8), Vector2(x, 18), Color(1, 1, 1, 0.5), 2.0)

	# The points of interest you haven't found yet. First we work out where
	# each marker goes, then sort them from left to right, so we can move a
	# distance label down a row when it would overlap the one before it.
	var markers := []
	for point in exploration.points:
		if exploration.is_found(point):
			continue
		var offset := point.global_position - car.global_position
		offset.y = 0.0
		var distance := offset.length()
		if distance > hint_distance:
			continue
		var x := _screen_x(_bearing(offset), heading)
		if x < 0.0:
			# Behind you: show it at the edge, pointing the way to turn.
			var left := wrapf(_bearing(offset) - heading, -PI, PI) < 0.0
			x = 10.0 if left else size.x - 10.0
		markers.append([x, distance])
	markers.sort()
	var last_x := -INF
	var row := 0
	for marker: Array in markers:
		var x: float = marker[0]
		var distance: float = marker[1]
		row = (row + 1) % 2 if x - last_x < 60.0 else 0
		last_x = x
		var text := "?" if distance > 120.0 else "!"
		draw_circle(Vector2(x, 44), 11.0, Color(0, 0, 0, 0.6))
		draw_circle(Vector2(x, 44), 11.0, marker_color, false, 2.0)
		var mark_width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x
		draw_string(font, Vector2(x - mark_width / 2.0, 51), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, marker_color)
		var label := "%d m" % roundi(distance)
		var label_width := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
		var label_x := clampf(x - label_width / 2.0, 0.0, size.x - label_width)
		var label_y := 74.0 + row * 16.0
		draw_string_outline(font, Vector2(label_x, label_y), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, 4, Color.BLACK)
		draw_string(font, Vector2(label_x, label_y), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, marker_color)

	# A little triangle in the middle: "you are pointing here".
	draw_colored_polygon(PackedVector2Array([Vector2(middle - 7, 0), Vector2(middle + 7, 0),
			Vector2(middle, 9)]), Color.WHITE)


# The compass angle of a direction: 0 = north (-Z), PI / 2 = east (+X).
func _bearing(direction: Vector3) -> float:
	return atan2(direction.x, -direction.z)


# Where on the strip an angle goes, or -1 if it's outside the strip.
func _screen_x(angle: float, heading: float) -> float:
	var relative := wrapf(angle - heading, -PI, PI)
	var half_view := deg_to_rad(view_angle) / 2.0
	if absf(relative) > half_view:
		return -1.0
	return size.x / 2.0 + relative / half_view * size.x / 2.0
