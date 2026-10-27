# Asset credits

All models in this folder are from [Kenney](https://kenney.nl) and licensed
[CC0 1.0](https://creativecommons.org/publicdomain/zero/1.0/): public domain,
free to use in any project, no attribution required. We list them anyway so
you know where they came from.

## Cars (`models/kenney_cars/`, from Kenney's Car Kit 3.1)

Source: https://kenney.nl/assets/car-kit (CC0, see `License.txt` there).

| File | Used for |
| --- | --- |
| `hatchback-sports.glb` | Rally Hatch |
| `suv.glb` | Trail SUV |
| `truck.glb` | Heavy Pickup |
| `sedan.glb`, `tractor.glb`, `debris-*.glb` | The rusty wreck and the forgotten tractor (Explore mode) |
| `Textures/colormap.png` | The models' shared colour texture |
| `Textures/colormap_red.png`, `colormap_blue.png` | Our recoloured copies, for the rally car and the pickup |

## Nature (`models/kenney_nature/`, from Kenney's Nature Kit 2.1)

Source: https://kenney.nl/assets/nature-kit (CC0, see `License.txt` there).
`scripts/nature.gd` repaints them with its `palette` setting.

| Files | Used for |
| --- | --- |
| `tree_pineTall*`, `tree_pineRound*`, `tree_pineDefault*`, `tree_default`, `tree_oak`, `tree_fat` | Trees |
| `stone_small*` | Rocks |
| `stone_large*`, `stone_tall*` | Boulders |
| `plant_bush*`, `grass_large` | Bushes and grass (decoration) |
| `tree_pineSmall*` | Small pines on Experimental mode's Valhallas maps |
| `tree_palm*`, `tree_plateau` | Palms and acacia-like trees on Experimental mode's desert maps |
| `tent_*`, `campfire_*`, `log*`, `canoe`, `pot_large`, `sign`, `stump_old`, `lily_large`, `statue_*`, `platform_stone`, `mushroom_*` | Points of interest in Explore mode (`scenes/poi/`) |

## Survival (`models/kenney_survival/`, from Kenney's Survival Kit 2.0)

Source: https://kenney.nl/assets/survival-kit (CC0, see `License.txt` there).
Used for the points of interest in Explore mode (`scenes/poi/`): the lookout
tower and the woodcutter's shelter (`structure*`), crates, barrels, fences,
signposts, the fishing stand and more. They share `Textures/colormap.png`.

The ground has no textures: `shaders/terrain.gdshader` paints it with plain
colours.

## Experimental maps (`maps/`)

Made by `tools/make_explore_maps.py` from a PDF of five map posters that
Kristoffer provided for this project (Tassili n'Ajjer and the Aurès Mountains
in Algeria; Emerald Lake, Gimli Ridge and Asgard Mountain in the Valhallas).
Each `poster.jpg` is the map part of one poster, made smaller; `terrain.png`
is worked out from it.

## Engine sounds (`sounds/engines/`)

Made from three engine recordings that Kristoffer provided for this project
(a 4-cylinder, a 6-cylinder and a V8). `tools/make_engine_loops.py` cut them
into the loops; it lists exactly which seconds of each recording were used.

| Files | Recording | Used for |
| --- | --- | --- |
| `rally_*.wav` | 4-cylinder | Rally Hatch |
| `suv_*.wav` | 6-cylinder | Trail SUV |
| `pickup_*.wav` | V8 | Heavy Pickup |
