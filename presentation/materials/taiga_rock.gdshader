shader_type spatial;
uniform sampler2D rock_texture : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D moss_texture : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float moss_amount : hint_range(0.0, 1.0) = 0.6;
varying vec3 world_position;
varying vec3 world_normal;
void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}
void fragment() {
	vec3 w = pow(abs(normalize(world_normal)), vec3(4.0));
	w /= max(dot(w, vec3(1.0)), 0.001);
	vec3 p = world_position * 0.6;
	vec3 rock = texture(rock_texture, p.zy).rgb * w.x + texture(rock_texture, p.xz).rgb * w.y + texture(rock_texture, p.xy).rgb * w.z;
	vec3 moss = texture(moss_texture, world_position.xz * 0.9).rgb;
	float patches = sin(world_position.x * 1.73 + sin(world_position.z * 2.1)) * 0.5 + 0.5;
	float cover = smoothstep(0.35, 0.82, world_normal.y) * smoothstep(0.25, 0.72, patches) * moss_amount;
	ALBEDO = mix(rock, moss, cover);
	ROUGHNESS = mix(0.83, 0.98, cover);
	SPECULAR = mix(0.32, 0.15, cover);
}
