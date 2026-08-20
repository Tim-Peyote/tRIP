shader_type canvas_item;
render_mode unshaded;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;
global uniform float trip_visual_intensity;
global uniform float trip_perception;
global uniform float trip_toxicity;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	float strength = clamp(trip_perception * trip_visual_intensity, 0.0, 1.0);
	vec2 uv = SCREEN_UV;
	float wave = sin(uv.y * 31.0 + TIME * 2.1) * 0.0018 * strength;
	float tracking = step(0.965, sin(uv.y * 9.0 - TIME * 0.72) * 0.5 + 0.5) * 0.012 * strength;
	uv.x += wave + tracking;
	vec2 chroma = vec2(0.0035 * strength, 0.0);
	vec3 color;
	color.r = texture(screen_texture, uv + chroma).r;
	color.g = texture(screen_texture, uv).g;
	color.b = texture(screen_texture, uv - chroma).b;
	float scanline = sin(FRAGCOORD.y * 2.4) * 0.035 * strength;
	float noise = (hash(FRAGCOORD.xy + vec2(TIME * 73.0)) - 0.5) * 0.06 * strength;
	color += vec3(scanline + noise, scanline * 0.7, noise * 0.8);
	color = mix(color, floor(color * 28.0) / 28.0, 0.22 * strength);
	COLOR = vec4(color, strength * 0.92);
}

