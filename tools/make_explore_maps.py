#!/usr/bin/env python3
"""Turns the map posters in a PDF into Explore maps for Experimental mode.

Each page of the PDF is one poster: a topographic map of a real place, with
contour lines, lakes, forests and trails. For every poster this script makes
a folder in assets/maps/<id>/ with:

- terrain.png  The map as data, 1024 x 1024 pixels, one pixel every 2.5 m of
               the 2560 m game map. Red and green together are the height
               (red * 256 + green, so 65 536 steps), blue is what the poster
               shows there (see GROUND below).
- poster.jpg   The poster's map, for the map screen (M) and the map picker.
- <id>.tres    An ExploreMapData resource (scripts/explore_map_data.gd) that
               the game loads: names, where you start, where the places are,
               the colours of the ground, the sky and the trees.

How the heights are found
-------------------------
The posters have no height numbers, but they do have contour lines: thin
lines that each follow one height, a fixed step apart. Where they are close
together the ground is steep, where they are far apart it is flat. So we:

1. find the contour lines and measure how close together they are
   everywhere (that's the steepness),
2. say that all water (lakes, rivers, the sea) is the lowest ground,
3. work out, for every pixel, the cheapest way to walk there from the water
   when every step costs as much as the ground is steep there (Dijkstra's
   shortest-path algorithm). You can't get up a mountain without climbing
   all of its steep parts, so that cost is how high the pixel is.

This is not exactly the real height (two lakes at different heights both
end up at the bottom), but the valleys, ridges and peaks are where the
poster has them.

Run it again after changing the settings in MAPS:

    python3 tools/make_explore_maps.py path/to/Combined.pdf

It needs pdftoppm (from poppler-utils), numpy, scipy and Pillow.
"""

import json
import os
import subprocess
import sys
import tempfile

import numpy as np
from PIL import Image
from scipy import ndimage as ndi
from scipy.sparse import coo_matrix
from scipy.sparse.csgraph import dijkstra

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
# The game map is 2560 m across (like Explore), stored as 1024 pixels.
MAP_METRES = 2560.0
PIXELS = 1024
METRES_PER_PIXEL = MAP_METRES / PIXELS
# Where the map is on a page rendered at 300 dpi (inside the black frame).
CROP = (196, 196, 2286, 2286)

# The "blue" value in terrain.png: what the poster shows at that pixel.
GROUND = {"open": 0, "sand": 1, "forest": 2, "water": 3, "trail": 4}

# Ground colours, grip and drag for each style. "grass" is under the forests,
# "meadow" is open low ground, "rock" is open high ground and every steep
# slope, "snow" is the very top.
STYLES = {
    "alpine": {
        "surfaces": {
            "grass": ("Grass", 1.0, 0.0, (0.36, 0.6, 0.27)),
            "meadow": ("Meadow", 1.0, 0.0, (0.62, 0.7, 0.36)),
            "sand": ("Gravel", 0.9, 0.05, (0.74, 0.68, 0.55)),
            "rock": ("Rock", 1.4, 0.0, (0.6, 0.6, 0.62)),
            "snow": ("Snow", 0.6, 0.1, (0.93, 0.95, 0.98)),
            "mud": ("Mud", 0.45, 0.35, (0.45, 0.31, 0.2)),
            "track": ("Trail", 1.1, 0.0, (0.62, 0.48, 0.32)),
            "lakebed": ("Water", 0.5, 0.9, (0.5, 0.45, 0.35)),
        },
        "meadow_line": 0.3,
        "rock_line": 0.8,
        "snow_line": 0.82,
        "mud_amount": 0.55,
        "trees": "pines",
        "trees_in_forest": 0.9,
        "trees_in_open": 0.03,
        "trees_on_sand": 0.0,
        "trees_by_water": 0.0,
        "tree_count": 500,
        "rock_count": 90,
        "boulder_count": 16,
        "sky_top": (0.22, 0.46, 0.85),
        "sky_horizon": (0.68, 0.8, 0.93),
        "sky_ground": (0.35, 0.5, 0.3),
        "fog": (0.72, 0.82, 0.93),
        "fog_density": 0.0009,
        "water_color": (0.2, 0.5, 0.62),
        "bumps": 1.2,
    },
    "desert": {
        "surfaces": {
            "grass": ("Scrub", 0.95, 0.02, (0.6, 0.62, 0.34)),
            "meadow": ("Gravel", 0.9, 0.02, (0.8, 0.66, 0.48)),
            "sand": ("Sand", 0.75, 0.12, (0.9, 0.75, 0.5)),
            "rock": ("Sandstone", 1.4, 0.0, (0.72, 0.45, 0.32)),
            "snow": ("Sandstone", 1.4, 0.0, (0.72, 0.45, 0.32)),
            "mud": ("Mud", 0.45, 0.35, (0.5, 0.37, 0.25)),
            "track": ("Track", 1.1, 0.0, (0.66, 0.5, 0.36)),
            "lakebed": ("Water", 0.5, 0.9, (0.55, 0.45, 0.3)),
        },
        "meadow_line": 0.05,
        "rock_line": 0.35,
        "snow_line": 2.0,  # Never: no snow in the Sahara.
        "mud_amount": 1.0,  # No mud either.
        "trees": "palms",
        "trees_in_forest": 0.6,
        "trees_in_open": 0.0,
        "trees_on_sand": 0.004,
        "trees_by_water": 0.5,
        "tree_count": 160,
        "rock_count": 110,
        "boulder_count": 30,
        "sky_top": (0.3, 0.52, 0.86),
        "sky_horizon": (0.93, 0.84, 0.7),
        "sky_ground": (0.72, 0.58, 0.4),
        "fog": (0.93, 0.84, 0.7),
        "fog_density": 0.0008,
        "water_color": (0.2, 0.55, 0.6),
        "bumps": 0.8,
    },
}

# The posters, in the order of the PDF's pages. "height" is how tall the
# highest ground is, in metres.
MAPS = [
    {
        "page": 1, "id": "tassili", "name": "Tassili n'Ajjer", "region": "Algeria",
        "style": "desert", "height": 110.0,
        "description": "A Saharan plateau of sandstone tables and sand valleys, with a few hidden pools.",
    },
    {
        "page": 2, "id": "aures", "name": "Aurès Mountains", "region": "Algeria",
        "style": "desert", "height": 180.0,
        "description": "Dry, rugged mountains around a long winding lake. Wide sandy plains in the south-east.",
    },
    {
        "page": 3, "id": "emerald_lake", "name": "Emerald Lake", "region": "The Valhallas",
        "style": "alpine", "height": 220.0,
        "description": "A green forest valley with two lakes and a river down to a big lake. Trails everywhere, mountains all around.",
    },
    {
        "page": 4, "id": "gimli_ridge", "name": "Gimli Ridge", "region": "The Valhallas",
        "style": "alpine", "height": 230.0,
        "description": "Lakes, islands and winding trails below the snowy ridges in the north-east.",
    },
    {
        "page": 5, "id": "asgard_mountain", "name": "Asgard Mountain", "region": "The Valhallas",
        "style": "alpine", "height": 260.0,
        "description": "High rocky country with a ring of trails around Asgard Mountain and lakes in the hollows.",
    },
]

# How many places to discover on each map (one for each scene in scenes/poi/).
PLACE_COUNT = 12


def render_pages(pdf, folder):
    subprocess.run(["pdftoppm", "-r", "300", "-png", pdf, os.path.join(folder, "page")], check=True)
    pages = sorted(f for f in os.listdir(folder) if f.startswith("page"))
    return [os.path.join(folder, f) for f in pages]


def downsample(array, mode=Image.BOX):
    image = Image.fromarray(array.astype(np.float32))
    return np.asarray(image.resize((PIXELS, PIXELS), mode)).astype(np.float32)


def read_poster(path):
    """Finds water, forest, sand, trails and contour lines on one poster."""
    poster = Image.open(path).convert("RGB").crop(CROP)
    rgb = np.asarray(poster).astype(np.float32)
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    lum = 0.299 * r + 0.587 * g + 0.114 * b

    # Colours: water is blue, forest is green, sand is tan, the rest is open
    # ground. A "closing" fills thin gaps, like the grid crosses on the sea.
    water = (b > r + 18) & (b > g + 4)
    water = ndi.binary_closing(water, structure=np.ones((5, 5)))
    forest = (g > r + 10) & (g > b + 8) & ~water
    sand = (r > b + 22) & ~forest & ~water

    # Trails are black dashes. Grow the dark pixels so the dashes of one
    # trail join up, then keep only the long shapes (not the grid crosses,
    # the letters in the margin or the frame along the edge).
    dark = lum < 100
    grown = ndi.binary_dilation(dark, iterations=8)
    labels, count = ndi.label(grown)
    keep = np.zeros(count + 1, bool)
    height, width = dark.shape
    for k, box in enumerate(ndi.find_objects(labels)):
        size = np.hypot(box[0].stop - box[0].start, box[1].stop - box[1].start)
        touches_edge = (box[0].start < 12 or box[1].start < 12
                or box[0].stop > height - 12 or box[1].stop > width - 12)
        if size > 160 and not touches_edge:
            keep[k + 1] = True
    trail = keep[labels] & dark

    # Contour lines are thin lines a little darker than the ground next to
    # them. A grey "closing" paints over thin dark lines, so the difference
    # between it and the poster is the lines.
    closed = ndi.grey_closing(lum, size=(5, 5))
    blocked = ndi.binary_dilation(dark, iterations=3) | ndi.binary_dilation(water, iterations=2)
    lines = ((closed - lum) > 10) & ~blocked
    # How much of the ground near each pixel is contour line. Under trails
    # and next to water we can't see the lines, so we fill those in from the
    # pixels around them.
    near = ndi.gaussian_filter(lines.astype(np.float32), 7)
    seen = ndi.gaussian_filter((~blocked).astype(np.float32), 7)
    density = near / np.maximum(seen, 1e-3)

    return {
        "poster": poster,
        "water": downsample(water) > 0.3,
        "forest": downsample(forest),
        "sand": downsample(sand),
        "trail": downsample(trail) > 0.02,
        "density": downsample(density),
    }


def climb_heights(density, water):
    """Height = the cheapest climb from the water (see the top of the file)."""
    density = np.clip(density, 0.0, 0.6)
    # Lines closer together = steeper. The small number keeps flat ground
    # from being perfectly flat, so far from water it still rises a little.
    steep = 0.02 + density / (1.0 - density)
    steep[water] = 0.0
    n = PIXELS
    index = np.arange(n * n).reshape(n, n)
    starts, ends, costs = [], [], []
    # Each pixel connects to its 8 neighbours (4 directions, both ways).
    for dy, dx in [(0, 1), (1, 0), (1, 1), (1, -1)]:
        a = (slice(0, n - dy), slice(max(0, -dx), n - max(0, dx)))
        b = (slice(dy, n), slice(max(0, dx), n + min(0, dx)))
        starts.append(index[a].ravel())
        ends.append(index[b].ravel())
        costs.append((0.5 * (steep[a] + steep[b]) * np.hypot(dx, dy)).ravel() + 1e-6)
    graph = coo_matrix((np.concatenate(costs), (np.concatenate(starts), np.concatenate(ends))),
            shape=(n * n, n * n)).tocsr()
    sources = np.flatnonzero(water.ravel())
    if sources.size == 0:
        sources = np.array([np.argmin(steep)])
    heights = dijkstra(graph, directed=False, indices=sources, min_only=True).reshape(n, n)
    return ndi.gaussian_filter(heights, 1.0)


def make_ground(info):
    """One ground class per pixel (the GROUND numbers)."""
    ground = np.full((PIXELS, PIXELS), GROUND["open"], np.uint8)
    ground[info["sand"] > 0.5] = GROUND["sand"]
    ground[info["forest"] > 0.45] = GROUND["forest"]
    ground[info["water"]] = GROUND["water"]
    # Trails: join the dashes into one line, a few metres wide.
    trail = ndi.binary_closing(info["trail"], structure=np.ones((3, 3)), iterations=4)
    trail = ndi.binary_dilation(trail, iterations=1)
    ground[trail] = GROUND["trail"]
    return ground


def finish_heights(raw, ground, top):
    """Scales the climb to metres, digs the lakes and smooths the trails."""
    water = ground == GROUND["water"]
    trail = ground == GROUND["trail"]
    heights = raw / np.percentile(raw, 99.5) * top
    heights = np.minimum(heights, top * 1.15)
    # Land starts half a metre above the water.
    heights = heights + 0.5
    # Lakes get deeper away from the shore: rivers and pools between islands
    # stay shallow enough to drive through, the middle of a big lake doesn't.
    shore = ndi.distance_transform_edt(water) * METRES_PER_PIXEL
    depth = np.clip(shore * 0.12, 0.35, 4.0)
    heights[water] = -depth[water]
    # Trails are smoother than the ground around them, and where a trail
    # crosses water it becomes a little causeway.
    smooth = ndi.gaussian_filter(heights, 3.0)
    blend = ndi.gaussian_filter(trail.astype(np.float32), 1.5)
    blend = np.clip(blend * 2.0, 0.0, 1.0)
    heights = heights * (1.0 - blend) + smooth * blend
    heights[trail] = np.maximum(heights[trail], 0.4)
    return heights


def map_position(row, col):
    """The game position (x, z) of a pixel's centre. North (row 0) is -z."""
    half = MAP_METRES / 2.0
    return (float(-half + (col + 0.5) * METRES_PER_PIXEL), float(-half + (row + 0.5) * METRES_PER_PIXEL))


def pick_spots(heights, ground):
    """Where you start, and the places to discover: on flat, dry ground."""
    water = ground == GROUND["water"]
    dry = ndi.distance_transform_edt(~water) * METRES_PER_PIXEL
    gy, gx = np.gradient(ndi.gaussian_filter(heights, 2.0), METRES_PER_PIXEL)
    slope = np.degrees(np.arctan(np.hypot(gx, gy)))
    # The steepest slope within about 20 m.
    slope = ndi.maximum_filter(slope, size=17)
    trail = ground == GROUND["trail"]
    to_trail = ndi.distance_transform_edt(~trail) * METRES_PER_PIXEL
    rows, cols = np.mgrid[0:PIXELS, 0:PIXELS]
    # Keep well away from the walls at the edge of the map.
    margin = 200.0 / METRES_PER_PIXEL
    inside = ((rows > margin) & (cols > margin) & (rows < PIXELS - margin) & (cols < PIXELS - margin))
    good = inside & (dry > 30.0) & (slope < 14.0) & ~trail

    # Start: near the middle, close to a trail if there is one.
    centre = np.hypot(rows - PIXELS / 2, cols - PIXELS / 2) * METRES_PER_PIXEL
    score = centre + np.minimum(to_trail, 300.0) * 0.8 + slope * 6.0
    score[~good] = np.inf
    start = np.unravel_index(np.argmin(score), score.shape)

    # Places: spread out over the map ("farthest point" picking). Each one
    # is as far as possible from the start and the ones picked so far, with
    # a bonus for being near a trail and for being flat.
    picked = [start]
    candidates = np.argwhere(good[::4, ::4]) * 4
    bonus = np.minimum(to_trail[candidates[:, 0], candidates[:, 1]], 200.0) * 0.6
    bonus += slope[candidates[:, 0], candidates[:, 1]] * 4.0
    for _ in range(PLACE_COUNT):
        far = np.full(len(candidates), np.inf)
        for spot in picked:
            far = np.minimum(far, np.hypot(*(candidates - np.array(spot)).T) * METRES_PER_PIXEL)
        best = np.argmax(np.minimum(far, 650.0) - bonus)
        picked.append(tuple(candidates[best]))
    return start, picked[1:]


def colour(values):
    return "Color(%.3f, %.3f, %.3f, 1)" % tuple(values)


def write_resource(entry, style, start, places, low, high, folder):
    """Writes <id>.tres, the ExploreMapData the game loads."""
    res_folder = "res://assets/maps/%s/" % entry["id"]
    lines = ['[gd_resource type="Resource" script_class="ExploreMapData" load_steps=13 format=3]', ""]
    lines.append('[ext_resource type="Script" path="res://scripts/explore_map_data.gd" id="1_data"]')
    lines.append('[ext_resource type="Script" path="res://scripts/surface_type.gd" id="2_surface"]')
    lines.append('[ext_resource type="Image" path="%sterrain.png" id="3_terrain"]' % res_folder)
    lines.append('[ext_resource type="Image" path="%sposter.jpg" id="4_poster"]' % res_folder)
    lines.append("")
    for key, (name, grip, drag, rgb) in style["surfaces"].items():
        lines.append('[sub_resource type="Resource" id="Surface_%s"]' % key)
        lines.append('script = ExtResource("2_surface")')
        lines.append('display_name = "%s"' % name)
        lines.append("grip = %s" % grip)
        lines.append("drag = %s" % drag)
        lines.append("color = %s" % colour(rgb))
        lines.append("")
    lines.append("[resource]")
    lines.append('script = ExtResource("1_data")')
    lines.append('id = "%s"' % entry["id"])
    lines.append("display_name = %s" % json.dumps(entry["name"], ensure_ascii=False))
    lines.append('region = "%s"' % entry["region"])
    lines.append("description = %s" % json.dumps(entry["description"], ensure_ascii=False))
    lines.append('terrain_image = ExtResource("3_terrain")')
    lines.append('poster = ExtResource("4_poster")')
    lines.append("lowest = %.4f" % low)
    lines.append("highest = %.4f" % high)
    lines.append("start = Vector2(%.1f, %.1f)" % map_position(*start))
    spots = ", ".join("%.1f, %.1f" % map_position(*spot) for spot in places)
    lines.append("places = PackedVector2Array(%s)" % spots)
    lines.append("bumps = %s" % style["bumps"])
    lines.append("meadow_line = %s" % style["meadow_line"])
    lines.append("rock_line = %s" % style["rock_line"])
    lines.append("snow_line = %s" % style["snow_line"])
    lines.append("mud_amount = %s" % style["mud_amount"])
    for key in style["surfaces"]:
        lines.append('%s = SubResource("Surface_%s")' % (key, key))
    lines.append('trees = "%s"' % style["trees"])
    for key in ["trees_in_forest", "trees_in_open", "trees_on_sand", "trees_by_water",
            "tree_count", "rock_count", "boulder_count", "fog_density"]:
        lines.append("%s = %s" % (key, style[key]))
    for key in ["sky_top", "sky_horizon", "sky_ground", "fog", "water_color"]:
        lines.append("%s = %s" % (key, colour(style[key])))
    with open(os.path.join(folder, entry["id"] + ".tres"), "w", encoding="utf-8") as file:
        file.write("\n".join(lines) + "\n")


def write_import_file(path):
    """Tells Godot to load a picture as plain Image data, not as a texture for
    the graphics card. Textures get compressed, which would change the
    numbers in terrain.png, and an Image can be read on any thread."""
    path += ".import"
    if not os.path.exists(path):
        with open(path, "w") as file:
            file.write('[remap]\n\nimporter="image"\ntype="Image"\n')


def make_map(entry, page_path):
    style = STYLES[entry["style"]]
    folder = os.path.join(ROOT, "assets", "maps", entry["id"])
    os.makedirs(folder, exist_ok=True)

    info = read_poster(page_path)
    ground = make_ground(info)
    raw = climb_heights(info["density"], ground == GROUND["water"])
    heights = finish_heights(raw, ground, entry["height"])
    start, places = pick_spots(heights, ground)

    # Height as two bytes: red is the big steps, green the small ones.
    low, high = float(heights.min()), float(heights.max())
    steps = np.round((heights - low) / (high - low) * 65535.0).astype(np.uint32)
    pixels = np.stack([steps >> 8, steps & 255, ground], -1).astype(np.uint8)
    Image.fromarray(pixels, "RGB").save(os.path.join(folder, "terrain.png"), optimize=True)
    info["poster"].resize((PIXELS, PIXELS), Image.LANCZOS).save(
            os.path.join(folder, "poster.jpg"), quality=88)
    write_import_file(os.path.join(folder, "terrain.png"))
    write_import_file(os.path.join(folder, "poster.jpg"))
    write_resource(entry, style, start, places, low, high, folder)
    print("%s: heights %.1f to %.1f m, start %s, %d places" % (
            entry["id"], low, high, map_position(*start), len(places)))


def main():
    if len(sys.argv) != 2:
        print(__doc__)
        sys.exit(1)
    with tempfile.TemporaryDirectory() as folder:
        pages = render_pages(sys.argv[1], folder)
        for entry in MAPS:
            make_map(entry, pages[entry["page"] - 1])


if __name__ == "__main__":
    main()
