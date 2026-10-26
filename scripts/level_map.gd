class_name LevelMap
extends Control
## Draws a level's map with its route on the level-select screen: the start,
## a line to each checkpoint in order, numbers on the checkpoints, and the
## finish in green.

var _texture: Texture2D
var _route := PackedVector2Array()
var _map_size := 1


## Shows a new map. With no texture it says "Drawing the map..." instead.
func show_map(texture: Texture2D, route: PackedVector2Array, map_size: int) -> void:
	_texture = texture
	_route = route
	_map_size = map_size
	# queue_redraw asks Godot to call _draw again before the next frame.
	queue_redraw()


func _draw() -> void:
	var font := ThemeDB.fallback_font
	# The map is the biggest square that fits.
	var side := minf(size.x, size.y)
	var rect := Rect2((size - Vector2(side, side)) / 2.0, Vector2(side, side))
	draw_rect(rect.grow(6.0), Color(0, 0, 0, 0.6))
	if _texture == null:
		draw_string(font, rect.get_center() - Vector2(90, 0), "Drawing the map...",
				HORIZONTAL_ALIGNMENT_LEFT, -1, 22)
		return
	draw_texture_rect(_texture, rect, false)

	var points := PackedVector2Array()
	for spot in _route:
		points.append(_to_map(rect, spot))
	# The route: a dark line under a bright one, so it shows on any ground.
	draw_polyline(points, Color(0, 0, 0, 0.6), 6.0, true)
	draw_polyline(points, Color(1, 0.85, 0.2), 3.0, true)
	for i in range(1, points.size()):
		var is_finish := i == points.size() - 1
		var color := Color(0.3, 1.0, 0.4) if is_finish else Color(1, 0.85, 0.2)
		draw_circle(points[i], 13.0, Color.BLACK)
		draw_circle(points[i], 11.0, color)
		var text := "F" if is_finish else str(i)
		var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
		draw_string(font, points[i] + Vector2(-width / 2.0, 6.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.BLACK)
	# The start: a white square.
	draw_rect(Rect2(points[0] - Vector2(8, 8), Vector2(16, 16)), Color.BLACK)
	draw_rect(Rect2(points[0] - Vector2(6, 6), Vector2(12, 12)), Color.WHITE)
	draw_string_outline(font, points[0] + Vector2(12, 6), "Start", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, 5, Color.BLACK)
	draw_string(font, points[0] + Vector2(12, 6), "Start", HORIZONTAL_ALIGNMENT_LEFT, -1, 16)


# Where a spot on the level (x, z in metres) is on the map. North (-Z) is up,
# like on the Explore map.
func _to_map(rect: Rect2, spot: Vector2) -> Vector2:
	var fraction := (spot + Vector2.ONE * _map_size / 2.0) / _map_size
	return rect.position + fraction * rect.size
