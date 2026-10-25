// Paints the terrain with real photo textures: dirt, mud and rock.
//
// A shader is a small program that runs on the graphics card for every pixel.
// The terrain script (scripts/terrain.gd) stores in each vertex's COLOR how
// much of each surface is there: red = dirt, green = mud, blue = rock. The
// same numbers decide the car's grip, so what you see is what you drive on.
//
// The terrain has no texture coordinates (UVs), so we use the position in
// the world instead. Flat ground looks at the texture from above. Rock is on
// steep slopes, where a texture seen from above would be stretched, so rock
// uses "triplanar" mapping: it looks at the texture from three sides and
// blends them, depending on which way the slope faces.
shader_type spatial;
render_mode cull_back;

group_uniforms Dirt;
uniform sampler2D dirt_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D dirt_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
// How many metres one copy of the texture covers.
uniform float dirt_tile_size = 4.0;
uniform float dirt_roughness : hint_range(0.0, 1.0) = 0.95;

group_uniforms Mud;
uniform sampler2D mud_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D mud_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float mud_tile_size = 3.0;
// Mud is wet, so it is smoother (shinier) than dirt.
uniform float mud_roughness : hint_range(0.0, 1.0) = 0.65;

group_uniforms Rock;
uniform sampler2D rock_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rock_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float rock_tile_size = 6.0;
uniform float rock_roughness : hint_range(0.0, 1.0) = 0.85;

group_uniforms Look;
// How strong the bumps from the normal maps are.
uniform float normal_strength : hint_range(0.0, 2.0) = 1.0;
// Big, soft light and dark patches so you don't notice the texture repeating.
uniform float macro_variation : hint_range(0.0, 1.0) = 0.35;
// How crisp the edges between surfaces are. Higher is sharper.
uniform float blend_sharpness : hint_range(1.0, 16.0) = 6.0;

varying vec3 world_pos;
varying vec3 world_normal;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

// Reads a normal map and turns it from "-1 to 1" numbers into a direction.
vec3 unpack_normal(vec4 texel) {
	vec3 n = texel.rgb * 2.0 - 1.0;
	n.xy *= normal_strength;
	return n;
}

// Texture seen from straight above. Returns the colour, and writes the bumpy
// world-space normal into `normal_out`.
vec3 sample_top(sampler2D albedo, sampler2D normal_map, float tile, vec3 n, out vec3 normal_out) {
	vec2 uv = world_pos.xz / tile;
	vec3 t = unpack_normal(texture(normal_map, uv));
	// Image "up" is -Z in the world here, so the green channel is flipped.
	normal_out = normalize(vec3(t.x + n.x, n.y, -t.y + n.z));
	return texture(albedo, uv).rgb;
}

// Texture seen from three sides and blended ("triplanar").
vec3 sample_triplanar(sampler2D albedo, sampler2D normal_map, float tile, vec3 n, out vec3 normal_out) {
	vec3 weights = pow(abs(n), vec3(4.0));
	weights /= weights.x + weights.y + weights.z;

	vec2 uv_x = world_pos.zy / tile;
	vec2 uv_y = world_pos.xz / tile;
	vec2 uv_z = world_pos.xy / tile;

	vec3 tx = unpack_normal(texture(normal_map, uv_x));
	vec3 ty = unpack_normal(texture(normal_map, uv_y));
	vec3 tz = unpack_normal(texture(normal_map, uv_z));
	// Tilt the surface normal by the bumps of each side's texture.
	vec3 nx = vec3(n.x, -tx.y + n.y, tx.x + n.z);
	vec3 ny = vec3(ty.x + n.x, n.y, -ty.y + n.z);
	vec3 nz = vec3(tz.x + n.x, -tz.y + n.y, n.z);
	normal_out = normalize(nx * weights.x + ny * weights.y + nz * weights.z);

	return texture(albedo, uv_x).rgb * weights.x
		+ texture(albedo, uv_y).rgb * weights.y
		+ texture(albedo, uv_z).rgb * weights.z;
}

float brightness(vec3 c) {
	return dot(c, vec3(0.299, 0.587, 0.114));
}

void fragment() {
	vec3 n = normalize(world_normal);

	vec3 dirt_n;
	vec3 mud_n;
	vec3 rock_n;
	vec3 dirt = sample_top(dirt_albedo, dirt_normal, dirt_tile_size, n, dirt_n);
	vec3 mud = sample_top(mud_albedo, mud_normal, mud_tile_size, n, mud_n);
	vec3 rock = sample_triplanar(rock_albedo, rock_normal, rock_tile_size, n, rock_n);

	// "Height blending": where two surfaces meet, the brighter (higher) bits
	// of one texture poke through the other, so edges look natural instead
	// of like a smooth fade.
	vec3 w = COLOR.rgb + vec3(brightness(dirt), brightness(mud), brightness(rock)) * 0.5;
	w = pow(max(w, vec3(0.0001)), vec3(blend_sharpness)) * max(COLOR.rgb, vec3(0.0001));
	w /= w.x + w.y + w.z;

	vec3 color = dirt * w.x + mud * w.y + rock * w.z;

	// Large light/dark patches, read from the dirt texture at a huge scale.
	float patches = brightness(texture(dirt_albedo, world_pos.xz / 97.0).rgb)
		+ brightness(texture(rock_albedo, world_pos.xz / 41.0).rgb);
	color *= mix(1.0, patches * 1.1, macro_variation);

	ALBEDO = color;
	ROUGHNESS = dirt_roughness * w.x + mud_roughness * w.y + rock_roughness * w.z;
	vec3 bumped = normalize(dirt_n * w.x + mud_n * w.y + rock_n * w.z);
	// Godot wants the normal relative to the camera ("view space").
	NORMAL = normalize((VIEW_MATRIX * vec4(bumped, 0.0)).xyz);
}
