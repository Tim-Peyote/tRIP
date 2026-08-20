shader_type canvas_item;

uniform vec3 deep_color : source_color = vec3(0.008, 0.014, 0.011);
uniform vec3 moss_color : source_color = vec3(0.055, 0.12, 0.075);
uniform vec3 spore_color : source_color = vec3(0.63, 0.76, 0.42);
global uniform float trip_visual_intensity;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec2 uv = UV;
	float vignette = smoothstep(0.85, 0.18, distance(uv, vec2(0.5)));
	float canopy = sin(uv.x * 11.0 + sin(uv.y * 7.0)) * 0.5 + 0.5;
	float mist = sin((uv.y + TIME * 0.006) * 21.0 + sin(uv.x * 9.0)) * 0.5 + 0.5;
	float spores = step(0.995, hash(floor((uv + vec2(TIME * 0.004, -TIME * 0.008)) * 240.0)));
	vec3 color = mix(deep_color, moss_color, canopy * 0.38 + mist * 0.12);
	color += spore_color * spores * 0.24 * trip_visual_intensity;
	float scanline = sin(FRAGCOORD.y * 2.15) * 0.012 * trip_visual_intensity;
	color = (color + scanline) * (0.48 + vignette * 0.7);
	COLOR = vec4(color, 1.0);
}
