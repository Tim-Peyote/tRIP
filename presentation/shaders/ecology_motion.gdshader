shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx, cull_disabled;

uniform vec4 base_color : source_color = vec4(0.2, 0.45, 0.16, 1.0);
uniform float motion_strength : hint_range(0.0, 0.5) = 0.08;
uniform float motion_speed : hint_range(0.1, 3.0) = 1.0;
uniform float height_response : hint_range(0.1, 4.0) = 1.0;
uniform float emission_strength : hint_range(0.0, 1.0) = 0.0;

varying float motion_light;

void vertex() {
	vec3 world_origin = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	float height_mask = clamp(max(VERTEX.y, 0.0) * height_response, 0.0, 1.0);
	float broad_wave = sin(TIME * motion_speed + world_origin.x * 0.071 + world_origin.z * 0.053);
	float detail_wave = sin(TIME * motion_speed * 1.73 + world_origin.z * 0.13 + VERTEX.y * 1.9);
	float displacement = (broad_wave * 0.72 + detail_wave * 0.28) * motion_strength * height_mask;
	VERTEX.x += displacement;
	VERTEX.z += displacement * 0.38;
	motion_light = broad_wave * 0.5 + 0.5;
}

void fragment() {
	vec3 tint = base_color.rgb * COLOR.rgb;
	ALBEDO = tint * mix(0.9, 1.08, motion_light);
	ROUGHNESS = 0.86;
	EMISSION = tint * emission_strength;
}
