shader_type spatial;
uniform vec4 base_color : source_color = vec4(0.3, 0.25, 0.2, 1.0);
uniform float surface_roughness = 0.8;
uniform float surface_metallic = 0.0;
uniform int surface_kind = 0;
uniform sampler2D wood_texture : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
varying vec3 local_position;
varying vec3 local_normal;
float grain(vec3 p) {
	return fract(sin(dot(floor(p), vec3(17.13, 39.71, 91.7))) * 43758.54);
}
void vertex() { local_position = VERTEX; local_normal = NORMAL; }
void fragment() {
	vec3 w = pow(abs(normalize(local_normal)), vec3(4.0));
	w /= max(dot(w, vec3(1.0)), 0.001);
	float detail = grain(local_position * 180.0);
	// Fade sub-pixel grain instead of sparkling at distance.
	float visibility = 1.0 - smoothstep(0.003, 0.012, length(fwidth(local_position)));
	detail = mix(0.5, detail, visibility);
	vec3 color = base_color.rgb;
	if (surface_kind == 0) {
		vec3 p = local_position * 2.0;
		color = texture(wood_texture, p.zy).rgb * w.x
			+ texture(wood_texture, p.xz).rgb * w.y
			+ texture(wood_texture, p.xy).rgb * w.z;
	} else {
		color *= mix(0.82, 1.08, detail);
	}
	float patina = smoothstep(0.55, 0.85, grain(local_position * 12.0));
	if (surface_kind == 3) color = mix(color, vec3(0.075, 0.13, 0.115), patina * 0.55);
	float soot = surface_kind == 2 ? (1.0 - smoothstep(-0.04, 0.17, local_position.y)) * 0.6 : 0.0;
	color = mix(color, vec3(0.018, 0.015, 0.012), soot);
	ALBEDO = color;
	ROUGHNESS = clamp(surface_roughness + (detail - 0.5) * 0.16 + soot * 0.3, 0.18, 1.0);
	METALLIC = surface_metallic * (1.0 - patina * 0.25) * (1.0 - soot);
	SPECULAR = surface_kind == 4 ? 0.5 : 0.3;
}
