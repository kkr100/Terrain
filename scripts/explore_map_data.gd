class_name ExploreMapData
extends Resource
## One map for Experimental mode, made from a map poster.
##
## tools/make_explore_maps.py makes these from the posters in a PDF: it
## writes assets/maps/<id>/<id>.tres (this resource), terrain.png (the
## heights and the kind of ground) and poster.jpg. Open a .tres in the
## Inspector to try other colours, more trees or a different sky. (Running the
## tool again writes the .tres again, so change its STYLES too if you want to
## keep your changes.)

## A short name for the save file. Each map saves the places you found in
## its own section, "experimental_<id>".
@export var id := ""
@export var display_name := ""
## Where the place is, like "Algeria".
@export var region := ""
@export_multiline var description := ""

@export_group("Map")
## The map as data, one pixel every 2.5 m (see tools/make_explore_maps.py).
## Red * 256 + green is the height, from lowest (0) to highest (65535).
## Blue is what the poster shows there: 0 open ground, 1 sand, 2 forest,
## 3 water, 4 trail.
@export var terrain_image: Image
## The poster's map, shown on the map screen and the map picker.
@export var poster: Image
## The height of the lowest and the highest pixel, in metres. The water is at
## height 0, so the bottom of the lakes is below 0.
@export var lowest := -4.0
@export var highest := 150.0
## Where you start (x, z), in metres from the middle of the map.
@export var start := Vector2.ZERO
## Where the places to discover are, one (x, z) for each.
@export var places := PackedVector2Array()

@export_group("Ground")
## How big the little bumps on top are, in metres.
@export var bumps := 1.0
## Open ground below this part of the highest height is meadow ("0.3" =
## the lowest 30%). Above it, it slowly turns into rock...
@export_range(0.0, 1.0) var meadow_line := 0.3
## ...until above this part of the highest height it's nearly all rock.
@export_range(0.0, 1.0) var rock_line := 0.8
## Open ground above this part of the highest height is snow. More than 1
## means no snow at all.
@export var snow_line := 0.85
## Lower numbers give more mud puddles in the grass. 1 means no mud.
@export_range(-1.0, 1.0) var mud_amount := 0.4
## Under the forests.
@export var grass: SurfaceType
## Open, low ground.
@export var meadow: SurfaceType
## The tan areas of the poster.
@export var sand: SurfaceType
## Open high ground and every steep slope.
@export var rock: SurfaceType
@export var snow: SurfaceType
@export var mud: SurfaceType
## The trails (the dashed lines on the poster).
@export var track: SurfaceType
## The bottom of lakes and rivers. Its drag makes driving through water slow.
@export var lakebed: SurfaceType

@export_group("Nature")
## Which trees grow: "pines" or "palms" (see ExperimentalMap).
@export var trees := "pines"
## The chance (0 to 1) that a tree grows on a free spot, for each kind of ground.
@export_range(0.0, 1.0) var trees_in_forest := 0.9
@export_range(0.0, 1.0) var trees_in_open := 0.03
@export_range(0.0, 1.0) var trees_on_sand := 0.0
## Near the water (in an oasis, say). 0 = no different from anywhere else.
@export_range(0.0, 1.0) var trees_by_water := 0.0
## The most trees, rocks and boulders in one 256 x 256 m square.
@export var tree_count := 400
@export var rock_count := 70
@export var boulder_count := 12

@export_group("Sky")
@export var sky_top := Color(0.22, 0.48, 0.86)
@export var sky_horizon := Color(0.68, 0.82, 0.95)
## The colour of the sky below the horizon (you see it past the edge of the map).
@export var sky_ground := Color(0.35, 0.5, 0.3)
@export var fog := Color(0.72, 0.84, 0.95)
@export var fog_density := 0.001
@export var water_color := Color(0.2, 0.5, 0.62)
