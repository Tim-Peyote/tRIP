shader_type spatial;
varying vec3 local_position;
void vertex() { local_position = VERTEX; }
void fragment() {
	float radius = length(local_position.xz);
	float phase = radius * 110.0 + sin(local_position.x * 19.0) * 0.5;
	float antialias = 1.0 - smoothstep(0.8, 3.0, fwidth(phase));
	float rings = mix(0.5, 0.5 + 0.5 * sin(phase), antialias);
	ALBEDO = mix(vec3(0.22, 0.135, 0.065), vec3(0.48, 0.33, 0.18), rings);
	ROUGHNESS = 0.92;
	SPECULAR = 0.2;
}
