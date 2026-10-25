class_name SurfaceType
extends Resource
## One kind of ground, like dirt, mud or rock.
##
## This is a custom Resource: a small bundle of settings you can create and
## edit in the Inspector, just like a material. The terrain owns one of these
## for each surface, and the car reads them to decide how much grip it has.

## The name shown on screen when the car drives on it.
@export var display_name := "Dirt"
## How grippy the ground is. 1.0 is normal. Lower makes the wheels slide
## (mud), higher makes them stick (rock).
@export_range(0.05, 3.0, 0.05) var grip := 1.0
## How much the ground holds the car back, like sinking into mud.
## 0 means no extra drag.
@export_range(0.0, 2.0, 0.05) var drag := 0.0
## The colour this surface is painted on the terrain.
@export var color := Color(0.55, 0.42, 0.28)
