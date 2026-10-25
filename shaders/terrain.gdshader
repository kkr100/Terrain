// Paints the terrain in a cartoon "low-poly" style, to match the cars and
// the trees (which all come from Kenney's low-poly kits).
//
// A shader is a small program that runs on the graphics card for every pixel.
// The terrain script (scripts/terrain.gd) stores in each vertex's COLOR how
// much of each surface is there: red = dirt, green = mud, blue = rock. The
// same numbers decide the car's grip, so what you see is what you drive on.
//
// The low-poly look comes from three tricks:
// 1. Flat shading: every triangle gets one single direction it faces, so it
//    is lit evenly and you can see the edges between triangles (facets).
// 2. Plain colours instead of photo textures, with hard edges between
//    surfaces instead of soft fades.
// 3. Every triangle gets a slightly different shade of its colour, like the
//    patchwork look of low-poly art.
shader_type spatial;
render_mode cull_back;

group_uniforms Colours;
// Dirt is the normal, grassy ground.
uniform vec4 dirt_color : source_color = vec4(0.47, 0.69, 0.29, 1.0);
// Some dirt patches are a drier, yellower green, so big fields aren't boring.
uniform vec4 dry_color : source_color = vec4(0.71, 0.73, 0.33, 1.0);
uniform vec4 mud_color : source_color = vec4(0.45, 0.31, 0.2, 1.0);
uniform vec4 rock_color : source_color = vec4(0.58, 0.57, 0.6, 1.0);

group_uniforms Look;
// How much each triangle's shade differs from its neighbours.
uniform float facet_variation : hint_range(0.0, 0.3) = 0.08;
// How big the dry patches are, in metres. Bigger number = bigger patches.
uniform float dry_patch_size = 40.0;
// Mud is wet, so it is a bit shinier than grass and rock.
uniform float mud_roughness : hint_range(0.0, 1.0) = 0.55;
// How big the grid squares of the mesh are, in metres. The race map uses 1 m
// squares. The big Explore map (scripts/explore_terrain.gd) uses bigger ones
// far away and sets this for each chunk. "instance" means every mesh using
// this material can have its own value.
instance uniform float facet_size = 1.0;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

// Turns a 2D point into a random-looking number between 0 and 1. The same
// point always gives the same number.
float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

// Smooth random value (simple "value noise"), for the dry patches.
float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

void fragment() {
	// 1. Flat shading. dFdx/dFdy tell us how the position changes to the next
	// pixel on screen. Both lie flat on the triangle, so their cross product
	// points straight out of it (the order dFdy, dFdx makes it point out of
	// the front, not into the ground). VERTEX is already relative to the
	// camera, which is what NORMAL wants.
	NORMAL = normalize(cross(dFdy(VERTEX), dFdx(VERTEX)));

	// 2. Which surface wins here? We pick the biggest one, so the edges are
	// a crisp line instead of a soft fade.
	vec3 w = COLOR.rgb;
	vec3 color;
	float roughness = 1.0;
	if (w.g > w.r && w.g > w.b) {
		color = mud_color.rgb;
		roughness = mud_roughness;
	} else if (w.b > w.r) {
		color = rock_color.rgb;
	} else {
		float dry = smoothstep(0.55, 0.7, value_noise(world_pos.xz / dry_patch_size));
		color = mix(dirt_color.rgb, dry_color.rgb, dry);
	}

	// 3. Every grid square is cut into two triangles along the diagonal.
	// Work out which triangle this pixel is in, and give it its own shade.
	vec2 grid_pos = world_pos.xz / facet_size;
	vec2 cell = floor(grid_pos);
	vec2 inside = grid_pos - cell;
	float which = step(1.0, inside.x + inside.y);
	float shade = hash(cell + which * 0.5) * 2.0 - 1.0;
	color *= 1.0 + shade * facet_variation;

	ALBEDO = color;
	ROUGHNESS = roughness;
}
