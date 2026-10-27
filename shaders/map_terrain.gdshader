// Paints the ground of Experimental mode's maps (scripts/map_terrain.gd) in
// the same low-poly style as shaders/terrain.gdshader.
//
// The difference: here every vertex's COLOR is simply the colour of its
// surface (grass, sand, rock, snow...), straight from the map's SurfaceTypes.
// That way a map can have as many kinds of ground as it likes.
//
// "flat" on the varying below means the colour is NOT blended across a
// triangle: the whole triangle takes the colour of one of its corners. That
// gives crisp, blocky edges between surfaces, like low-poly art.
shader_type spatial;
render_mode cull_back;

// How much each triangle's shade differs from its neighbours.
uniform float facet_variation : hint_range(0.0, 0.3) = 0.07;
// The size of the mesh's grid squares, in metres. map_terrain.gd sets this
// for each chunk, like on the Explore map.
instance uniform float facet_size = 1.0;

varying flat vec3 ground_color;
varying vec3 world_pos;

void vertex() {
	// Colours are written the way you pick them in a colour picker ("sRGB").
	// The lighting maths needs "linear" colours, so we convert them (the
	// source_color hint does this for the colours in terrain.gdshader).
	vec3 c = COLOR.rgb;
	ground_color = mix(pow((c + 0.055) / 1.055, vec3(2.4)), c / 12.92, lessThan(c, vec3(0.04045)));
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

// Turns a 2D point into a random-looking number between 0 and 1.
float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	// Flat shading: one direction for the whole triangle (see terrain.gdshader).
	NORMAL = normalize(cross(dFdy(VERTEX), dFdx(VERTEX)));

	// Give every triangle its own slightly different shade.
	vec2 grid_pos = world_pos.xz / facet_size;
	vec2 cell = floor(grid_pos);
	vec2 inside = grid_pos - cell;
	float which = step(1.0, inside.x + inside.y);
	float shade = hash(cell + which * 0.5) * 2.0 - 1.0;

	ALBEDO = ground_color * (1.0 + shade * facet_variation);
	ROUGHNESS = 1.0;
}
